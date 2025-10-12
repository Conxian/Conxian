;; mock-strategy-a.clar
;; A simple mock strategy contract for testing the yield optimizer.

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)

(define-public (deposit (asset <sip-010-ft-trait>) (amount uint))
  (begin
    ;; This function is called when the vault transfers funds to this strategy.
    ;; In a real strategy, it would put the funds to work. Here, we just accept them.
    (print { event: "strategy-a-deposit", asset: asset, amount: amount })
    (ok true)))

(define-public (withdraw (asset <sip-010-ft-trait>) (amount uint))
  ;; This function is called by the vault to recall funds.
  (as-contract (contract-call? asset transfer amount (as-contract tx-sender) tx-sender none))
)

(define-public (get-balance (asset <sip-010-ft-trait>))
  (contract-call? asset get-balance (as-contract tx-sender))
)

