(define-trait mev-protector-trait
  (
    (check-front-running (tx-hash (buff 32)) (block-height uint) (response bool (err uint)))
    (record-transaction (tx-hash (buff 32)) (block-height uint) (amount uint) (response bool (err uint)))
    (is-protected (user principal) (response bool (err uint)))
  )
)
