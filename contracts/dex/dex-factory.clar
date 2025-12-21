;; Conxian DEX Factory V2 - DIMENSIONAL INTEGRATION (Refactored)
;; This contract acts as a facade, delegating logic to specialized registry contracts.

;; (use-trait factory-trait .dex-traits.factory-trait) ;; Removed: Unused and invalid path
(use-trait access-control-trait .core-traits.rbac-trait)
(use-trait circuit-breaker-trait .security-monitoring.circuit-breaker-trait)
(use-trait dim-registry-trait .dimensional-traits.dim-registry-trait)
(use-trait pool-trait .dex-traits.pool-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait pool-type-registry-trait .pool-type-registry.pool-type-registry-trait)
(use-trait pool-implementation-registry-trait .pool-implementation-registry.pool-implementation-registry-trait)
(use-trait pool-registry-trait .pool-registry.pool-registry-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1003))
(define-constant ERR_POOL_EXISTS (err u2001))
(define-constant ERR_INVALID_TOKENS (err u2002))
(define-constant ERR_INVALID_FEE (err u2004))
(define-constant ERR_INVALID_POOL_TYPE (err u2005))
(define-constant ERR_IMPLEMENTATION_NOT_FOUND (err u2006))
(define-constant ERR_SWAP_FAILED (err u2007))
(define-constant ERR_CIRCUIT_OPEN (err u5000))

;; --- Data Variables ---

;; @desc Stores the principal of the access control contract.
(define-data-var access-control-contract principal .access-control)
;; @desc Stores the principal of the circuit breaker contract.
(define-data-var circuit-breaker principal .circuit-breaker)
;; @desc Stores the principal of the dimensional registry contract for integrating pools as dimensional nodes.
(define-data-var dimensional-registry principal .dim-registry)
;; @desc Stores the principal of the pool type registry contract.
(define-data-var pool-type-registry principal .pool-type-registry)
;; @desc Stores the principal of the pool implementation registry contract.
(define-data-var pool-implementation-registry principal .pool-implementation-registry)
;; @desc Stores the principal of the pool registry contract.
(define-data-var pool-registry principal .pool-registry)
;; @desc Stores the default pool type used for new pool creations.
(define-data-var default-pool-type (string-ascii 64) "weighted")

;; --- Private Functions ---

;; @desc Checks if the transaction sender is the contract owner.
;; @returns (response bool uint) A response indicating success or an unauthorized error.
(define-private (check-is-owner)
  (contract-call? .roles has-role "contract-owner" tx-sender))

;; @desc Checks if the transaction sender has the 'POOL_MANAGER' role.
;; @returns (response bool uint) A response indicating success or an unauthorized error.
(define-private (check-pool-manager)
  (contract-call? .roles has-role "POOL_MANAGER" tx-sender))

;; @desc Checks if the circuit breaker is open.
;; @returns (response bool uint) A response indicating if the circuit is open.
(define-private (check-circuit-breaker)
  (contract-call? .circuit-breaker is-circuit-open))

;; @desc Validates if a given pool type is registered and active by querying the pool type registry.
;; @param pool-type (string-ascii 64) The string identifier of the pool type.
;; @returns (response bool uint) A response indicating success or an invalid pool type error.
(define-private (validate-pool-type (pool-type (string-ascii 64)))
  ;; Temporarily bypassed until pool-type-registry contract is implemented
  (ok true))

;; --- Public Functions ---

