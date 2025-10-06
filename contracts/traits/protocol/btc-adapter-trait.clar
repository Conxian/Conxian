(define-trait btc-adapter-trait
  (
    (wrap-btc (amount uint) (btc-tx-id (buff 32)) (response uint (err uint)))
    (unwrap-btc (amount uint) (btc-address (buff 64)) (response bool (err uint)))
    (get-wrapped-balance (user principal) (response uint (err uint)))
  )
)
