;; DEX Factory v2 - Minimal trait-compliant implementation

;; Implement centralized factory v2 trait
(use-trait dex-factory-v2-trait .all-traits.dex-factory-v2-trait)
;; Import SIP-010 FT trait for contract-of typing
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)

;; Declare implementation of trait
(impl-trait .all-traits.dex-factory-v2-trait)

(define-constant ERR_UNAUTHORIZED (err u2001))
(define-constant ERR_TYPE_NOT_FOUND (err u2002))

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
;; @returns (response principal uint) The principal of the created pool or an error.
;; @error ERR_TYPE_NOT_FOUND if the specified pool type is not registered.
(define-public (create-pool
    (type-id (string-ascii 32))
    (token-a principal)
    (token-b principal)
  )
  (let ((type-entry (map-get? pool-types { type-id: type-id })))
    (asserts! (is-some type-entry) ERR_TYPE_NOT_FOUND)
    (let ((impl (get impl (unwrap-panic type-entry))))
      ;; For minimal implementation, we simply record the mapping and return impl
      (map-set pools {
        token-a: token-a,
        token-b: token-b,
      } {
        type-id: type-id,
        pool: impl,
      })
      (ok impl)
    )
  )
)

;; @desc Retrieves the pool principal for a given token pair.
;; @param token-a The principal of the first token in the pair.
;; @param token-b The principal of the second token in the pair.
;; @returns (response (optional principal) uint) An optional principal of the pool or an error.
(define-read-only (get-pool
    (token-a principal)
    (token-b principal)
  )
  (let ((entry (map-get? pools {
      token-a: token-a,
      token-b: token-b,
    })))
    (ok (match entry
      e (some (get pool e))
      none
    ))
  )
)
