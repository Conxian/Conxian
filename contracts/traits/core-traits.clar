;; Core Traits
;; Defines foundational traits for access control, lifecycle management, and security.

;; ===========================================
;; OWNABLE TRAIT
;; ===========================================
(define-trait ownable-trait (
  (transfer-ownership
    (principal)
    (response bool uint)
  )
  (get-owner
    ()
    (response principal uint)
  )
))

;; ===========================================
;; PAUSABLE TRAIT
;; ===========================================
(define-trait pausable-trait (
  (pause
    ()
    (response bool uint)
  )
  (unpause
    ()
    (response bool uint)
  )
  (is-paused
    ()
    (response bool uint)
  )
))

;; ===========================================
;; REENTRANCY GUARD TRAIT
;; ===========================================
(define-trait reentrancy-guard-trait (
  (with-guard
    ((string-ascii 32))
    (response bool uint)
  )
))

;; ===========================================
;; RBAC TRAIT (Role-Based Access Control)
;; ===========================================
(define-trait rbac-trait (
  (initialize-rbac
    (principal)
    (response bool uint)
  )
  (assign-role
    ((string-ascii 32) principal)
    (response bool uint)
  )
  (revoke-role
    ((string-ascii 32) principal)
    (response bool uint)
  )
  (has-role
    ((string-ascii 32) principal)
    (response bool uint)
  )
  (get-role-principal
    ((string-ascii 32))
    (response (optional principal) uint)
  )
  (transfer-ownership
    (principal)
    (response bool uint)
  )
))

;; Upgradeable trait
(define-trait upgradeable-trait (
  (propose-upgrade
    (principal uint)
    (response bool uint)
  )
  (finalize-upgrade
    (principal uint)
    (response bool uint)
  )
  (migrate
    (uint)
    (response bool uint)
  )
  (get-current-implementation
    ()
    (response principal uint)
  )
  (get-version
    ()
    (response uint uint)
  )
))

;; Queue contract trait
(define-trait queue-contract (
  (enqueue
    ((buff 64))
    (response bool uint)
  )
  (dequeue
    ()
    (response (optional (buff 64)) uint)
  )
  (peek
    ()
    (response (optional (buff 64)) uint)
  )
  (is-empty
    ()
    (response bool uint)
  )
))

;; Controller trait
(define-trait controller (
  (is-system-paused
    ()
    (response bool uint)
  )
  (is-mint-allowed
    (uint)
    (response bool uint)
  )
))

;; Revenue distributor trait
(define-trait revenue-distributor-trait (
  (distribute
    (principal uint principal)
    (response bool uint)
  )
  (report-revenue
    (principal uint principal)
    (response bool uint)
  )
  (set-recipient
    (principal)
    (response bool uint)
  )
))

;; Token coordinator trait
(define-trait token-coordinator-trait (
  (on-transfer
    (uint principal principal)
    (response bool uint)
  )
  (on-mint
    (uint principal)
    (response bool uint)
  )
  (on-burn
    (uint principal)
    (response bool uint)
  )
  (on-dimensional-yield
    (uint uint uint)
    (response bool uint)
  )
))

;; Protocol support trait
(define-trait protocol-support-trait (
  (is-protocol-paused
    ()
    (response bool uint)
  )
))
