;; File: contracts/access/roles.clar
;; Role-based access control implementation

(use-trait "access-control-trait" .access-control-trait.access-control-trait)

;; Implement access control
(impl-trait .access-control-trait.access-control-trait)

;; Owner data variable
(define-data-var contract-owner principal tx-sender)

(define-constant ERR_NOT_OWNER (err u1000))
(define-constant ERR_ROLE_EXISTS (err u2000))
(define-constant ERR_ROLE_NOT_FOUND (err u2001))
(define-constant ERR_NOT_AUTHORIZED (err u2002))
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
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    
    ;; Set the role for the address
    (map-set roles { who: who, role: role } true)
    
    (ok true)
  )
)

;; Revoke a role from the transaction sender
(define-public (revoke-role (role-name (string-ascii 32)))
  (begin
    ;; Only the contract owner can revoke roles
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    
    ;; Remove the role from tx-sender
    (map-delete roles { who: tx-sender, role: role-name })
    
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
(define-read-only (has-role (role-name (string-ascii 32)))
  (ok (default-to false (map-get? roles { who: tx-sender, role: role-name })))
)

;; Get the principal assigned to a role
(define-read-only (get-role-principal (role-name (string-ascii 32)))
  (ok (some { authorized-principal: (var-get contract-owner) }))
)

;; Initialize access control
(define-public (initialize-access-control (initial-owner principal))
  (begin
    (asserts! (is-eq tx-sender (as-contract tx-sender)) ERR_NOT_OWNER)
    (var-set contract-owner initial-owner)
    (ok true)
  )
)

;; Transfer ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Convenience functions for common roles
(define-public (grant-admin (who principal))
  (grant-role who ROLE_ADMIN))

(define-public (revoke-admin (who principal))
  (revoke-role who ROLE_ADMIN))

(define-read-only (is-admin (who principal))
  (has-role who ROLE_ADMIN))
