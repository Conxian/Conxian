;; risk-manager.clar
;; Enforces risk management rules for the Conxian DEX.

(define-constant ERR_UNAUTHORIZED (err u12000))
(define-constant ERR_POSITION_LIMIT_EXCEEDED (err u12001))

(define-map user-positions { user: principal } {
  value: uint
})

(define-data-var position-limit uint u1000000) ;; $1,000,000

(define-public (set-position-limit (new-limit uint))
  (begin
    (asserts! (is-eq tx-sender .admin) ERR_UNAUTHORIZED)
    (var-set position-limit new-limit)
    (ok true)
  )
)

(define-public (check-position-limit (user principal) (trade-value uint))
  (let ((position-value (default-to u0 (get value (map-get? user-positions { user: user })))))
    (asserts! (<= (+ position-value trade-value) (var-get position-limit)) ERR_POSITION_LIMIT_EXCEEDED)
    (ok true)
  )
)

(define-public (update-position-value (user principal) (new-value uint))
  (begin
    (asserts! (is-eq tx-sender .order-book) ERR_UNAUTHORIZED)
    (map-set user-positions { user: user } { value: new-value })
    (ok true)
  )
)
