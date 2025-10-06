(define-trait liquidity-manager-trait
  (
    (get-utilization () (response uint (err uint)))
    (get-yield-rate () (response uint (err uint)))
    (get-risk-score () (response uint (err uint)))
    (get-performance-score () (response uint (err uint)))
    (rebalance-liquidity (threshold uint) (response bool (err uint)))
    (trigger-emergency-rebalance () (response bool (err uint)))
  )
)
