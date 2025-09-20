;; Circuit Breaker Implementation
;; Implements a circuit breaker pattern for protecting critical operations

(use-trait circuit-breaker-admin-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.circuit-breaker-admin-trait)
(use-trait ownable-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.ownable-trait)

(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_THRESHOLD (err u101))
(define-constant ERR_INVALID_TIMEOUT (err u102))
(define-constant ERR_CIRCUIT_OPEN (err u103))
(define-constant ERR_INVALID_OPERATION (err u104))

;; Circuit states
(define-constant STATE_CLOSED u0)    ;; Normal operation
(define-constant STATE_OPEN u1)      ;; Circuit is open, all operations blocked
(define-constant STATE_HALF_OPEN u2) ;; Testing if error condition is resolved

;; Default configuration
(define-constant DEFAULT_FAILURE_THRESHOLD u300)  ;; 3% failure rate
(define-constant DEFAULT_RESET_TIMEOUT u100)      ;; ~100 blocks (~16 hours)
(define-constant WINDOW_SIZE u1000)               ;; Last 1000 operations

;; Admin address
(define-data-var admin principal tx-sender)

;; Circuit configuration
(define-map circuit-config
  { operation: (string-ascii 64) }
  {
    failure-threshold: uint,
    reset-timeout: uint,
    last-reset: uint
  }
)

;; Operation tracking
(define-map operation-stats
  { operation: (string-ascii 64) }
  {
    success-count: uint,
    failure-count: uint,
    last-updated: uint,
    state: uint,  ;; CLOSED, OPEN, or HALF_OPEN
    last-state-change: uint
  }
)

;; Operation history (for rolling window)
(define-map operation-history
  { operation: (string-ascii 64), index: uint }
  bool  ;; true for success, false for failure
)

;; ========== Admin Functions ==========

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-failure-threshold (operation (string-ascii 64)) (threshold uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (asserts! (<= threshold u10000) ERR_INVALID_THRESHOLD)  ;; Max 100% in basis points
    
    (match (map-get? circuit-config {operation: operation})
      config => 
        (map-set circuit-config 
          {operation: operation} 
          (merge (unwrap-panic config) {
            failure-threshold: threshold
          })
        )
      _ =>
        (map-set circuit-config 
          {operation: operation} 
          {
            failure-threshold: threshold,
            reset-timeout: DEFAULT_RESET_TIMEOUT,
            last-reset: block-height
          }
        )
    )
    (ok true)
  )
)

