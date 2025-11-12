;; File: contracts/access/roles.clar
;; Role-based access control implementation

(use-trait ownable-trait .ownable.ownable-trait)

(define-constant ERR_NOT_OWNER (err u1000))
(define-constant ERR_ROLE_EXISTS (err u1001))
(define-constant ERR_ROLE_NOT_FOUND (err u1002))
(define-constant ERR_NOT_AUTHORIZED (err u1003))
(define-constant ERR_INVALID_ROLE (err u1004))

;; Role definitions - using string-ascii 32 for role names
(define-constant ROLE_ADMIN "admin")
(define-constant ROLE_MINTER "minter")
(define-constant ROLE_PAUSER "pauser")
(define-constant ROLE_OPERATOR "operator")

;; Data storage for role assignments
(define-map roles {who: principal, role: (string-ascii 32)} bool)

;; ===========================================
;; Public functions
;; ===========================================

;; Grant a role to an address
(define-public (grant-role (who principal) (role (string-ascii 32)))
  (begin
    ;; Only the contract owner can grant roles
    (let ((owner (contract-call? .ownable get-owner)))
      (asserts! (is-ok owner) ERR_NOT_OWNER)
      (asserts! (is-eq tx-sender (unwrap-panic owner)) ERR_NOT_OWNER)
    )
    
    ;; Set the role for the address
    (map-set roles { who: who, role: role } true)
    
    (ok true)
  )
)

;; Revoke a role from an address
(define-public (revoke-role (who principal) (role (string-ascii 32)))
  (begin
    ;; Only the contract owner can revoke roles
    (let ((owner (contract-call? .ownable get-owner)))
      (asserts! (is-ok owner) ERR_NOT_OWNER)
      (asserts! (is-eq tx-sender (unwrap-panic owner)) ERR_NOT_OWNER)
    )
    
    ;; Remove the role from the address
    (map-delete roles { who: who, role: role })
    
    (ok true)
  )
)

;; ===========================================
;; Internal functions
;; ===========================================

;; Internal function to check if the transaction sender has a specific role
(define-private (check-role (role (string-ascii 32)))
  (let ((has-role-val (default-to false (map-get? roles { who: tx-sender, role: role }))))
    (if has-role-val
      (ok true)
      (err ERR_NOT_AUTHORIZED)
    )
  )
)

;; Public function to check if an address has a specific role
(define-read-only (has-role (who principal) (role (string-ascii 32)))
  (ok (default-to false (map-get? roles { who: who, role: role })))
)

;; Convenience functions for common roles
(define-public (grant-admin (who principal))
  (grant-role who ROLE_ADMIN))

(define-public (revoke-admin (who principal))
  (revoke-role who ROLE_ADMIN))

(define-read-only (is-admin (who principal))
  (has-role who ROLE_ADMIN))
