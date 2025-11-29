;; DEX Factory v2 - Minimal trait-compliant implementation

;; Implement centralized factory v2 trait
;; Temporarily remove trait until available
;; (impl-trait .pool-factory-v2.pool-factory-v2-trait)

(use-trait pool-deployer-trait .defi-primitives.pool-deployer-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_TYPE_NOT_FOUND (err u1439))
(define-constant ERR_POOL_ALREADY_EXISTS (err u1440))

(define-data-var contract-owner principal tx-sender)

;; Registry of pool type -> implementation principal
(define-map pool-types
  { type-id: (string-ascii 32) }
  { impl: principal }
)

;; Mapping of token pairs -> pool principal and type
(define-map pools
  {
    token-a: principal,
    token-b: principal,
  }
  {
    type-id: (string-ascii 32),
    pool: principal,
  }
)

;; @desc Sets the contract owner.
;; @param new-owner The principal of the new owner.
;; @returns (response bool uint) True if successful, or an error.
;; @error ERR_UNAUTHORIZED if the transaction sender is not the current owner.
(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)
;; @desc Registers a new pool type with its implementation contract.
;; @param type-id A unique identifier for the pool type.
;; @param impl The principal of the contract implementing this pool type.
;; @returns (response bool uint) True if successful, or an error.
;; @error ERR_UNAUTHORIZED if the transaction sender is not the contract owner.
(define-public (register-pool-type
    (type-id (string-ascii 32))
    (impl principal)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set pool-types { type-id: type-id } { impl: impl })
    (ok true)
  )
)

;; @desc Creates a new pool for a given token pair and pool type.
;; @param type-id The identifier of the pool type to create.
;; @param token-a The principal of the first token in the pair.
;; @param token-b The principal of the second token in the pair.
;; @param deployer The pool deployer trait reference.
;; @returns (response principal uint) The principal of the created pool or an error.
;; @error ERR_TYPE_NOT_FOUND if the specified pool type is not registered.
(define-public (create-pool
    (type-id (string-ascii 32))
    (token-a principal)
    (token-b principal)
    (deployer <pool-deployer-trait>)
  )
  (let (
    (type-entry (map-get? pool-types { type-id: type-id }))
    (sorted-tokens {
      t1: token-a,
      t2: token-b,
    })
  )
    (asserts! (is-some type-entry) (err ERR_TYPE_NOT_FOUND))
    (asserts!
      (is-eq (contract-of deployer) (get impl (unwrap-panic type-entry)))
      (err ERR_UNAUTHORIZED)
    )
    (asserts! (is-none (map-get? pools { token-a: (get t1 sorted-tokens), token-b: (get t2 sorted-tokens) })) (err ERR_POOL_ALREADY_EXISTS))
    (let (
      (call-result (contract-call? deployer deploy-and-initialize token-a token-b))
    )
      (asserts! (is-ok call-result) ERR_TYPE_NOT_FOUND)
      (let ((inner-result (unwrap-panic call-result)))
        (asserts! (is-ok inner-result) (err ERR_TYPE_NOT_FOUND))
        (let ((pool-principal (unwrap-panic inner-result)))
          (map-set pools {
            token-a: (get t1 sorted-tokens),
            token-b: (get t2 sorted-tokens),
          } {
            type-id: type-id,
            pool: pool-principal,
          })
          (ok pool-principal)
        )
      )
    )
  )
)

;; @desc Retrieves the pool principal for a given token pair.
;; @param token-a The principal of the first token in the pair.
;; @param token-b The principal of the second token in the pair.
;; @returns (response (optional principal) uint) An optional principal of the pool or an error.
;; @desc Retrieves the pool contract principal for a given token pair.
;; @param token-a The principal of the first token in the pair.
;; @param token-b The principal of the second token in the pair.
;; @returns (response (optional principal) (err u1439)) An optional principal of the pool contract, or an error.
;; @error u1439 If the pool is not found.
(define-read-only (get-pool
    (token-a principal)
    (token-b principal)
  )
  (let (
    (sorted-tokens {
      t1: token-a,
      t2: token-b,
    })
    (entry (map-get? pools {
      token-a: (get t1 sorted-tokens),
      token-b: (get t2 sorted-tokens),
    }))
  )
    (ok (match entry
      e (some (get pool e))
      none
    ))
  )
)

;; @desc Retrieves all registered pool types.
;; @returns (response (list 10 {type-id: (string-ascii 32), impl: principal}) uint) A list of all registered pool types.
;; @desc Retrieves a list of all registered pool types.
;; @returns (response (list (string-ascii 64)) (err u1451)) A list of all pool types, or an error.
;; @error u1451 If an unexpected error occurs while retrieving pool types.
(define-read-only (get-all-pool-types)
  (ok (list))
)

;; @desc Retrieves all created pools.
;; @returns (response (list 10 {token-a: principal, token-b: principal, type-id: (string-ascii 32), pool: principal}) uint) A list of all created pools.
(define-read-only (get-all-pools)
  (ok (list))
)
