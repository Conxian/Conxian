;; ===========================================
;; BASE TRAITS MODULE
;; ===========================================
;; Core foundational traits for all contracts
;; Fast compilation, minimal dependencies

;; ===========================================
;; OWNABLE TRAIT
;; ===========================================
;; @desc Defines a standard interface for contracts that have a single owner.
;; This trait allows for ownership transfer and verification.
(define-trait ownable-trait
  (
    ;; @desc Gets the current owner of the contract.
    ;; @returns (response principal uint) The principal of the contract owner, or an error code.
    (get-owner () (response principal uint))

    ;; @desc Transfers ownership of the contract to a new principal.
    ;; @param new-owner: The principal of the new owner.
    ;; @returns (response bool uint) A boolean indicating success or failure, or an error code.
    (transfer-ownership (principal) (response bool uint))

    ;; @desc Accepts ownership of the contract. This must be called by the new owner.
    ;; @returns (response bool uint) A boolean indicating success or failure, or an error code.
    (accept-ownership () (response bool uint))

    ;; @desc Checks if a given principal is the owner of the contract.
    ;; @param user: The principal to check.
    ;; @returns (response bool uint) A boolean indicating if the principal is the owner.
    (is-owner (principal) (response bool uint))
  )
)

;; ===========================================
;; PAUSABLE TRAIT
;; ===========================================
;; @desc Defines a standard interface for contracts that can be paused and unpaused.
;; This is often used as a security measure to halt contract activity in case of an emergency.
(define-trait pausable-trait
  (
    ;; @desc Pauses the contract, preventing certain actions from being executed.
    ;; @returns (response bool uint) A boolean indicating success or failure, or an error code.
    (pause () (response bool uint))

    ;; @desc Unpauses the contract, resuming normal activity.
    ;; @returns (response bool uint) A boolean indicating success or failure, or an error code.
    (unpause () (response bool uint))

    ;; @desc Checks if the contract is currently paused.
    ;; @returns (response bool uint) A boolean indicating if the contract is paused.
    (is-paused () (response bool uint))
  )
)

;; ===========================================
;; RBAC TRAIT (Role-Based Access Control)
;; ===========================================
;; @desc Defines a standard interface for contracts that use Role-Based Access Control.
;; This allows for assigning specific roles to principals, granting them permissions to perform certain actions.
(define-trait rbac-trait
  (
    ;; @desc Initializes the RBAC system, typically setting the contract deployer as the initial admin.
    ;; @param admin: The principal to be assigned the initial admin role.
    ;; @returns (response bool uint) A boolean indicating success or failure, or an error code.
    (initialize-rbac (principal) (response bool uint))

    ;; @desc Assigns a role to a principal.
    ;; @param role: The role to assign, represented as a string.
    ;; @param user: The principal to assign the role to.
    ;; @returns (response bool uint) A boolean indicating success or failure, or an error code.
    (assign-role ((string-ascii 32) principal) (response bool uint))

    ;; @desc Revokes a role from the principal currently assigned to it.
    ;; @param role: The role to revoke.
    ;; @returns (response bool uint) A boolean indicating success or failure, or an error code.
    (revoke-role ((string-ascii 32)) (response bool uint))

    ;; @desc Checks if the caller has a specific role.
    ;; @param role: The role to check for.
    ;; @returns (response bool uint) A boolean indicating if the caller has the role.
    (has-role ((string-ascii 32)) (response bool uint))

    ;; @desc Gets the principal assigned to a specific role.
    ;; @param role: The role to query.
    ;; @returns (response (optional principal) uint) The principal assigned to the role, or none if no principal is assigned.
    (get-role-principal ((string-ascii 32)) (response (optional principal) uint))

    ;; @desc Transfers ownership of the RBAC system to a new principal.
    ;; @param new-owner: The principal of the new owner.
    ;; @returns (response bool uint) A boolean indicating success or failure, or an error code.
    (transfer-ownership (principal) (response bool uint))
  )
)

;; ===========================================
;; MATH TRAIT
;; ===========================================
;; @desc Defines a standard interface for common mathematical operations.
(define-trait math-trait
  (
    ;; @desc Multiplies two unsigned integers and divides by a third.
    ;; @param x: The first multiplicand.
    ;; @param y: The second multiplicand.
    ;; @param z: The divisor.
    ;; @returns (response uint uint) The result of (x * y) / z, or an error code.
    (mul-div (uint uint uint) (response uint uint))

    ;; @desc Calculates the integer square root of an unsigned integer.
    ;; @param x: The number to take the square root of.
    ;; @returns (response uint uint) The integer square root of x, or an error code.
    (sqrt (uint) (response uint uint))

    ;; @desc Calculates the power of a number.
    ;; @param base: The base.
    ;; @param exp: The exponent.
    ;; @returns (response uint uint) The result of base^exp, or an error code.
    (pow (uint uint) (response uint uint))

    ;; @desc Calculates the natural logarithm of an unsigned integer.
    ;; @param x: The number to take the natural logarithm of.
    ;; @returns (response uint uint) The natural logarithm of x, or an error code.
    (ln (uint) (response uint uint))
  )
)
