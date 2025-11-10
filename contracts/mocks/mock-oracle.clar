(define-trait oracle-trait
  (
    (get-price (principal) (response uint uint))
  )
)

(define-public (get-price (asset principal))
  (ok u100000000)
)
