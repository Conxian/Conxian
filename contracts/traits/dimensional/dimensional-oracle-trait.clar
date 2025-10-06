(define-trait dimensional-oracle-trait
  (
    (get-price (asset principal) (response uint (err uint)))
    (update-price (asset principal) (price uint) (response bool (err uint)))
    (add-price-feed (asset principal) (source principal) (response bool (err uint)))
    (remove-price-feed (asset principal) (response bool (err uint)))
  )
)
