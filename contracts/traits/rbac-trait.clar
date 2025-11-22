;; ===========================================
;; RBAC TRAIT
;; ===========================================
;; @desc Trait for Role-Based Access Control (RBAC) contracts.
;; This trait provides functions to manage roles and permissions within the protocol.
;;
;; @example
;; (use-trait rbac .rbac-trait.rbac-trait)
(define-trait rbac-trait
  (
    ;; @desc Checks if the transaction sender has a specific role.
    ;; @param role-name: The name of the role to check.
    ;; @returns (response bool uint): True if the sender has the role, or an error.
    (has-role ((string-ascii 32)) (response bool uint))

    ;; @desc Assigns a role to a principal.
    ;; @param role-name: The name of the role to assign.
    ;; @param authorized-principal: The principal to assign the role to.
    ;; @returns (response bool uint): True if successful, or an error.
    (assign-role ((string-ascii 32) principal) (response bool uint))

    ;; @desc Revokes a role from a principal.
    ;; @param role-name: The name of the role to revoke.
    ;; @returns (response bool uint): True if successful, or an error.
    (revoke-role ((string-ascii 32)) (response bool uint))

    ;; @desc Returns the principal assigned to a specific role.
    ;; @param role-name: The name of the role to query.
    ;; @returns (response (optional principal) uint): The principal if found, or none.
    (get-role-principal ((string-ascii 32)) (response (optional { authorized-principal: principal }) uint))

    ;; @desc Initializes the RBAC contract by setting the initial contract owner.
    ;; @param initial-owner: The principal to be set as the initial contract owner.
    ;; @returns (response bool uint): True if successful, or an error.
    (initialize-rbac (principal) (response bool uint))

    ;; @desc Transfers the contract ownership to a new principal.
    ;; @param new-owner: The principal to transfer ownership to.
    ;; @returns (response bool uint): True if successful, or an error.
    (transfer-ownership (principal) (response bool uint))
  )
)
