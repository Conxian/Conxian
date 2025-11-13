;; mock-strategy-b.clar
;; A simple mock strategy contract for testing the yield optimizer.

(define-public (deposit (asset principal) (amount uint))
  (begin
    ;; This function is called when the vault transfers funds to this strategy.
    ;; In a real strategy, it would put the funds to work. Here, we just accept them.
    (print { event: "strategy-b-deposit", asset: asset, amount: amount })
    (ok true)
  )
)

(define-public (withdraw (asset principal) (amount uint))
  ;; This function is called by the vault to recall funds.
  (as-contract 
    (contract-call? 
      asset 
      transfer 
      amount 
      (as-contract tx-sender) 
      tx-sender 
      none
    )
  )
)

(define-read-only (get-balance (asset principal))
  (contract-call? 
    asset 
    get-balance 
    (as-contract tx-sender)
  )
)
