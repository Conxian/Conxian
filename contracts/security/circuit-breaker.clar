;; circuit-breaker.clar

(use-trait circuit-breaker-trait .circuit-breaker-trait.circuit-breaker-trait)

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
