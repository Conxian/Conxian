;; access-traits.clar
;; @desc Defines access control traits for the Conxian protocol.
;; This trait provides a simplified interface for role management.
(define-trait access-control-trait
  (
    ;; @desc Grant a role to a principal.
    ;; @param role: The role to grant.
    ;; @param user: The principal to grant the role to.
    ;; @returns (response bool uint) True if successful, otherwise an error.
    (grant-role (principal principal) (response bool uint))
    
    ;; @desc Revoke a role from a principal.
    ;; @param role: The role to revoke.
    ;; @param user: The principal to revoke the role from.
    ;; @returns (response bool uint) True if successful, otherwise an error.
    (revoke-role (principal principal) (response bool uint))
    
    ;; @desc Check if a principal has a role.
    ;; @param role: The role to check for.
    ;; @param user: The principal to check.
    ;; @returns (response bool uint) True if the principal has the role, otherwise false.
    (has-role (principal principal) (response bool uint))
  )
)
