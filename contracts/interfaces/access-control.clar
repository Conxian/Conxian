(define-trait access-control-trait
  (
    (has-role (uint principal) (response bool uint))
    (grant-role (uint principal) (response bool uint))
    (revoke-role (uint principal) (response bool uint))
  )
)

