(define-trait metrics-trait
  (
    (get-apy (strategy principal) (response uint (err uint)))
    (get-yield-efficiency (strategy principal) (response uint (err uint)))
    (get-vault-performance (strategy principal) (response uint (err uint)))
  )
)
