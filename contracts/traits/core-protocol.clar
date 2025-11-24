;; Core Protocol Traits - Production Module

;; ===========================================
;; OWNABLE TRAIT
;; ===========================================
(define-trait ownable-trait
  (
    (get-owner () (response principal uint))
    (set-owner (principal) (response bool uint))
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
;; RBAC (Role-Based Access Control) TRAIT
;; ===========================================
(define-trait rbac-trait
  (
    (has-role ((string-ascii 32) principal) (response bool uint))
    (grant-role ((string-ascii 32) principal) (response bool uint))
    (revoke-role ((string-ascii 32) principal) (response bool uint))
  )
)

;; ===========================================
;; UPGRADEABLE TRAIT
;; ===========================================
(define-trait upgradeable-trait
  (
    (upgrade-contract (principal) (response bool uint))
    (get-implementation () (response principal uint))
  )
)

;; ===========================================
;; REVENUE DISTRIBUTOR TRAIT
;; ===========================================
(define-trait revenue-distributor-trait
  (
    (report-revenue (principal uint principal) (response bool uint))
  )
)

;; ===========================================
;; TOKEN COORDINATOR TRAIT
;; ===========================================
(define-trait token-coordinator-trait
  (
    (on-dimensional-yield (uint uint uint) (response bool uint))
  )
)
