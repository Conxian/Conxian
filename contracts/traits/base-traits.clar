;; ===========================================
;; BASE TRAITS MODULE
;; ===========================================
;; Core foundational traits for all contracts
;; Fast compilation, minimal dependencies

;; ===========================================
;; OWNABLE TRAIT
;; ===========================================
(define-trait ownable-trait
  (
    (get-owner () (response principal uint))
    (transfer-ownership (principal) (response bool uint))
    (accept-ownership () (response bool uint))
    (is-owner (principal) (response bool uint))
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
;; RBAC TRAIT
;; ===========================================
(define-trait rbac-trait
  (
    (initialize-rbac (principal) (response bool uint))
    (assign-role ((string-ascii 32) principal) (response bool uint))
    (revoke-role ((string-ascii 32)) (response bool uint))
    (has-role ((string-ascii 32)) (response bool uint))
    (get-role-principal ((string-ascii 32)) (response (optional principal) uint))
    (transfer-ownership (principal) (response bool uint))
  )
)

;; ===========================================
;; MATH TRAIT
;; ===========================================
(define-trait math-trait
  (
    (mul-div (uint uint uint) (response uint uint))
    (sqrt (uint) (response uint uint))
    (pow (uint uint) (response uint uint))
    (ln (uint) (response uint uint))
  )
)
