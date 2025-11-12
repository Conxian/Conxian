;; contracts/access/traits/access-traits.clar

(define-trait rbac-trait
  (
    (initialize-rbac ((initial-owner principal)) (response bool uint))
    (assign-role ((role-name (string-ascii 32)) (authorized-principal principal)) (response bool uint))
    (revoke-role ((role-name (string-ascii 32))) (response bool uint))
    (has-role ((role-name (string-ascii 32))) (response bool uint))
    (get-role-principal ((role-name (string-ascii 32))) (response (optional principal) uint))
    (transfer-ownership ((new-owner principal)) (response bool uint))
  )
)
