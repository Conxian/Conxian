;; Conxian DEX Factory V2 - DIMENSIONAL INTEGRATION
;; Pool creation and registration through dimensional registry
;; All pools registered as dimensional nodes for unified routing

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait factory-trait .all-traits.factory-trait)
(use-trait access-control-trait .all-traits.access-control-trait)
(use-trait circuit-breaker-trait .all-traits.circuit-breaker-trait)
(use-trait dim-registry-trait .all-traits.dim-registry-trait)

;; --- Dimensional Integration ---
;; @desc Stores the principal of the dimensional registry contract.
(define-data-var dimensional-registry principal tx-sender) ;; Will be set to dim-registry.clar

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1003))
(define-constant ERR_POOL_EXISTS (err u2001))
(define-constant ERR_INVALID_TOKENS (err u2002))
(define-constant ERR_POOL_NOT_FOUND (err u2003))
(define-constant ERR_INVALID_FEE (err u2004))
(define-constant ERR_INVALID_POOL_TYPE (err u2005))
(define-constant ERR_IMPLEMENTATION_NOT_FOUND (err u2006))
(define-constant ERR_SWAP_FAILED (err u2007))
(define-constant ERR_CIRCUIT_OPEN (err u5000))
(use-trait rbac-trait .rbac-trait.rbac-trait)

;; --- Data Variables ---
;; @desc Stores the principal of the access control contract.
(define-data-var access-control-contract principal .access-control)
;; @desc Stores the total count of pools created by the factory.
(define-data-var pool-count uint u0)
;; @desc Stores the principal of the circuit breaker contract.
(define-data-var circuit-breaker principal .circuit-breaker)
;; @desc Stores the default pool type used for new pool creations.
(define-data-var default-pool-type (string-ascii 64) POOL_TYPE_WEIGHTED)

;; --- Maps ---
;; @desc Maps a token pair to its corresponding pool principal.
(define-map pools { token-a: principal, token-b: principal } principal)
;; @desc Stores detailed information about each pool, indexed by its principal.
(define-map pool-info principal { token-a: principal, token-b: principal, fee-bps: uint, created-at: uint })
;; @desc Maps a pool type string to its implementation contract principal.
(define-map pool-implementations (string-ascii 64) principal)
;; @desc Maps a pool principal to its associated pool type string.
(define-map pool-types principal (string-ascii 64))
;; @desc Stores a deterministic ordering index for token principals, managed by the owner.
(define-map token-order principal uint)

;; @desc Stores metadata for each registered pool type.
(define-map pool-type-info (string-ascii 64) {
  name: (string-ascii 32),
  description: (string-ascii 128),
  is-active: bool
})

;; Pool Types
(define-constant POOL_TYPE_WEIGHTED "weighted")
(define-constant POOL_TYPE_CONCENTRATED_LIQUIDITY "concentrated-liquidity")
(define-constant POOL_TYPE_LIQUIDITY_BOOTSTRAP "liquidity-bootstrap")
(define-constant POOL_TYPE_CONSTANT_PRODUCT "constant-product")
(define-constant POOL_TYPE_STABLE_SWAP "stable-swap")

;; @desc Normalizes a pair of token principals to ensure consistent ordering.
;; @param token-a The principal of the first token.
;; @param token-b The principal of the second token.
;; @returns (response { token-a: principal, token-b: principal } uint) A response containing the normalized token pair or an error if tokens are identical.
(define-private (normalize-token-pair (token-a principal) (token-b principal))
  (if (is-eq token-a token-b)
    (err ERR_INVALID_TOKENS)
    (let ((order-a (default-to u0 (map-get? token-order token-a)))
          (order-b (default-to u0 (map-get? token-order token-b))))
      (if (< order-a order-b)
        (ok { token-a: token-a, token-b: token-b })
        (ok { token-a: token-b, token-b: token-a })
      )
    )
  )
)

