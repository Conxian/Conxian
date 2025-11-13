;; access-traits.clar
;; Defines access control traits for the Conxian protocol

(define-trait access-control-trait
  (
    ;; Grant a role to a principal
    (grant-role (principal principal) (response bool uint))
    
    ;; Revoke a role from a principal
    (revoke-role (principal principal) (response bool uint))
    
    ;; Check if a principal has a role
    (has-role (principal principal) (response bool uint))
  )
)
