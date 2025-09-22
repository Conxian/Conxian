;; System Monitor
;; Implements monitoring and alerting for the Conxian protocol

(use-trait monitoring-admin-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.monitoring-admin-trait)
(use-trait ownable-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.ownable-trait)

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
    data: (optional {})
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
      (current-block (block-height))
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
      health =>
        (let ((current-health (unwrap-panic health)))
          (map-set component-health 
            {component: component}
            (merge current-health {
              last-updated: current-block,
              last-event-id: event-id,
              event-count: (+ (get event-count current-health) u1),
              error-count: (if (>= severity SEVERITY_ERROR) 
                             (+ (get error-count current-health) u1)
                             (get error-count current-health)),
              warning-count: (if (= severity SEVERITY_WARNING)
                              (+ (get warning-count current-health) u1)
                              (get warning-count current-health)),
              status: (calculate-status severity (get status current-health))
            })
          )
        )
      _ =>
        ;; New component
        (map-set component-health 
          {component: component}
          {
            status: (if (>= severity SEVERITY_ERROR) STATUS_ISSUE STATUS_HEALTHY),
            last-updated: current-block,
            last-event-id: event-id,
            event-count: u1,
            error-count: (if (>= severity SEVERITY_ERROR) u1 u0),
            warning-count: (if (= severity SEVERITY_WARNING) u1 u0),
            created-at: current-block
          }
        )
    )
    
    ;; Add to component event index
    (match (map-get? component-health {component: component})
      health =>
        (map-set component-events 
          {component: component, index: (get event-count (unwrap-panic health))} 
          event-id
        )
      _ => (ok "No health data for component")  ;; Should not happen
    )
    
    ;; Increment event counter
    (var-set event-counter (+ event-id u1))
    
    (ok true)
  )
)

(define-private (calculate-status (severity uint) (current-status uint))
  (cond
    ((>= severity SEVERITY_CRITICAL) STATUS_OUTAGE)
    ((and (>= severity SEVERITY_ERROR) (!= current-status STATUS_OUTAGE)) STATUS_ISSUE)
    ((and (>= severity SEVERITY_WARNING) 
          (!= current-status STATUS_ISSUE) 
          (!= current-status STATUS_OUTAGE)) 
     STATUS_DEGRADED)
    (true current-status)
  )
)

;; ========== Read-Only Functions ==========

(define-read-only (get-events (component (string-ascii 32)) (limit uint) (offset uint))
  (begin
    (asserts! (<= limit u100) ERR_INVALID_LIMIT)  ;; Max 100 events per request
    
    (let ((events (list)))
      (fold (component-events {component: component, index: 0} {component: component, index: u1000}) 
            (lambda (event-id events)
              (let ((event (unwrap-panic (map-get? events {id: event-id}))))
                (if (>= (get block-height event) offset)
                  (cons {
                    id: event-id,
                    event-type: (get event-type event),
                    severity: (get severity event),
                    message: (get message event),
                    block-height: (get block-height event),
                    data: (get data event)
                  } events)
                  events
                )
              )
            )
            events
      )
      (ok (slice events u0 (min limit (len events))))
    )
  )
)

(define-read-only (get-event (event-id uint))
  (match (map-get? events {id: event-id})
    event => (ok (unwrap-panic event))
    _ => (err ERR_EVENT_NOT_FOUND)
  )
)

(define-read-only (get-health-status (component (string-ascii 32)))
  (match (map-get? component-health {component: component})
    health => 
      (let ((health-data (unwrap-panic health)))
        (ok {
          status: (get status health-data),
          last-updated: (get last-updated health-data),
          uptime: (- (get last-updated health-data) (get created-at health-data)),
          error-count: (get error-count health-data),
          warning-count: (get warning-count health-data)
        })
      )
    _ => (ok {
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
