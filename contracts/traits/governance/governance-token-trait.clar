(define-trait governance-token-trait
  (
    (delegate (delegatee principal) (response bool (err uint)))
    (get-voting-power (account principal) (response uint (err uint)))
    (get-prior-votes (account principal) (block-height uint) (response uint (err uint)))
  )
)
