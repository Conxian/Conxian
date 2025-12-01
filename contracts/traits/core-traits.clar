;; Core Traits
;; Defines foundational traits for access control, lifecycle management, and security.

;; ===========================================
;; OWNABLE TRAIT
;; ===========================================
(define-trait ownable-trait
  (
    (transfer-ownership (principal) (response bool uint))
    (get-owner () (response principal uint))
  )
)

;; ===========================================
;; PAUSABLE TRAIT
;; ===========================================
(define-trait pausable-trait
  (
    (pause () (response bool uint))
    (unpause () (response bool uint))
    (is-paused () (response bool uint))
  )
)

;; ===========================================
;; REENTRANCY GUARD TRAIT
;; ===========================================
(define-trait reentrancy-guard-trait
  (
    (with-guard ((string-ascii 32)) (response bool uint))
  )
)

;; ===========================================
;; RBAC TRAIT (Role-Based Access Control)
;; ===========================================
(define-trait rbac-trait
  (
    (initialize-rbac (principal) (response bool uint))
    (assign-role ((string-ascii 32) principal) (response bool uint))
    (revoke-role ((string-ascii 32) principal) (response bool uint))
    (has-role ((string-ascii 32) principal) (response bool uint))
    (get-role-principal ((string-ascii 32)) (response (optional principal) uint))
    (transfer-ownership (principal) (response bool uint))
  )
)
