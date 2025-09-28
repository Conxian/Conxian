;; Access Control Contract
;; Implements role-based access control (RBAC) for the Conxian protocol

(use-trait access-control-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.access-control-trait)
(use-trait ownable-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.ownable-trait)

(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.access-control-trait)
(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.ownable-trait)

(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_ROLE (err u101))
(define-constant ERR_ROLE_ALREADY_GRANTED (err u102))
(define-constant ERR_ROLE_NOT_GRANTED (err u103))
(define-constant ERR_INVALID_ADMIN (err u104))

;; Role definitions
(define-constant ROLE_ADMIN u1) ;; Can grant/revoke roles
(define-constant ROLE_PAUSER u2) ;; Can pause contracts
(define-constant ROLE_ORACLE_UPDATER u4) ;; Can update oracles
(define-constant ROLE_LIQUIDATOR u8) ;; Can perform liquidations
(define-constant ROLE_STRATEGIST u16) ;; Can manage strategies

;; Role to name mapping for better error messages
(define-map role-names { role: uint } { name: (string-ascii 64) })

;; Role members (role -> set of addresses)
(define-map role-members { role: uint, member: principal } bool)

;; Contract admin
(define-data-var admin principal tx-sender)

;; Initialize role names
(begin
  (map-set role-names { role: ROLE_ADMIN } { name: "ADMIN" })
  (map-set role-names { role: ROLE_PAUSER } { name: "PAUSER" })
  (map-set role-names { role: ROLE_ORACLE_UPDATER } { name: "ORACLE_UPDATER" })
  (map-set role-names { role: ROLE_LIQUIDATOR } { name: "LIQUIDATOR" })
  (map-set role-names { role: ROLE_STRATEGIST } { name: "STRATEGIST" })
  
  ;; Grant admin role to deployer
  (map-set role-members { role: ROLE_ADMIN, member: tx-sender } true)
)

;; ========== Admin Functions ==========

(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (has-role tx-sender ROLE_ADMIN) ERR_NOT_AUTHORIZED)
    (asserts! (is-valid-principal new-admin) ERR_INVALID_ADMIN)
    (var-set admin new-admin)
    (ok true)
  )
)

;; ========== Role Management ==========

(define-read-only (has-role (account principal) (role uint))
  (default-to false (map-get? role-members { role: role, member: account }))
)

(define-read-only (get-role-name (role uint))
  (match (map-get? role-names { role: role })
    role-entry (ok (get name role-entry))
    (err ERR_INVALID_ROLE)
  )
)

(define-public (grant-role (role uint) (account principal))
  (let (
      (role-name (unwrap! (get-role-name role) (err ERR_INVALID_ROLE)))
    )
    (asserts! (has-role tx-sender ROLE_ADMIN) ERR_NOT_AUTHORIZED)
    (asserts! (is-valid-principal account) ERR_INVALID_ADMIN)
    (asserts! (not (has-role account role)) ERR_ROLE_ALREADY_GRANTED)
    
    (map-set role-members { role: role, member: account } true)
    (ok true)
  )
)

(define-public (revoke-role (role uint) (account principal))
  (let (
      (role-name (unwrap! (get-role-name role) (err ERR_INVALID_ROLE)))
    )
    (asserts! (has-role tx-sender ROLE_ADMIN) ERR_NOT_AUTHORIZED)
    (asserts! (has-role account role) ERR_ROLE_NOT_GRANTED)
    
    (map-delete role-members { role: role, member: account })
    (ok true)
  )
)

(define-public (renounce-role (role uint))
  (let (
      (role-name (unwrap! (get-role-name role) (err ERR_INVALID_ROLE)))
    )
    (asserts! (has-role tx-sender role) ERR_NOT_AUTHORIZED)
    
    (map-delete role-members { role: role, member: tx-sender })
    (ok true)
  )
)

;; ========== Modifiers ==========

(define-private (only-role (role uint))
  (let (
      (has-permission (has-role tx-sender role))
    )
    (asserts! has-permission ERR_NOT_AUTHORIZED)
    (ok true)
  )
)

(define-private (only-admin)
  (only-role ROLE_ADMIN)
)

(define-private (only-pauser)
  (only-role ROLE_PAUSER)
)

(define-private (only-oracle-updater ()
  (only-role ROLE_ORACLE_UPDATER)
)

;; ========== Helper Functions ==========

(define-private (is-valid-principal (account principal))
  (not (is-eq account (as-contract tx-sender)))
)

(define-public (renounce-ownership)
  (begin
    (asserts! (has-role tx-sender ROLE_ADMIN) ERR_NOT_AUTHORIZED)
    ;; In a real implementation, you might want to set to a burn address
    (var-set admin tx-sender)
    (ok true)
  )
)
