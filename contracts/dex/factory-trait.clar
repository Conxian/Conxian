;; SPDX-License-Identifier: TBD

;; Trait for a DEX Factory
;; This trait defines the standard interface for a DEX factory contract.
;; A DEX factory is responsible for creating and managing liquidity pools.
(define-trait factory-trait
  (
    ;; --- Public Functions ---

    ;; @desc Creates a new liquidity pool of a specified type. This function is the primary entry point for pool creation.
    ;; @param token-a The trait of the first token in the pool. This must conform to the sip-010 standard.
    ;; @param token-b The trait of the second token in the pool. This must also conform to the sip-010 standard.
    ;; @param pool-type (optional (string-ascii 64)) The string identifier of the pool type to create (e.g., "weighted", "stable-swap"). If none is provided, the factory's default pool type will be used.
    ;; @param fee-bps uint The fee for the pool, expressed in basis points (e.g., 30 for 0.30%).
    ;; @param additional-params (optional { tick-spacing: uint, initial-price: uint }) An optional tuple containing additional parameters that may be required for specific pool types, such as `tick-spacing` for concentrated liquidity pools.
    ;; @returns (response principal uint) A response containing the principal of the newly created pool contract or an error code.
    (create-pool (trait_reference, trait_reference, (optional (string-ascii 64)), uint, (optional { tick-spacing: uint, initial-price: uint })) (response principal uint))

    ;; @desc Registers a pool implementation contract for a specific pool type. This allows the factory to be extended with new pool types.
    ;; @param pool-type (string-ascii 64) The string identifier for the pool type.
    ;; @param implementation-contract principal The principal of the smart contract that implements the logic for this pool type.
    ;; @returns (response bool uint) A response indicating `(ok true)` on success or an error if the operation fails.
    (register-pool-implementation ((string-ascii 64), principal) (response bool uint))

    ;; @desc Registers a new pool type with its metadata, making it available for use in the factory.
    ;; @param pool-type (string-ascii 64) The string identifier for the new pool type.
    ;; @param name (string-ascii 32) The human-readable name of the pool type.
    ;; @param description (string-ascii 128) A description of the pool type and its characteristics.
    ;; @param is-active bool A boolean indicating if the pool type is currently active and can be used for new pool creations.
    ;; @returns (response bool uint) A response indicating `(ok true)` on success or an error if the operation fails.
    (register-pool-type ((string-ascii 64), (string-ascii 32), (string-ascii 128), bool) (response bool uint))

    ;; @desc Sets the default pool type for the factory. This pool type will be used when `create-pool` is called without specifying a `pool-type`.
    ;; @param new-default-pool-type (string-ascii 64) The string identifier of the pool type to be set as the new default.
    ;; @returns (response bool uint) A response indicating `(ok true)` on success or an error if the operation fails.
    (set-default-pool-type ((string-ascii 64)) (response bool uint))

    ;; @desc Retrieves the principal of the pool for a given pair of tokens.
    ;; @param token-a principal The principal of the first token in the pair.
    ;; @param token-b principal The principal of the second token in the pair.
    ;; @returns (response (optional principal) uint) A response containing the optional principal of the pool contract if it exists, or `(ok none)` if no pool is found for the pair.
    (get-pool (principal, principal) (response (optional principal) uint))

    ;; @desc Retrieves the pool type for a given pool principal.
    ;; @param pool-principal principal The principal of the pool contract.
    ;; @returns (response (optional (string-ascii 64)) uint) A response containing the optional string identifier of the pool type, or `(ok none)` if the pool is not found.
    (get-pool-type (principal) (response (optional (string-ascii 64)) uint))

    ;; @desc Retrieves the implementation contract for a given pool type.
    ;; @param pool-type (string-ascii 64) The string identifier of the pool type.
    ;; @returns (response (optional principal) uint) A response containing the optional principal of the implementation contract, or `(ok none)` if no implementation is registered for the type.
    (get-pool-implementation ((string-ascii 64)) (response (optional principal) uint))

    ;; @desc Retrieves detailed information about a specific pool.
    ;; @param pool-principal principal The principal of the pool contract.
    ;; @returns (response (optional { token-a: principal, token-b: principal, fee-bps: uint, created-at: uint, additional-params: (optional { tick-spacing: uint, initial-price: uint }) }) uint) A response containing an optional tuple of the pool's information, or `(ok none)` if the pool is not found.
    (get-pool-info (principal) (response (optional { token-a: principal, token-b: principal, fee-bps: uint, created-at: uint, additional-params: (optional { tick-spacing: uint, initial-price: uint }) }) uint))

    ;; @desc Retrieves the total number of liquidity pools created by the factory.
    ;; @returns (response uint uint) A response containing the total count of pools.
    (get-pool-count () (response uint uint))

    ;; @desc Retrieves the default pool type currently set for the factory.
    ;; @returns (response (string-ascii 64) uint) A response containing the string identifier of the default pool type.
    (get-default-pool-type () (response (string-ascii 64) uint))
  )
)
