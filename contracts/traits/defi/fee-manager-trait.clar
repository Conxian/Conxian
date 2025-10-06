(define-trait fee-manager-trait
  (
    (get-fee-rate (pool principal) (tier uint) (response uint (err uint)))
    (set-fee-rate (pool principal) (tier uint) (rate uint) (response bool (err uint)))
    (collect-fees (pool principal) (response uint (err uint)))
    (distribute-fees (pool principal) (amount uint) (response bool (err uint)))
  )
)
