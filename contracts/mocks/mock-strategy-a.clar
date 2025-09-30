;; mock-strategy-a.clar
;; A simple mock strategy contract for testing the yield optimizer.

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait strategy-trait .all-traits.strategy-trait)
(impl-trait .all-traits.strategy-trait)

(define-public (deposit (asset principal) (amount uint))
  ;; This function is called when the vault transfers funds to this strategy.
  ;; In a real strategy, it would put the funds to work. Here, we just accept them.
  (print { event: "strategy-a-deposit", asset: asset, amount: amount })
  (ok true)
)

(define-public (withdraw (asset principal) (amount uint))
  ;; This function is called by the vault to recall funds.
  (let ((token (contract-of asset)))
    (as-contract (contract-call? token transfer amount (as-contract tx-sender) tx-sender none))
  )
)

(define-read-only (get-balance (asset principal))
  (contract-call? (contract-of asset) get-balance (as-contract tx-sender))
)
