;; ============================================================
;; CONXIAN PROTOCOL - BASE CONTRACT (v3.9.2+)
;; ============================================================
;; Base contract with common functionality for all Conxian contracts

(use-trait errors .all-traits.errors)
(use-trait access-control .all-traits.access-control-trait)
(use-trait pausable .all-traits.pausable-trait)
(use-trait math-utils .all-traits.math-utils-trait)

(impl-trait .all-traits.access-control-trait)
(impl-trait .all-traits.pausable-trait)

;; ======================
;; CONSTANTS
;; ======================

(define-constant CONTRACT_VERSION "3.9.2")

;; ======================
;; DATA VARIABLES
;; ======================

;; Contract owner
(define-data-var owner principal tx-sender)

;; Pause state
(define-data-var paused bool false)

;; Reentrancy guard
(define-data-var reentrancy-guard bool false)

;; ======================
;; ACCESS CONTROL
;; ======================

;; Roles (aligned with role-manager.clar)
(define-constant ROLE_ADMIN (string-to-uint "admin"))
(define-constant ROLE_MANAGER (string-to-uint "manager"))
(define-constant ROLE_OPERATOR (string-to-uint "operator"))
(define-constant ROLE_LIQUIDATOR (string-to-uint "liquidator"))

;; Role storage (using same map as role-manager for consistency)
(define-map roles principal uint)

;; ======================
;; MODIFIERS
;; ======================

(define-private (non-reentrant)
  (if (var-get reentrancy-guard)
      (err u1003)  ;; REENTRANCY_GUARD
      (ok true)
  )
)

;; ======================
;; REENTRANCY PROTECTION
;; ======================

(define-private (with-reentrancy-guard (inner (function () (response uint uint))))
  (let (
    { _: (try! (non-reentrant)) }
    (var-set reentrancy-guard true)
    result: (try! (inner))
  )
  (var-set reentrancy-guard false)
  (ok result)
))

;; ======================
;; EVENTS
;; ======================

(define-event OwnershipTransferred 
  ((previous-owner principal) 
   (new-owner principal))
)

(define-event Paused (address: principal))
(define-event Unpaused (address: principal))

(define-event RoleGranted
  ((role uint)
   (account principal)
   (sender principal))
)

(define-event RoleRevoked
  ((role uint)
   (account principal)
   (sender principal))
)

;; ======================
;; MODIFIERS
;; ======================

;; Only allow the contract owner
(define-private (only-owner)
  (if (is-eq tx-sender (var-get owner))
    (ok true)
    (err ERR_NOT_OWNER)
  )
)

;; Only allow when not paused
(define-private (when-not-paused)
  (if (var-get paused)
    (err ERR_CONTRACT_PAUSED)
    (ok true)
  )
)

;; Only allow when paused
(define-private (when-paused)
  (if (var-get paused)
    (ok true)
    (err ERR_CONTRACT_NOT_PAUSED)
  )
)

;; ======================
;; PUBLIC FUNCTIONS
;; ======================

;; Transfer ownership to a new address
(define-public (transfer-ownership (new-owner principal))
  (let (
    (caller tx-sender)
  )
    (try! (only-owner))
    (try! (validate-address new-owner))
    
    (let ((previous-owner (var-get owner)))
      (var-set owner new-owner)
      (emit-ownership-transferred previous-owner new-owner)
      (ok true)
    )
  )
)

;; Pause the contract
(define-public (pause)
  (try! (has-role ROLE_ADMIN))
  (try! (when-not-paused))
  
  (var-set paused true)
  (emit-paused tx-sender)
  (ok true)
)

;; Unpause the contract
(define-public (unpause)
  (try! (has-role ROLE_ADMIN))
  (try! (when-paused))
  
  (var-set paused false)
  (emit-unpaused tx-sender)
  (ok true)
)

;; Grant a role to an address
(define-public (grant-role (role uint) (account principal))
  (try! (has-role ROLE_ADMIN))
  (try! (validate-address account))
  
  (map-set roles account role)
  (emit-role-granted role account tx-sender)
  (ok true)
)

;; Revoke a role from an address
(define-public (revoke-role (role uint) (account principal))
  (try! (has-role ROLE_ADMIN))
  
  (map-delete roles account)
  (emit-role-revoked role account tx-sender)
  (ok true)
)

;; ======================
;; VIEW FUNCTIONS
;; ======================

;; Check if an address has a specific role
(define-read-only (has-role (role uint) (account principal))
  (ok (is-eq (default-to u0 (map-get? roles account)) role))
)

;; Check if the contract is paused
(define-read-only (is-paused)
  (ok (var-get paused))
)

;; Get the current owner
(define-read-only (get-owner)
  (ok (var-get owner))
)

;; Get the contract version
(define-read-only (get-version)
  (ok CONTRACT_VERSION)
)

;; ======================
;; INTERNAL HELPERS
;; ======================

;; Internal function to validate addresses
(define-private (validate-address (addr principal))
  (if (is-eq addr 'ST000000000000000000002AMW42H)
    (err ERR_INVALID_ADDRESS)
    (ok true)
  )
)

;; Internal function to check if sender has a role
(define-private (check-role (role (string-ascii 32)))
  (let (
    (has-role (default-to false (map-get? roles { who: tx-sender, role: role })))
  )
    (if has-role
      (ok true)
      (err ERR_UNAUTHORIZED)
    )
  )
)
