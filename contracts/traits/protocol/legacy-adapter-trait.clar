(define-trait legacy-adapter-trait
  (
    (migrate-from-legacy (legacy-contract principal) (amount uint) (response bool (err uint)))
    (get-legacy-balance (user principal) (legacy-contract principal) (response uint (err uint)))
  )
)
