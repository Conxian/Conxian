;; contracts/access/traits/access-traits.clar

;; Role-based access control trait
(define-trait rbac-trait
  (
    ;; Initialize role-based access control
    (initialize-rbac (initial-owner principal) (response bool uint))

    ;; Assign a role to a principal
    (assign-role (role (string-ascii 32)) (principal principal) (response bool uint))

    ;; Revoke a role from a principal
    (revoke-role (role (string-ascii 32)) (principal principal) (response bool uint))

    ;; Check if a principal has a specific role
    (has-role (role (string-ascii 32)) (principal principal) (response bool uint))

    ;; Get the principal assigned to a role
    (get-role-principal (role (string-ascii 32)) (response (optional principal) uint))

    ;; Transfer ownership of the contract
    (transfer-ownership (new-owner principal) (response bool uint))
  )
)
