

;; circuit-breaker.clar

;; Implements the enhanced circuit breaker pattern

;; ===== Constants =====(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_CIRCUIT_OPEN (err u1002))
(define-constant ERR_INVALID_OPERATION (err u1003))
(define-constant ERR_INVALID_THRESHOLD (err u1004))
(define-constant ERR_INVALID_TIMEOUT (err u1005))
(define-constant ERR_EMERGENCY_SHUTDOWN (err u1006))
(define-constant ERR_RATE_LIMIT_EXCEEDED (err u1007))
(define-constant ERR_INVALID_RATE_LIMIT (err u1008))
(define-constant ERR_INVALID_RATE_WINDOW (err u1009))

;; Defaults and limits
(define-constant DEFAULT_THRESHOLD u5000)
(define-constant DEFAULT_TIMEOUT u144)
(define-constant MAX_RATE_WINDOW u10080)
(define-constant MAX_THRESHOLD u10000)

;; ===== State =====
(define-data-var admin principal tx-sender)
(define-data-var global-failure-threshold uint DEFAULT_THRESHOLD)
(define-data-var global-reset-timeout uint DEFAULT_TIMEOUT)
(define-data-var emergency-shutdown-active bool false)
(define-data-var circuit-mode (optional bool) none)

(define-map operation-stats (string-ascii 64)
  (tuple
    (success-count uint)
    (failure-count uint)
    (last-updated uint)
    (is-open bool)
    (last-state-change uint)
    (rate-limit uint)
    (rate-window uint)
    (rate-count uint)
    (rate-window-start uint)
  )
)

;; ===== Helpers =====
(define-private (get-default-stats (current-time uint))
  (tuple
    (success-count u0)
    (failure-count u0)
    (last-updated current-time)
    (is-open false)
    (last-state-change current-time)
    (rate-limit u0)
    (rate-window u0)
    (rate-count u0)
    (rate-window-start current-time)
  )
)

(define-private (calculate-failure-rate (success-count uint) (failure-count uint))
  (let ((total (+ success-count failure-count)))
    (if (is-eq total u0)
      u0
      (/ (* failure-count u10000) total)
    )
  )
)
;; ===== Admin Functions =====
(define-public (set-circuit-state (operation (string-ascii 64)) (state bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (let ((stats (default-to (get-default-stats block-height)
                           (map-get? operation-stats operation))))
      (map-set operation-stats operation
        (merge stats (tuple
          (is-open state)
          (last-state-change block-height)
        )))
      (ok true)
    )
  )
)

(define-public (set-failure-threshold (threshold uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (and (>= threshold u0) (<= threshold u10000)) ERR_INVALID_THRESHOLD)
    ;; 0-10000 (0-100%)
    (var-set global-failure-threshold threshold)
    (ok true)
  )
)

(define-public (set-reset-timeout (timeout uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (> timeout u0) ERR_INVALID_TIMEOUT)
    (var-set global-reset-timeout timeout)
    (ok true)
  )
)

(define-public (set-rate-limit (operation (string-ascii 64)) (limit uint) (window uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (> limit u0) ERR_INVALID_RATE_LIMIT)
    (asserts! (and (> window u0) (<= window MAX_RATE_WINDOW)) ERR_INVALID_RATE_WINDOW)
    (let ((stats (default-to (get-default-stats block-height)
                           (map-get? operation-stats operation))))
      (map-set operation-stats operation
        (merge stats (tuple
          (rate-limit limit)
          (rate-window window)
          (rate-count u0)
          (rate-window-start block-height)
        )))
      (ok true)
    )
  )
)
(define-public (set-circuit-mode (mode (optional bool)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set circuit-mode mode)
    (ok true)
  )
)

(define-public (emergency-shutdown)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set emergency-shutdown-active true)
    (ok true)
  )
)

(define-public (recover-from-shutdown)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set emergency-shutdown-active false)
    (ok true)
  )
)

;; ===== Read-Only Functions =====
(define-read-only (get-rate-limit (operation (string-ascii 64)))
  (let ((stats (default-to (get-default-stats block-height)
                         (map-get? operation-stats operation)))
        (window-end (+ (get rate-window-start stats) (get rate-window stats))))
    (ok (tuple
      (limit (get rate-limit stats))
      (window (get rate-window stats))
      (current (get rate-count stats))
      (reset-time window-end)
    ))
  )
)

(define-read-only (get-circuit-mode)
  (ok (var-get circuit-mode))
)

(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-read-only (get-health-status)
  (ok (tuple
    (is_operational (not (var-get emergency-shutdown-active)))
    (total_failure_rate u0)
    (last_checked block-height)
    (uptime u100)
    (total_operations u0)
    (failed_operations u0)
  ))
)

;; ===== Ownable Trait Implementation =====
(define-read-only (get-owner)
  (ok (var-get admin))
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (renounce-ownership)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    ;; In a real implementation, you might want to set to a burn address
    (var-set admin tx-sender)
    (ok true)
  )
)