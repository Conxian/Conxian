;; Automated Circuit Breaker Contract
;; Protects system from cascading failures by monitoring error rates and automatically 
;; cutting off requests when thresholds are exceeded

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_CIRCUIT_OPEN (err u502))
(define-constant ERR_INVALID_PARAMS (err u400))
(define-constant ERR_SERVICE_NOT_FOUND (err u404))

;; Circuit breaker states
(define-constant STATE_CLOSED u0)
(define-constant STATE_OPEN u1)
(define-constant STATE_HALF_OPEN u2)

;; Circuit breaker configuration
(define-data-var contract-owner principal tx-sender)
(define-data-var failure-threshold uint u10) ;; Open circuit after 10 failures
(define-data-var success-threshold uint u5)  ;; Close circuit after 5 successes
(define-data-var timeout-duration uint u300) ;; 5 minutes timeout before half-open

;; Service circuit breakers
(define-map service-circuits
  { service-name: (string-ascii 64) }
  {
    state: uint,
    failure-count: uint,
    success-count: uint,
    last-failure-time: uint,
    total-requests: uint,
    failed-requests: uint
  }
)

;; Service configurations
(define-map service-configs
  { service-name: (string-ascii 64) }
  {
    failure-threshold: uint,
    success-threshold: uint,
    timeout-duration: uint
  }
)

;; Recent request history (for rate calculations)
(define-map request-history
  { service-name: (string-ascii 64), window-id: uint }
  {
    success-count: uint,
    failure-count: uint,
    timestamp: uint
  }
)

;; Global circuit breaker metrics
(define-data-var total-circuits uint u0)
(define-data-var total-failures uint u0)
(define-data-var total-recoveries uint u0)

;; === OWNER FUNCTIONS ===

(define-public (only-owner-guard)
  (if (is-eq tx-sender (var-get contract-owner))
    (ok true)
    (err u401)))

(define-public (set-contract-owner (new-owner principal))
  (begin
    (try! (only-owner-guard))
    (ok (var-set contract-owner new-owner))
  )
)

(define-public (configure-global-settings (failure-thresh uint) (success-thresh uint) (timeout uint))
  (begin
    (try! (only-owner-guard))
    (asserts! (and (> failure-thresh u0) (> success-thresh u0) (> timeout u0)) ERR_INVALID_PARAMS)
    (var-set failure-threshold failure-thresh)
    (var-set success-threshold success-thresh)
    (var-set timeout-duration timeout)
    (ok true)))

;; === SERVICE MANAGEMENT ===

(define-public (register-service (service-name (string-ascii 64)))
  (begin
    (try! (only-owner-guard))
    (map-set service-circuits
      { service-name: service-name }
      {
        state: STATE_CLOSED,
        failure-count: u0,
        success-count: u0,
        last-failure-time: u0,
        total-requests: u0,
        failed-requests: u0
      }
    )
    (map-set service-configs
      { service-name: service-name }
      {
        failure-threshold: (var-get failure-threshold),
        success-threshold: (var-get success-threshold),
        timeout-duration: (var-get timeout-duration)
      }
    )
    (var-set total-circuits (+ (var-get total-circuits) u1))
    (ok true)
  )
)

(define-public (configure-service (service-name (string-ascii 64)) (failure-thresh uint) (success-thresh uint) (timeout uint))
  (begin
    (try! (only-owner-guard))
    (asserts! (is-some (map-get? service-circuits { service-name: service-name })) ERR_SERVICE_NOT_FOUND)
    (asserts! (and (> failure-thresh u0) (> success-thresh u0) (> timeout u0)) ERR_INVALID_PARAMS)
    (map-set service-configs
      { service-name: service-name }
      {
        failure-threshold: failure-thresh,
        success-threshold: success-thresh,
        timeout-duration: timeout
      }
    )
    (ok true)
  )
)

;; === CIRCUIT BREAKER LOGIC ===