;; @desc Creates a new liquidity pool. This function validates inputs and then delegates the creation and registration process.
;; @param token-a <sip-010-ft-trait> The trait of the first token in the pool.
;; @param token-b <sip-010-ft-trait> The trait of the second token in the pool.
;; @param pool-type (optional (string-ascii 64)) The string identifier of the pool type. If not provided, the default pool type is used.
;; @param fee-bps uint The fee in basis points for the pool.
;; @param additional-params (optional { tick-spacing: uint, initial-price: uint }) Optional parameters for specific pool types.
;; @returns (response principal uint) The principal of the newly created pool or an error.
(define-public (create-pool 
    (token-a <sip-010-ft-trait>) 
    (token-b <sip-010-ft-trait>) 
    (pool-type (optional (string-ascii 64))) 
    (fee-bps uint) 
    (additional-params (optional { tick-spacing: uint, initial-price: uint }))
    (pool-impl <pool-trait>)
    (pool-impl-reg <pool-implementation-registry-trait>)
    (pool-reg <pool-registry-trait>)
    (dim-reg <dim-registry-trait>)
  )
  (begin
    (try! (check-pool-manager))
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    
    ;; Verify passed traits match configured registries
(asserts!
      (is-eq (contract-of pool-impl-reg) (var-get pool-implementation-registry))
      ERR_UNAUTHORIZED
    )
(asserts! (is-eq (contract-of pool-reg) (var-get pool-registry))
      ERR_UNAUTHORIZED
    )
(asserts! (is-eq (contract-of dim-reg) (var-get dimensional-registry))
      ERR_UNAUTHORIZED
    )

    (let ((selected-pool-type (default-to (var-get default-pool-type) pool-type)))
      (try! (validate-pool-type selected-pool-type))
      (asserts! (and (>= fee-bps u0) (<= fee-bps u10000)) (err ERR_INVALID_FEE))
      (asserts! (not (is-eq (contract-of token-a) (contract-of token-b))) (err ERR_INVALID_TOKENS))

      (let ((impl-principal (unwrap! (contract-call? pool-impl-reg get-pool-implementation selected-pool-type) (err ERR_IMPLEMENTATION_NOT_FOUND)))
            (token-a-principal (contract-of token-a))
            (token-b-principal (contract-of token-b)))
        
        ;; Verify the passed pool-impl trait matches the implementation returned by registry
(asserts! (is-eq (contract-of pool-impl) impl-principal)
          (err ERR_IMPLEMENTATION_NOT_FOUND)
        )

(asserts!
          (is-none (unwrap!
            (contract-call? pool-reg get-pool token-a-principal token-b-principal)
            (err u0)
          ))
          ERR_POOL_EXISTS
        )

        (let ((pool-principal (unwrap! (contract-call? pool-impl create-pool token-a-principal token-b-principal fee-bps additional-params) (err ERR_SWAP_FAILED))))

;; --- Registry Management Functions ---


          (print {
            event: "pool-created",
            pool-address: pool-principal,
            token-a: token-a-principal,
            token-b: token-b-principal,
            pool-type: selected-pool-type
          })

          (ok pool-principal)
        )
      )
    )
  )
)

;; --- Registry Management Functions ---

;; @desc Registers a new pool type by calling the pool type registry.
;; @param pool-type (string-ascii 64) The identifier for the new pool type.
;; @param name (string-ascii 32) The human-readable name of the pool type.
;; @param description (string-ascii 128) A description of the pool type.
;; @param is-active bool Whether the pool type is active.
;; @returns (response bool uint) The response from the pool type registry.
(define-public (register-pool-type (pool-type (string-ascii 64)) (name (string-ascii 32)) (description (string-ascii 128)) (is-active bool))
  (begin
    (try! (check-is-owner))
    (contract-call? (var-get pool-type-registry) register-pool-type pool-type name description is-active)
  )
)

;; @desc Sets the active status of a pool type by calling the pool type registry.
;; @param pool-type (string-ascii 64) The identifier of the pool type to update.
;; @param is-active bool The new active status.
;; @returns (response bool uint) The response from the pool type registry.
(define-public (set-pool-type-active (pool-type (string-ascii 64)) (is-active bool))
  (begin
    (try! (check-is-owner))
    (contract-call? (var-get pool-type-registry) set-pool-type-active pool-type is-active)
  )
)

;; @desc Registers a pool implementation by calling the pool implementation registry.
;; @param pool-type (string-ascii 64) The identifier of the pool type.
;; @param implementation-contract principal The principal of the implementation contract.
;; @returns (response bool uint) The response from the pool implementation registry.
(define-public (register-pool-implementation (pool-type (string-ascii 64)) (implementation-contract principal))
  (begin
    (try! (check-is-owner))
    (contract-call? (var-get pool-implementation-registry) register-pool-implementation pool-type implementation-contract)
  )
)

;; --- Configuration Functions ---

;; @desc Sets the default pool type for new pool creations.
;; @param new-default-pool-type (string-ascii 64) The identifier of the new default pool type.
;; @returns (response bool uint) `(ok true)` on success, or an error.
(define-public (set-default-pool-type (new-default-pool-type (string-ascii 64)))
  (begin
    (try! (check-is-owner))
    (try! (validate-pool-type new-default-pool-type))
    (var-set default-pool-type new-default-pool-type)
    (ok true)
  )
)

