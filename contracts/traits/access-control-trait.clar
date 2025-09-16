;; Access Control Trait - Role-based access control interface
;; Standardized interface for role-based access control

(define-trait access-control-trait
  (
    ;; Role Management
    (has-role (principal (string-ascii 32)) (response bool uint))
    (grant-role (principal (string-ascii 32)) (response bool uint))
    (revoke-role (principal (string-ascii 32)) (response bool uint))
    
    ;; Role-based Access Control
    (only-role ((string-ascii 32)) (response bool uint))
    (only-roles ((list 10 (string-ascii 32))) (response bool uint))
  )
)

;; Standard role definitions
(define-constant ROLE_ADMIN "admin")
(define-constant ROLE_OPERATOR "operator")
(define-constant ROLE_EMERGENCY "emergency")





