(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(impl-trait .defi-traits.pool-trait)

(define-public (swap
    (amount-in uint)
    (token-in <sip-010-ft-trait>)
    (token-out <sip-010-ft-trait>)
  )
  (ok amount-in)
)

(define-public (add-liquidity
    (amount0 uint)
    (amount1 uint)
    (token0 <sip-010-ft-trait>)
    (token1 <sip-010-ft-trait>)
  )
  (ok u0)
)

(define-public (remove-liquidity
    (position-id uint)
    (token0 <sip-010-ft-trait>)
    (token1 <sip-010-ft-trait>)
  )
  (ok {
    amount0: u0,
    amount1: u0,
  })
)

(define-read-only (get-reserves)
  (ok {
    reserve0: u0,
    reserve1: u0,
  })
)