(define-public (check-circuit-state (service-name (string-ascii 64)))
  (let (
    (circuit (unwrap! (map-get? service-circuits { service-name: service-name }) ERR_SERVICE_NOT_FOUND))
    (config (unwrap! (map-get? service-configs { service-name: service-name }) ERR_SERVICE_NOT_FOUND))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (if (is-eq (get state circuit) STATE_OPEN)
      ;; Check if timeout has passed to transition to half-open
      (if (>= (- current-time (get last-failure-time circuit)) (get timeout-duration config))
        (begin
          (map-set service-circuits
            { service-name: service-name }
            (merge circuit { state: STATE_HALF_OPEN, success-count: u0 })
          )
          (ok STATE_HALF_OPEN)
        )
        ERR_CIRCUIT_OPEN
      )
      (ok (get state circuit))
    )
  )
)

(define-public (record-success (service-name (string-ascii 64)))
  (let (
    (circuit (unwrap! (map-get? service-circuits { service-name: service-name }) ERR_SERVICE_NOT_FOUND))
    (config (unwrap! (map-get? service-configs { service-name: service-name }) ERR_SERVICE_NOT_FOUND))
    (new-success-count (+ (get success-count circuit) u1))
    (new-total-requests (+ (get total-requests circuit) u1))
  )
    (if (is-eq (get state circuit) STATE_HALF_OPEN)
      ;; In half-open state, check if we should close the circuit
      (if (>= new-success-count (get success-threshold config))
        (begin
          (map-set service-circuits
            { service-name: service-name }
            (merge circuit {
              state: STATE_CLOSED,
              success-count: u0,
              failure-count: u0,
              total-requests: new-total-requests
            })
          )
          (var-set total-recoveries (+ (var-get total-recoveries) u1))
          (ok STATE_CLOSED)
        )
        (begin
          (map-set service-circuits
            { service-name: service-name }
            (merge circuit {
              success-count: new-success-count,
              total-requests: new-total-requests
            })
          )
          (ok STATE_HALF_OPEN)
        )
      )
      ;; In closed state, just update counters
      (begin
        (map-set service-circuits
          { service-name: service-name }
          (merge circuit {
            success-count: new-success-count,
            failure-count: u0, ;; Reset failure count on success
            total-requests: new-total-requests
          })
        )
        (ok STATE_CLOSED)
      )
    )
  )
)

(define-public (record-failure (service-name (string-ascii 64)))
  (let (
    (circuit (unwrap! (map-get? service-circuits { service-name: service-name }) ERR_SERVICE_NOT_FOUND))
    (config (unwrap! (map-get? service-configs { service-name: service-name }) ERR_SERVICE_NOT_FOUND))
    (new-failure-count (+ (get failure-count circuit) u1))
    (new-failed-requests (+ (get failed-requests circuit) u1))
    (new-total-requests (+ (get total-requests circuit) u1))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (if (or (is-eq (get state circuit) STATE_HALF_OPEN) 
            (>= new-failure-count (get failure-threshold config)))
      ;; Open the circuit
      (begin
        (map-set service-circuits
          { service-name: service-name }
          (merge circuit {
            state: STATE_OPEN,
            failure-count: new-failure-count,
            last-failure-time: current-time,
            failed-requests: new-failed-requests,
            total-requests: new-total-requests
          })
        )
        (var-set total-failures (+ (var-get total-failures) u1))
        (ok STATE_OPEN)
      )
      ;; Stay closed but update failure count
      (begin
        (map-set service-circuits
          { service-name: service-name }
          (merge circuit {
            failure-count: new-failure-count,
            failed-requests: new-failed-requests,
            total-requests: new-total-requests
          })
        )
        (ok STATE_CLOSED)
      )
    )
  )
)

;; === EMERGENCY CONTROLS ===

(define-public (force-open-circuit (service-name (string-ascii 64)))
  (begin
    (try! (only-owner-guard))
    (let (
      (circuit (unwrap! (map-get? service-circuits { service-name: service-name }) ERR_SERVICE_NOT_FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
      (map-set service-circuits
        { service-name: service-name }
        (merge circuit {
          state: STATE_OPEN,
          last-failure-time: current-time
        })
      )
      (ok true)
    )
  )
)

(define-public (force-close-circuit (service-name (string-ascii 64)))
  (begin
    (try! (only-owner-guard))
    (let (
      (circuit (unwrap! (map-get? service-circuits { service-name: service-name }) ERR_SERVICE_NOT_FOUND))
    )
      (map-set service-circuits
        { service-name: service-name }
        (merge circuit {
          state: STATE_CLOSED,
          failure-count: u0,
          success-count: u0
        })
      )
      (ok true)
    )
  )
)

(define-public (reset-all-circuits)
  (begin
    (try! (only-owner-guard))
    ;; Note: In a real implementation, we'd iterate through all services
    ;; For now, this serves as a template for emergency reset
    (var-set total-failures u0)
    (var-set total-recoveries u0)
    (ok true)
  )
)

;; === READ-ONLY FUNCTIONS ===

(define-read-only (get-owner)
  (var-get contract-owner)
)

(define-read-only (get-circuit-status (service-name (string-ascii 64)))
  (map-get? service-circuits { service-name: service-name })
)

(define-read-only (get-service-config (service-name (string-ascii 64)))
  (map-get? service-configs { service-name: service-name })
)

(define-read-only (get-global-stats)
  {
    total-circuits: (var-get total-circuits),
    total-failures: (var-get total-failures),
    total-recoveries: (var-get total-recoveries),
    failure-threshold: (var-get failure-threshold),
    success-threshold: (var-get success-threshold),
    timeout-duration: (var-get timeout-duration)
  }
)

(define-read-only (calculate-error-rate (service-name (string-ascii 64)))
  (let (
    (circuit (map-get? service-circuits { service-name: service-name }))
  )
    (match circuit
      some-circuit
      (if (> (get total-requests some-circuit) u0)
        (some (/ (* (get failed-requests some-circuit) u10000) (get total-requests some-circuit)))
        (some u0)
      )
      none
    )
  )
)

(define-read-only (is-circuit-healthy (service-name (string-ascii 64)))
  (let (
    (circuit (map-get? service-circuits { service-name: service-name }))
  )
    (match circuit
      some-circuit (is-eq (get state some-circuit) STATE_CLOSED)
      false
    )))
