;; System Monitor
;; Implements monitoring and alerting for the Conxian protocol



(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_SEVERITY (err u101))
(define-constant ERR_EVENT_NOT_FOUND (err u102))
(define-constant ERR_INVALID_LIMIT (err u103))

;; Severity levels
(define-constant SEVERITY_DEBUG u0)
(define-constant SEVERITY_INFO u1)
(define-constant SEVERITY_WARNING u2)
(define-constant SEVERITY_ERROR u3)
(define-constant SEVERITY_CRITICAL u4)

;; Health status
(define-constant STATUS_HEALTHY u0)
(define-constant STATUS_DEGRADED u1)
(define-constant STATUS_ISSUE u2)
(define-constant STATUS_OUTAGE u3)

;; Admin address
(define-data-var admin principal tx-sender)

;; Event counter
(define-data-var event-counter uint u0)

;; Component health tracking
(define-map component-health
  { component: (string-ascii 32) }
  {
    status: uint,
    last-updated: uint,
    last-event-id: uint,
    event-count: uint,
    error-count: uint,
    warning-count: uint,
    created-at: uint
  }
)

;; Event storage
(define-map events
  { id: uint }
  {
    component: (string-ascii 32),
    event-type: (string-ascii 32),
    severity: uint,
    message: (string-ascii 256),
    block-height: uint,
    data: (optional (string-utf8 256))
  }
)

;; Component event index (for faster lookups)
(define-map component-events
  { component: (string-ascii 32), index: uint }
  uint  ;; event ID
)

;; Alert thresholds
(define-map alert-thresholds
  { component: (string-ascii 32), alert-type: (string-ascii 32) }
  uint
)

;; ========== Admin Functions ==========

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-alert-threshold (component (string-ascii 32)) 
                                  (alert-type (string-ascii 32)) 
                                  (threshold uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (map-set alert-thresholds {component: component, alert-type: alert-type} threshold)
    (ok true)
  )
)

;; ========== Event Logging ==========

(define-public (log-event (component (string-ascii 32)) 
                         (event-type (string-ascii 32)) 
                         (severity uint) 
                         (message (string-ascii 256)) 
                         (data (optional {})))
  (let (
      (event-id (var-get event-counter))
      (current-block block-height)
    )
    ;; Validate severity level
    (asserts! (<= severity SEVERITY_CRITICAL) ERR_INVALID_SEVERITY)
    
    ;; Store the event
    (map-set events 
      {id: event-id}
      {
        component: component,
        event-type: event-type,
        severity: severity,
        message: message,
        block-height: current-block,
        data: data
      }
    )
    
    ;; Update component health
    (match (map-get? component-health {component: component})
      health-data
      (begin
        (map-set component-health
          {component: component}
          (merge health-data {
            last-updated: current-block,
            last-event-id: event-id,
            event-count: (+ (get event-count health-data) u1),
            error-count: (if (>= severity SEVERITY_ERROR)
                           (+ (get error-count health-data) u1)
                           (get error-count health-data)),
            warning-count: (if (is-eq severity SEVERITY_WARNING)
                            (+ (get warning-count health-data) u1)
                            (get warning-count health-data)),
            status: (calculate-status severity (get status health-data))
          })
        )
      )
      ;; New component
      (map-set component-health
        {component: component}
        {
          status: (if (>= severity SEVERITY_ERROR) STATUS_ISSUE STATUS_HEALTHY),
          last-updated: current-block,
          last-event-id: event-id,
          event-count: u1,
          error-count: (if (>= severity SEVERITY_ERROR) u1 u0),
          warning-count: (if (is-eq severity SEVERITY_WARNING) u1 u0),
          created-at: current-block
        }
      )
    )
    
    ;; Add to component event index
    (match (map-get? component-health {component: component})
      health-data
      (map-set component-events
        {component: component, index: (get event-count health-data)}
        event-id
      )
      (ok true)  ;; No health data for component
    )
    
    ;; Increment event counter
    (var-set event-counter (+ event-id u1))
    
    (ok true)
  )
)

(define-private (calculate-status (severity uint) (current-status uint))
  (if (>= severity SEVERITY_CRITICAL)
      STATUS_OUTAGE
      (if (and (>= severity SEVERITY_ERROR) (not (is-eq current-status STATUS_OUTAGE)))
          STATUS_ISSUE
          (if (and (>= severity SEVERITY_WARNING)
                   (not (is-eq current-status STATUS_ISSUE))
                   (not (is-eq current-status STATUS_OUTAGE)))
              STATUS_DEGRADED
              current-status
          )
      )
  )
)

;; ========== Read-Only Functions ==========

(define-read-only (get-events (component (string-ascii 32)) (limit uint) (offset uint))
  (begin
    (asserts! (<= limit u100) ERR_INVALID_LIMIT)  ;; Max 100 events per request
    
    (let ((events (list)))
      (let ((collected-events (list)))
        (ok (unwrap-panic (as-max-len? collected-events u100)))
      )
    )
  )
)

(define-read-only (get-event (event-id uint))
  (match (map-get? events {id: event-id})
    event-data (ok event-data)
    (err ERR_EVENT_NOT_FOUND)
  )
)

(define-read-only (get-health-status (component (string-ascii 32)))
  (match (map-get? component-health {component: component})
    health-data
    (ok {
      status: (get status health-data),
      last-updated: (get last-updated health-data),
      uptime: (- (get last-updated health-data) (get created-at health-data)),
      error-count: (get error-count health-data),
      warning-count: (get warning-count health-data)
    })
    (ok {
      status: STATUS_HEALTHY,
      last-updated: block-height,
      uptime: u0,
      error-count: u0,
      warning-count: u0
    })
  )
)

(define-read-only (get-admin)
  (ok (var-get admin))
)

