;; Pool Trait - DEX pool interface for AMM functionality
;; Supports multiple pool types with enhanced tokenomics integration

(define-trait pool-trait
  (
    ;; Core AMM operations
    (swap-exact-in (uint uint bool uint) (response (tuple (amount-out uint) (fee uint)) uint))
    (add-liquidity (uint uint uint) (response (tuple (shares uint) (amount-a uint) (amount-b uint)) uint))
    (remove-liquidity (uint uint uint) (response (tuple (amount-a uint) (amount-b uint)) uint))
    
    ;; Pool information
    (get-reserves () (response (tuple (reserve-a uint) (reserve-b uint)) uint))
    (get-fee-info () (response (tuple (lp-fee-bps uint) (protocol-fee-bps uint)) uint))
    (get-price () (response (tuple (price-x-y uint) (price-y-x uint)) uint))
    (get-total-supply () (response uint uint))
    
    ;; Pool assets
    (get-token-a () (response principal uint))
    (get-token-b () (response principal uint))
    
    ;; Enhanced tokenomics integration
    (collect-protocol-fees () (response (tuple (fee-a uint) (fee-b uint)) uint))
    (get-pool-performance () (response (tuple (volume-24h uint) (fees-24h uint)) uint))
    (update-reward-distribution () (response bool uint))
  )
)



