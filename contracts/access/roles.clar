;; @desc Role-based access control implementation.
;; This contract provides a simple implementation of role-based access control (RBAC),
;; allowing the contract owner to grant and revoke roles to other principals.

(use-trait rbac-trait .core-traits.rbac-trait)
(impl-trait .core-traits.rbac-trait)

;; @data-vars
;; @var contract-owner: The principal of the contract owner.
(define-data-var contract-owner principal tx-sender)

;; @constants
;; @var ERR_NOT_OWNER: The caller is not the owner of the contract.
(define-constant ERR_NOT_OWNER (err u1002))
;; @var ERR_ROLE_EXISTS: The specified role already exists.
(define-constant ERR_ROLE_EXISTS (err u7009))
;; @var ERR_ROLE_NOT_FOUND: The specified role was not found.
(define-constant ERR_ROLE_NOT_FOUND (err u7010))
;; @var ERR_NOT_AUTHORIZED: The caller is not authorized to perform this action.
(define-constant ERR_NOT_AUTHORIZED (err u1001))
;; @var ERR_INVALID_ROLE: The specified role is invalid.
(define-constant ERR_INVALID_ROLE (err u7008))
;; @var ROLE_ADMIN: The admin role.
(define-constant ROLE_ADMIN "admin")
;; @var ROLE_MINTER: The minter role.
(define-constant ROLE_MINTER "minter")
;; @var ROLE_PAUSER: The pauser role.
(define-constant ROLE_PAUSER "pauser")
;; @var ROLE_OPERATOR: The operator role.
(define-constant ROLE_OPERATOR "operator")

;; @data-vars
;; @var roles: A map of principals to their roles.
(define-map roles {who: principal, role: (string-ascii 32)} bool)

;; ===========================================
;; Public functions
;; ===========================================

;; @desc Grant a role to an address.
;; @param who: The principal to grant the role to.
;; @param role: The role to grant.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (grant-role (role (string-ascii 32)) (who principal))
  (begin
    ;; Only the contract owner can grant roles
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    
    ;; Set the role for the address
    (map-set roles { who: who, role: role } true)
    
    (ok true)
  )
)

;; @desc Revoke a role from an address.
;; @param who: The principal to revoke the role from.
;; @param role: The role to revoke.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (revoke-role (role (string-ascii 32)) (who principal))
  (begin
    ;; Only the contract owner can revoke roles
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    
    ;; Remove the role from address
    (map-delete roles { who: who, role: role })
    
    (ok true)
  )
)

;; @desc Check if a principal has a specific role.
;; @param who: The principal to check.
;; @param role: The role to check for.
;; @returns (response bool uint): An `ok` response with `true` if the principal has the role, `false` otherwise.
(define-public (has-role (role (string-ascii 32)) (who principal))
  (ok (default-to false (map-get? roles { who: who, role: role })))
)

;; @desc Initialize the access control contract.
;; @param initial-owner: The principal of the initial owner.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (initialize-access-control (initial-owner principal))
  (begin
    (asserts! (is-eq tx-sender (as-contract tx-sender)) ERR_NOT_OWNER)
    (var-set contract-owner initial-owner)
    (ok true)
  )
)

;; @desc Transfer ownership of the contract.
;; @param new-owner: The principal of the new owner.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Grant the admin role to a principal.
;; @param who: The principal to grant the admin role to.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (grant-admin (who principal))
  (grant-role ROLE_ADMIN who))

;; @desc Revoke the admin role from a principal.
;; @param who: The principal to revoke the admin role from.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (revoke-admin (who principal))
  (revoke-role ROLE_ADMIN who))

;; @desc Check if a principal has the admin role.
;; @param who: The principal to check.
;; @returns (response bool uint): An `ok` response with `true` if the principal has the admin role, `false` otherwise.
(define-public (is-admin (who principal))
  (has-role ROLE_ADMIN who))