;; @desc Checks if the transaction sender is the contract owner.
;; @returns (response bool uint) A response indicating success or an unauthorized error.
(define-private (check-is-owner)
  (begin
    (asserts! (contract-call? .rbac-contract has-role "contract-owner") ERR_UNAUTHORIZED)
    (ok true)
  )
)

;; @desc Checks if the transaction sender has the 'POOL_MANAGER' role.
;; @returns (response bool uint) A response indicating success or an unauthorized error.
(define-private (check-pool-manager)
  (let ((has (unwrap! (contract-call? (var-get access-control-contract) has-role "POOL_MANAGER" tx-sender) ERR_UNAUTHORIZED)))
      (asserts! has ERR_UNAUTHORIZED)
      (ok true)
    ))
)

;; @desc Checks if the circuit breaker is open.
;; @returns (response bool uint) A response indicating if the circuit is open.
(define-private (check-circuit-breaker)
  (contract-call? .circuit-breaker is-circuit-open))

;; @desc Validates if a given pool type is registered and active.
;; @param pool-type The string identifier of the pool type.
;; @returns (response bool uint) A response indicating success or an invalid pool type error.
(define-private (validate-pool-type (pool-type (string-ascii 64)))
  (let ((pool-type-data (map-get? pool-type-info pool-type)))
    (asserts! (is-some pool-type-data) (err ERR_INVALID_POOL_TYPE))
    (asserts! (get is-active (unwrap-panic pool-type-data)) (err ERR_INVALID_POOL_TYPE))
    (ok true)
  )
)

;; --- Public Functions ---

;; @desc Creates a new liquidity pool of a specified type.
;; @param token-a The trait of the first token in the pool.
;; @param token-b The trait of the second token in the pool.
;; @param pool-type The string identifier of the pool type to create. If none, uses default.
;; @param fee-bps The fee in basis points for the pool.
;; @returns (response principal uint) A response containing the principal of the newly created pool or an error.
;; @events (print { event: "pool-created", pool-address: pool-principal, token-a: (get token-a normalized-pair), token-b: (get token-b normalized-pair), pool-type: pool-type })
(define-public (create-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (pool-type (optional (string-ascii 64))) (fee-bps uint))
  (begin
    (try! (check-pool-manager))
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)

    (let ((selected-pool-type (default-to (var-get default-pool-type) pool-type)))
      (try! (validate-pool-type selected-pool-type))
      (asserts! (>= fee-bps u0) (err ERR_INVALID_FEE))
      (asserts! (<= fee-bps u10000) (err ERR_INVALID_FEE)) ;; Max 100% fee
      (asserts! (is-ok (contract-call? token-a get-symbol)) (err ERR_INVALID_TOKENS))
      (asserts! (is-ok (contract-call? token-b get-symbol)) (err ERR_INVALID_TOKENS))
      (asserts! (not (is-eq (contract-of token-a) (contract-of token-b))) (err ERR_INVALID_TOKENS))

      (let ((normalized-pair (unwrap! (normalize-token-pair (contract-of token-a) (contract-of token-b)) (err ERR_INVALID_TOKENS)))
            (pool-impl (unwrap! (map-get? pool-implementations selected-pool-type) (err ERR_IMPLEMENTATION_NOT_FOUND))))
        
        (asserts! (is-none (map-get? pools normalized-pair)) ERR_POOL_EXISTS)

        (let ((pool-principal (unwrap! (contract-call? pool-impl create-pool (get token-a normalized-pair) (get token-b normalized-pair) fee-bps) (err ERR_SWAP_FAILED))))

          ;; Register pool component with dimensional registry (factory as caller)
          (let ((registry (var-get dimensional-registry)))
            (try! (as-contract (contract-call? registry register-component pool-principal u100))))

          (map-set pools normalized-pair pool-principal)
          (map-set pool-info pool-principal
            {
              token-a: (get token-a normalized-pair),
              token-b: (get token-b normalized-pair),
              fee-bps: fee-bps,
              created-at: block-height
            }
          )
          (map-set pool-types pool-principal selected-pool-type)

          (var-set pool-count (+ (var-get pool-count) u1))

          (print {
            event: "pool-created",
            pool-address: pool-principal,
            token-a: (get token-a normalized-pair),
            token-b: (get token-b normalized-pair),
            pool-type: selected-pool-type
          })

          (ok pool-principal)
        )
      )
    )
  )
)

