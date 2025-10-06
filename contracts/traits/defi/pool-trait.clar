(define-trait pool-trait
  (
    (add-liquidity (amount-a uint) (amount-b uint) (recipient principal) (response (tuple (tokens-minted uint) (token-a-used uint) (token-b-used uint)) (err uint)))
    (remove-liquidity (amount uint) (recipient principal) (response (tuple (token-a-returned uint) (token-b-returned uint)) (err uint)))
    (swap (token-in principal) (amount-in uint) (recipient principal) (response uint (err uint)))
    (get-reserves () (response (tuple (reserve-a uint) (reserve-b uint)) (err uint)))
    (get-total-supply () (response uint (err uint)))
  )
)
