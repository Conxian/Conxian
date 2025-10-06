(define-trait position-nft-trait
  (
    (mint (recipient principal) (liquidity uint) (tick-lower int) (tick-upper int) (response uint (err uint)))
    (burn (token-id uint) (response bool (err uint)))
    (get-position (token-id uint) (response (tuple (owner principal) (liquidity uint) (tick-lower int) (tick-upper int)) (err uint)))
    (trigger-emergency-rebalance () (response bool (err uint)))
    (rebalance-liquidity (threshold uint) (response bool (err uint)))
  )
)