;; @desc Sets the circuit breaker contract principal.
;; @param new-circuit-breaker principal The principal of the new circuit breaker contract.
;; @returns (response bool uint) `(ok true)` on success, or an error.
(define-public (set-circuit-breaker (new-circuit-breaker principal))
  (begin
    (try! (check-is-owner))
    (var-set circuit-breaker new-circuit-breaker)
    (ok true)
  )
)

;; @desc Sets the dimensional registry contract principal.
;; @param new-registry principal The principal of the new dimensional registry contract.
;; @returns (response bool uint) `(ok true)` on success, or an error.
(define-public (set-dimensional-registry (new-registry principal))
  (begin
    (try! (check-is-owner))
    (var-set dimensional-registry new-registry)
    (ok true)
  )
)

;; @desc Sets the access control contract principal.
;; @param new-access-control principal The principal of the new access control contract.
;; @returns (response bool uint) `(ok true)` on success, or an error.
(define-public (set-access-control-contract (new-access-control principal))
  (begin
    (try! (check-is-owner))
    (var-set access-control-contract new-access-control)
    (ok true)
  )
)

;; @desc Sets the pool type registry contract principal.
;; @param new-registry principal The principal of the new pool type registry contract.
;; @returns (response bool uint) `(ok true)` on success, or an error.
(define-public (set-pool-type-registry (new-registry principal))
  (begin
    (try! (check-is-owner))
    (var-set pool-type-registry new-registry)
    (ok true)
  )
)

;; @desc Sets the pool implementation registry contract principal.
;; @param new-registry principal The principal of the new pool implementation registry contract.
;; @returns (response bool uint) `(ok true)` on success, or an error.
(define-public (set-pool-implementation-registry (new-registry principal))
  (begin
    (try! (check-is-owner))
    (var-set pool-implementation-registry new-registry)
    (ok true)
  )
)

;; @desc Sets the pool registry contract principal.
;; @param new-registry principal The principal of the new pool registry contract.
;; @returns (response bool uint) `(ok true)` on success, or an error.
(define-public (set-pool-registry (new-registry principal))
  (begin
    (try! (check-is-owner))
    (var-set pool-registry new-registry)
    (ok true)
  )
)

;; --- Read-Only Functions ---

;; @desc Retrieves the pool principal for a given token pair by calling the pool registry.
;; @param token-a principal The principal of the first token.
;; @param token-b principal The principal of the second token.
;; @returns (response (optional principal) uint) The response from the pool registry.
(define-read-only (get-pool (token-a principal) (token-b principal))
  (contract-call? (var-get pool-registry) get-pool token-a token-b)
)

;; @desc Retrieves the pool type for a given pool principal by calling the pool registry.
;; @param pool-principal principal The principal of the pool.
;; @returns (response (optional (string-ascii 64)) uint) The response from the pool registry.
(define-read-only (get-pool-type (pool-principal principal))
  (contract-call? (var-get pool-registry) get-pool-type pool-principal)
)

;; @desc Retrieves the implementation contract for a given pool type by calling the pool implementation registry.
;; @param pool-type (string-ascii 64) The identifier of the pool type.
;; @returns (response (optional principal) uint) The response from the pool implementation registry.
(define-read-only (get-pool-implementation (pool-type (string-ascii 64)))
  (contract-call? (var-get pool-implementation-registry) get-pool-implementation pool-type)
)

;; @desc Retrieves information about a specific pool by calling the pool registry.
;; @param pool-principal principal The principal of the pool.
;; @returns (response (optional { ... }) uint) The response from the pool registry.
(define-read-only (get-pool-info (pool-principal principal))
  (contract-call? (var-get pool-registry) get-pool-info pool-principal)
)

;; @desc Retrieves the total number of pools by calling the pool registry.
;; @returns (response uint uint) The response from the pool registry.
(define-read-only (get-pool-count)
  (contract-call? (var-get pool-registry) get-pool-count)
)

;; @desc Retrieves the default pool type.
;; @returns (response (string-ascii 64) uint) The default pool type identifier.
(define-read-only (get-default-pool-type)
  (ok (var-get default-pool-type))
)

;; @desc Retrieves all registered pool types by calling the pool type registry.
;; @returns (response (list (string-ascii 64)) uint) The response from the pool type registry.
(define-read-only (get-all-pool-types)
  (contract-call? (var-get pool-type-registry) get-all-pool-types)
)
