(define-trait oracle-aggregator-trait
  (
    (add-oracle-feed (token principal) (feed principal) (response bool (err uint)))
    (remove-oracle-feed (token principal) (feed principal) (response bool (err uint)))
    (get-aggregated-price (token principal) (response uint (err uint)))
    (get-feed-count (token principal) (response uint (err uint)))
  )
)