;; @desc Sets the circuit breaker contract principal.
;; @param new-circuit-breaker The principal of the new circuit breaker contract.
;; @returns (response bool uint) A response indicating success or an unauthorized error.
(define-public (set-circuit-breaker (new-circuit-breaker principal))
  (begin
    (try! (check-is-owner))
    (var-set circuit-breaker new-circuit-breaker)
    (ok true)
  )
)

;; @desc Sets the dimensional registry contract principal.
;; @param new-registry The principal of the new dimensional registry contract.
;; @returns (response bool uint) A response indicating success or an unauthorized error.
(define-public (set-dimensional-registry (new-registry principal))
  (begin
    (try! (check-is-owner))
    (var-set dimensional-registry new-registry)
    (ok true)
  )
)

;; @desc Sets the access control contract principal.
;; @param new-access-control The principal of the new access control contract.
;; @returns (response bool uint) A response indicating success or an unauthorized error.
(define-public (set-access-control-contract (new-access-control principal))
  (begin
    (try! (check-is-owner))
    (var-set access-control-contract new-access-control)
    (ok true)
  )
)

;; @desc Sets the deterministic order index for a token principal.
;; @param token The principal of the token.
;; @param order The order index for the token.
;; @returns (response bool uint) A response indicating success or an unauthorized error.
(define-public (set-token-order (token principal) (order uint))
  (begin
    (try! (check-is-owner))
    (map-set token-order token order)
    (ok true)
  )
)

;; @desc Registers a pool implementation contract for a specific pool type.
;; @param pool-type The string identifier of the pool type.
;; @param implementation-contract The principal of the implementation contract for the pool type.
;; @returns (response bool uint) A response indicating success or an error if the pool type is invalid or unauthorized.
(define-public (register-pool-implementation (pool-type (string-ascii 64)) (implementation-contract principal))
  (begin
    (try! (check-is-owner))
    (asserts! (is-some (map-get? pool-type-info pool-type)) (err ERR_INVALID_POOL_TYPE))
    (map-set pool-implementations pool-type implementation-contract)
    (ok true)
  )
)

;; @desc Registers a new pool type with its metadata.
;; @param pool-type The string identifier of the new pool type.
;; @param name The human-readable name of the pool type.
;; @param description A description of the pool type.
;; @param is-active A boolean indicating if the pool type is active.
;; @returns (response bool uint) A response indicating success or an unauthorized error.
(define-public (register-pool-type (pool-type (string-ascii 64)) (name (string-ascii 32)) (description (string-ascii 128)) (is-active bool))
  (begin
    (try! (check-is-owner))
    (map-set pool-type-info pool-type {
      name: name,
      description: description,
      is-active: is-active
    })
    (ok true)
  )
)

;; @desc Sets the active status of a registered pool type.
;; @param pool-type The string identifier of the pool type.
;; @param is-active A boolean indicating whether the pool type should be active.
;; @returns (response bool uint) A response indicating success or an error if the pool type is invalid or unauthorized.
(define-public (set-pool-type-active (pool-type (string-ascii 64)) (is-active bool))
  (begin
    (try! (check-is-owner))
    (asserts! (is-some (map-get? pool-type-info pool-type)) (err ERR_INVALID_POOL_TYPE))
    (let ((pti (unwrap-panic (map-get? pool-type-info pool-type))))
      (map-set pool-type-info pool-type {
        name: (get name pti),
        description: (get description pti),
        is-active: is-active
      })
    )
    (ok true)
  )
)

