;; circuit-breaker.clar

(use-trait circuit-breaker-trait .security-monitoring.circuit-breaker-trait)

(define-constant ERR_UNAUTHORIZED (err u5000))

(define-data-var circuit-open bool false)
(define-data-var admin principal tx-sender)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-read-only (is-circuit-open)
  (ok (var-get circuit-open))
)

(define-public (open-circuit)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set circuit-open true)
    (ok true)
  )
)

(define-public (close-circuit)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set circuit-open false)
    (ok true)
  )
)

;; --- Implemented for comprehensive-lending-system compatibility ---

(define-public (record-success (service (string-ascii 32)))
  (ok true)
)

(define-public (record-failure (service (string-ascii 32)))
  (ok true)
)

(define-public (check-circuit-state (service (string-ascii 32)))
  (if (var-get circuit-open)
    (err u5007) ;; ERR_CIRCUIT_BREAKER_OPEN
    (ok true)
  )
)

;; --- Trait Implementation ---

(define-public (trigger-circuit-breaker (reason (string-utf8 200)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set circuit-open true)
    (ok true)
  )
)

(define-public (reset-circuit-breaker)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set circuit-open false)
    (ok true)
  )
)

(define-public (is-circuit-broken)
  (ok (var-get circuit-open))
)

(define-public (assert-operational)
  (if (var-get circuit-open)
    (err u5007)
    (ok true)
  )
)
