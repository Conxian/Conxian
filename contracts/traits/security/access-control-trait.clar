(define-trait access-control-trait
  (
    ;; Check if an account has a specific role
    (has-role (account principal) (role uint) (response bool (err uint)))

    ;; Get the admin address
    (get-admin () (response principal (err uint)))

    ;; Transfer admin rights
    (set-admin (new-admin principal) (response bool (err uint)))

    ;; Grant a role to an account
    (grant-role (role uint) (account principal) (response bool (err uint)))

    ;; Revoke a role from an account
    (revoke-role (role uint) (account principal) (response bool (err uint)))

    ;; Renounce a role (callable by role holder only)
    (renounce-role (role uint) (response bool (err uint)))

    ;; Get role name by ID
    (get-role-name (role uint) (response (string-ascii 64) (err uint)))

    ;; Check if caller has admin role (convenience function)
    (is-admin (caller principal) (response bool (err uint)))
  )
)