;; @desc Sets the default pool type for new pool creations.
;; @param pool-type The string identifier of the pool type to set as default.
;; @returns (response bool uint) A response indicating success or an error if the pool type is invalid or unauthorized.
(define-public (set-default-pool-type (pool-type (string-ascii 64)))
  (begin
    (try! (check-is-owner))
    (asserts! (is-some (map-get? pool-type-info pool-type)) (err ERR_INVALID_POOL_TYPE))
    (var-set default-pool-type pool-type)
    (ok true)
  )
)

;; @desc Updates the pool type for an existing pool.
;; @param pool The principal of the pool to update.
;; @param pool-type The new string identifier for the pool type.
;; @returns (response bool uint) A response indicating success or an error if the pool is not found, pool type is invalid, or unauthorized.
(define-public (set-pool-type (pool principal) (pool-type (string-ascii 64)))
  (begin
    (try! (check-is-owner))
    (asserts! (is-some (map-get? pool-info pool)) (err ERR_POOL_NOT_FOUND))
    (asserts! (is-some (map-get? pool-type-info pool-type)) (err ERR_INVALID_POOL_TYPE))
    (map-set pool-types pool pool-type)
    (ok true)
  )
)

;; @desc Allows the contract owner to transfer ownership to a new principal.
;; @param new-owner The principal of the new contract owner.
;; @returns (response bool uint) A response indicating success or an unauthorized error.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (try! (check-is-owner))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Retrieves the pool principal for a given pair of tokens and pool type.
;; @param token-a The principal of the first token.
;; @param token-b The principal of the second token.
;; @param pool-type The string identifier of the pool type.
;; @param fee-bps The fee in basis points for the pool.
;; @returns (response (optional principal) uint) An optional principal of the pool or an error.
(define-read-only (get-pool-by-type (token-a principal) (token-b principal) (pool-type (string-ascii 64)) (fee-bps uint))
  (let ((normalized-pair (unwrap-panic (normalize-token-pair token-a token-b))))
    (map-get? pools { 
      token-a: (get token-a normalized-pair), 
      token-b: (get token-b normalized-pair)
    })
  )
)

;; @desc Retrieves the default pool for a given pair of tokens.
;; @param token-a The principal of the first token.
;; @param token-b The principal of the second token.
;; @param fee-bps The fee in basis points for the pool.
;; @returns (response (optional principal) uint) An optional principal of the default pool or an error.
(define-read-only (get-pool (token-a principal) (token-b principal) (fee-bps uint)) 
  (get-pool-by-type token-a token-b (var-get default-pool-type) fee-bps)
)

;; @desc Retrieves the information for a given pool principal.
;; @param pool The principal of the pool.
;; @returns (response (optional { token-a: principal, token-b: principal, fee-bps: uint, created-at: uint }) uint) An optional map of pool information or an error.
(define-read-only (get-pool-info (pool principal))
  (map-get? pool-info pool)
)

;; @desc Retrieves the pool type for a given pool principal.
;; @param pool The principal of the pool.
;; @returns (response (optional (string-ascii 64)) uint) An optional string identifier of the pool type or an error.
(define-read-only (get-pool-type (pool principal))
  (map-get? pool-types pool)
)

;; @desc Retrieves the pool type information.
;; @param pool-type The string identifier of the pool type.
;; @returns (response (optional { name: (string-ascii 32), description: (string-ascii 128), is-active: bool }) uint) An optional map of pool type metadata or an error.
(define-read-only (get-pool-type-info (pool-type (string-ascii 64)))
  (ok (map-get? pool-type-info pool-type))
)

;; @desc Retrieves the implementation contract for a pool type.
;; @param pool-type The string identifier of the pool type.
;; @returns (response (optional principal) uint) An optional principal of the implementation contract or an error.
(define-read-only (get-pool-implementation-contract (pool-type (string-ascii 64)))
  (map-get? pool-implementations pool-type)
)

