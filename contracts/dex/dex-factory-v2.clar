;; DEX Factory v2 - Minimal trait-compliant implementation

;; Implement centralized factory v2 trait
(use-trait factory-trait .factory-trait.factory-trait)

;; Import SIP-010 FT trait for contract-of typing
(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)
(use-trait err-trait .error-codes-trait.error-codes-trait)

;; Declare implementation of trait
(impl-trait .factory-trait.factory-trait)

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
    (asserts! (contract-call? .access-control-contract has-role "contract-owner" tx-sender) ERR_UNAUTHORIZED)
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
    (asserts! (contract-call? .access-control-contract has-role "contract-owner" tx-sender) (err ERR_UNAUTHORIZED))
    (map-set pool-types { type-id: type-id } { impl: impl })
    (ok true)
  )
)

;; @desc Creates a new pool for a given token pair and pool type.
;; @param type-id The identifier of the pool type to create.
;; @param token-a The principal of the first token in the pair.
;; @param token-b The principal of the second token in the pair.
;; @returns (response principal uint) The principal of the created pool or an error.
;; @error ERR_TYPE_NOT_FOUND if the specified pool type is not registered.
(define-public (create-pool
    (type-id (string-ascii 32))
    (token-a principal)
    (token-b principal)
  )
  (let (
    (type-entry (map-get? pool-types { type-id: type-id }))
    (sorted-tokens (if (> token-a token-b) { t1: token-b, t2: token-a } { t1: token-a, t2: token-b }))
  )
    (asserts! (is-some type-entry) (err ERR_TYPE_NOT_FOUND))
    (asserts! (is-none (map-get? pools { token-a: (get t1 sorted-tokens), token-b: (get t2 sorted-tokens) })) (err ERR_POOL_ALREADY_EXISTS))
    (let (
      (impl (get impl (unwrap-panic type-entry)))
      (new-pool-principal (contract-call? impl deploy-and-initialize token-a token-b))
    )
      (asserts! (is-ok new-pool-principal) (err (unwrap-err new-pool-principal)))
      (map-set pools {
        token-a: (get t1 sorted-tokens),
        token-b: (get t2 sorted-tokens),
      } {
        type-id: type-id,
        pool: (unwrap-panic new-pool-principal),
      })
      (ok (unwrap-panic new-pool-principal))
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
    (sorted-tokens (if (> token-a token-b) { t1: token-b, t2: token-a } { t1: token-a, t2: token-b }))
    (entry (map-get? pools {
      token-a: (get t1 sorted-tokens),
      token-b: (get t2 sorted-tokens),
    }))
  )
  (ok (get pool entry))
))
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
  (ok (map-to-list pool-types))
)

;; @desc Retrieves all created pools.
;; @returns (response (list 10 {token-a: principal, token-b: principal, type-id: (string-ascii 32), pool: principal}) uint) A list of all created pools.
(define-read-only (get-all-pools)
  (ok (map-to-list pools))
)