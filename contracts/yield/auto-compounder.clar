;; auto-compounder.clar
;; Automatically compounds rewards for LPs.

(define-constant ERR_UNAUTHORIZED (err u9000))

(define-map user-positions { user: principal } {
  strategy-id: uint,
  amount: uint
})

(define-public (deposit (strategy-id uint) (amount uint))
  (begin
    (map-set user-positions { user: tx-sender } { strategy-id: strategy-id, amount: amount })
    (ok true)
  )
)

(define-public (withdraw (amount uint))
  (begin
    (let ((position (unwrap! (map-get? user-positions { user: tx-sender }) (err u0))))
      (map-set user-positions { user: tx-sender } (merge position { amount: (- (get amount position) amount) }))
    )
    (ok true)
  )
)

(define-public (harvest)
  ;; In a real implementation, this would be called by a keeper bot.
  ;; It would claim rewards and re-invest them into the user's position.
  (ok true)
)
