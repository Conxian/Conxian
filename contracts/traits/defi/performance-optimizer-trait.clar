(define-trait performance-optimizer-trait
  (
    (optimize-strategy (strategy principal) (response bool (err uint)))
    (get-performance-metrics (strategy principal) (response (tuple (apy uint) (tvl uint) (efficiency uint)) (err uint)))
    (rebalance (strategy principal) (response bool (err uint)))
  )
)