;; @desc Retrieves the total count of pools created by the factory.
;; @returns (response uint uint) A response containing the total pool count.
(define-read-only (get-pool-count)
  (ok (var-get pool-count))
)

;; @desc Retrieves the principal of the contract owner.
;; @returns (response principal uint) A response containing the contract owner's principal.
(define-read-only (get-owner)
  (ok (contract-call? .rbac-contract has-role "contract-owner"))
)

;; @desc Retrieves the default pool type.
;; @returns (response (string-ascii 64) uint) A response containing the default pool type string.
(define-read-only (get-default-pool-type)
  (var-get default-pool-type)
)

;; @desc Initializes and registers the concentrated liquidity pool type and its implementation.
;; @param pool-contract The principal of the concentrated liquidity pool contract.
;; @returns (response bool uint) A response indicating success or an error if unauthorized.
(define-public (initialize-concentrated-liquidity-pool (pool-contract principal))
  (begin
    (try! (check-is-owner))
    (try! (register-pool-type POOL_TYPE_CONCENTRATED_LIQUIDITY "Concentrated Liquidity Pool" "Pools with concentrated liquidity for enhanced capital efficiency" true))
    (try! (register-pool-implementation POOL_TYPE_CONCENTRATED_LIQUIDITY pool-contract))
    (ok true)
  )
)

;; @desc Retrieves a list of all registered pool types.
;; @returns (response (list (string-ascii 64)) uint) A response containing a list of all registered pool type strings.
(define-read-only (get-all-pool-types)
  (ok (map-keys pool-type-info))
)

;; @desc Retrieves a list of all pools of a specific type.
;; @param pool-type The string identifier of the pool type.
;; @returns (response (list principal) uint) A response containing a list of pool principals of the specified type.
(define-read-only (get-pools-by-type (pool-type (string-ascii 64)))
  (ok (fold
        (fun (key value acc)
          (if (is-eq value pool-type)
            (unwrap-panic (as-max-len? (append acc key) u1000))
            acc
          )
        )
        (map-keys pool-types)
        (list)
      ))
)

;; @desc Retrieves the total number of pools for a given pool type.
;; @param pool-type The string identifier of the pool type.
;; @returns (response uint uint) A response containing the count of pools for the specified type.
(define-read-only (get-pool-count-by-type (pool-type (string-ascii 64)))
  (ok (len (get-pools-by-type pool-type)))
)

;; @desc Retrieves the total value locked (TVL) for a specific pool.
;; @param pool The principal of the pool.
;; @returns (response uint uint) A response containing the TVL of the pool or an error.
(define-read-only (get-pool-tvl (pool principal))
  (let ((pool-data (map-get? pool-info pool)))
    (asserts! (is-some pool-data) (err ERR_POOL_NOT_FOUND))
    ;; This is a placeholder. Actual TVL calculation would involve calling the pool contract
    ;; to get token balances and their USD values via an oracle.
    (ok u0)
  )
)

;; @desc Retrieves the total value locked (TVL) for all pools of a specific type.
;; @param pool-type The string identifier of the pool type.
;; @returns (response uint uint) A response containing the total TVL for the specified pool type or an error.
(define-read-only (get-total-tvl-by-pool-type (pool-type (string-ascii 64)))
  (let ((pools-of-type (unwrap-panic (get-pools-by-type pool-type))))
    (fold
      (fun (pool-principal acc)
        (+ acc (unwrap-panic (get-pool-tvl pool-principal)))
      )
      pools-of-type
      u0
    )
  )
)

;; @desc Retrieves the total value locked (TVL) across all pools.
;; @returns (response uint uint) A response containing the total TVL across all pools.
(define-read-only (get-total-tvl)
  (let ((all-pool-types (unwrap-panic (get-all-pool-types))))
    (fold
      (fun (pool-type acc)
        (+ acc (unwrap-panic (get-total-tvl-by-pool-type pool-type)))
      )
      all-pool-types
      u0
    )
  )
)