(define-public (set-reset-timeout (operation (string-ascii 64)) (timeout uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (asserts! (> timeout u0) ERR_INVALID_TIMEOUT)
    
    (match (map-get? circuit-config {operation: operation})
      config => 
        (map-set circuit-config 
          {operation: operation} 
          (merge (unwrap-panic config) {
            reset-timeout: timeout
          })
        )
      _ =>
        (map-set circuit-config 
          {operation: operation} 
          {
            failure-threshold: DEFAULT_FAILURE_THRESHOLD,
            reset-timeout: timeout,
            last-reset: block-height
          }
        )
    )
    (ok true)
  )
)

(define-public (set-circuit-state (operation (string-ascii 64)) (state bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    
    (let ((new-state (if state STATE_CLOSED STATE_OPEN)))
      (match (map-get? operation-stats {operation: operation})
        stats =>
          (map-set operation-stats 
            {operation: operation} 
            (merge (unwrap-panic stats) {
              state: new-state,
              last-state-change: block-height
            })
          )
        _ => 
          (map-set operation-stats 
            {operation: operation} 
            {
              success-count: u0,
              failure-count: u0,
              last-updated: block-height,
              state: new-state,
              last-state-change: block-height
            }
          )
      )
      (ok true)
    )
  )
)

;; ========== Circuit Logic ==========

(define-public (check-circuit-state (operation (string-ascii 64)))
  (let ((current-block (block-height)))
    (match (map-get? operation-stats {operation: operation})
      stats =>
        (let ((state (get state (unwrap-panic stats)))
              (last-state-change (get last-state-change (unwrap-panic stats)))
              (config (default-to 
                {
                  failure-threshold: DEFAULT_FAILURE_THRESHOLD,
                  reset-timeout: DEFAULT_RESET_TIMEOUT,
                  last-reset: current-block
                } 
                (map-get? circuit-config {operation: operation})
              ))
              (reset-timeout (get reset-timeout (unwrap-panic config))))
          
          ;; Check if we should transition from OPEN to HALF_OPEN
          (if (and (is-eq state STATE_OPEN)
                   (>= (- current-block last-state-change) reset-timeout))
            (begin
              (map-set operation-stats 
                {operation: operation} 
                (merge (unwrap-panic stats) {
                  state: STATE_HALF_OPEN,
                  last-state-change: current-block,
                  success-count: u0,
                  failure-count: u0
                })
              )
              (ok false)  ;; Still consider it open for this check
            )
            (ok (or (is-eq state STATE_CLOSED) 
                   (is-eq state STATE_HALF_OPEN)))
          )
        )
      _ => (ok true)  ;; Default to closed if no state exists
    )
  )
)

(define-public (record-success (operation (string-ascii 64)))
  (let ((current-block (block-height)))
    (match (map-get? operation-stats {operation: operation})
      stats =>
        (let ((state (get state (unwrap-panic stats)))
              (success-count (get success-count (unwrap-panic stats)))
              (failure-count (get failure-count (unwrap-panic stats))))
          
          ;; If in HALF_OPEN with enough successes, close the circuit
          (if (and (is-eq state STATE_HALF_OPEN) 
                  (>= (+ success-count u1) 10))  ;; Need 10 successes to close
            (begin
              (map-set operation-stats 
                {operation: operation} 
                (merge (unwrap-panic stats) {
                  state: STATE_CLOSED,
                  last-state-change: current-block,
                  success-count: u0,
                  failure-count: u0
                })
              )
              (map-set circuit-config
                {operation: operation}
                (merge 
                  (default-to 
                    {
                      failure-threshold: DEFAULT_FAILURE_THRESHOLD,
                      reset-timeout: DEFAULT_RESET_TIMEOUT,
                      last-reset: current-block
                    } 
                    (map-get? circuit-config {operation: operation})
                  )
                  {
                    last-reset: current-block
                  }
                )
              )
            )
            ;; Otherwise just update the success count
            (map-set operation-stats 
              {operation: operation} 
              (merge (unwrap-panic stats) {
                success-count: (+ success-count u1),
                last-updated: current-block
              })
            )
          )
          (ok true)
        )
      _ => 
        (map-set operation-stats 
          {operation: operation} 
          {
            success-count: u1,
            failure-count: u0,
            last-updated: current-block,
            state: STATE_CLOSED,
            last-state-change: current-block
          }
        )
    )
    (ok true)
  )
)

(define-public (record-failure (operation (string-ascii 64)))
  (let ((current-block (block-height)))
    (match (map-get? operation-stats {operation: operation})
      stats =>
        (let ((state (get state (unwrap-panic stats)))
              (success-count (get success-count (unwrap-panic stats)))
              (failure-count (get failure-count (unwrap-panic stats)))
              (config (default-to 
                {
                  failure-threshold: DEFAULT_FAILURE_THRESHOLD,
                  reset-timeout: DEFAULT_RESET_TIMEOUT,
                  last-reset: current-block
                } 
                (map-get? circuit-config {operation: operation})
              ))
              (failure-threshold (get failure-threshold (unwrap-panic config)))
              (total-operations (+ success-count failure-count u1)))
          
          ;; If in HALF_OPEN, any failure reopens the circuit
          (if (is-eq state STATE_HALF_OPEN)
            (map-set operation-stats 
              {operation: operation} 
              (merge (unwrap-panic stats) {
                state: STATE_OPEN,
                last-state-change: current-block,
                failure-count: (+ failure-count u1)
              })
            )
            
            ;; In CLOSED state, check if we should open the circuit
            (let ((failure-rate (* (/ (+ failure-count u1) total-operations) u10000)))
              (if (and (>= total-operations 10)  ;; Need at least 10 operations
                       (>= failure-rate failure-threshold))
                (map-set operation-stats 
                  {operation: operation} 
                  (merge (unwrap-panic stats) {
                    state: STATE_OPEN,
                    last-state-change: current-block,
                    failure-count: (+ failure-count u1)
                  })
                )
                (map-set operation-stats 
                  {operation: operation} 
                  (merge (unwrap-panic stats) {
                    failure-count: (+ failure-count u1),
                    last-updated: current-block
                  })
                )
              )
            )
          )
          (ok true)
        )
      _ => 
        (map-set operation-stats 
          {operation: operation} 
          {
            success-count: u0,
            failure-count: u1,
            last-updated: current-block,
            state: STATE_CLOSED,  ;; Start closed even on first failure
            last-state-change: current-block
          }
        )
    )
    (ok true)
  )
)

;; ========== Read-Only Functions ==========

(define-read-only (get-failure-rate (operation (string-ascii 64)))
  (match (map-get? operation-stats {operation: operation})
    stats =>
      (let ((success-count (get success-count (unwrap-panic stats)))
            (failure-count (get failure-count (unwrap-panic stats))))
        (if (is-eq (+ success-count failure-count) u0)
          (ok u0)
          (ok (* (/ failure-count (+ success-count failure-count)) u10000))  ;; In basis points
      ))
    _ => (ok u0)  ;; No failures if no stats
  )
)

(define-read-only (get-circuit-state (operation (string-ascii 64)))
  (match (map-get? operation-stats {operation: operation})
    stats =>
      (let ((state (get state (unwrap-panic stats)))
            (last-checked (get last-updated (unwrap-panic stats)))
            (success-count (get success-count (unwrap-panic stats)))
            (failure-count (get failure-count (unwrap-panic stats))))
        (ok {
          state: state,
          last-checked: last-checked,
          failure-rate: (if (is-eq (+ success-count failure-count) u0)
                          u0
                          (* (/ failure-count (+ success-count failure-count)) u10000))
        })
      )
    _ => (ok {
      state: STATE_CLOSED,
      last-checked: block-height,
      failure-rate: u0
    })
  )
)

(define-read-only (get-admin)
  (ok (var-get admin))
)
