;; Access Control Trait
;; Defines the standard interface for role-based access control (RBAC)

(define-trait access-control-trait
  (
    ;; Check if an account has a specific role
    (has-role (account principal) (role uint) (response bool uint))
    
    ;; Get the admin address
    (get-admin () (response principal uint))
    
    ;; Transfer admin rights
    (set-admin (new-admin principal) (response bool uint))
    
    ;; Grant a role to an account
    (grant-role (role uint) (account principal) (response bool uint))
    
    ;; Revoke a role from an account
    (revoke-role (role uint) (account principal) (response bool uint))
    
    ;; Renounce a role (callable by role holder only)
    (renounce-role (role uint) (response bool uint))
    
    ;; Get role name by ID
    (get-role-name (role uint) (response (string-ascii 64) uint))
    
    ;; Check if caller has admin role (convenience function)
    (is-admin (caller principal) (response bool uint))
  )
)

;; Standard Roles
(define-constant ROLE_ADMIN 0x0000000000000000000000000000000000000000000000000000000000000001)  ;; Can grant/revoke all roles
(define-constant ROLE_PAUSER 0x0000000000000000000000000000000000000000000000000000000000000002)  ;; Can pause contracts
(define-constant ROLE_ORACLE_UPDATER 0x0000000000000000000000000000000000000000000000000000000000000004)  ;; Can update oracles
(define-constant ROLE_LIQUIDATOR 0x0000000000000000000000000000000000000000000000000000000000000008  ;; Can perform liquidations
(define-constant ROLE_STRATEGIST 0x0000000000000000000000000000000000000000000000000000000000000010  ;; Can manage strategies

;; Error Codes
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_ROLE (err u101))
(define-constant ERR_ROLE_ALREADY_GRANTED (err u102))
(define-constant ERR_ROLE_NOT_GRANTED (err u103))
(define-constant ERR_INVALID_ADMIN (err u104))
