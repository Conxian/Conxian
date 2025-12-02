;; DEX Factory V2
;; Production-grade factory for managing multiple pool types and deployments.

(use-trait pool-deployer-trait .defi-traits.pool-deployer-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_TYPE_NOT_FOUND (err u1439))
(define-constant ERR_POOL_ALREADY_EXISTS (err u1440))
(define-constant ERR_INVALID_POOL (err u1441))

(define-data-var contract-owner principal tx-sender)
(define-data-var pool-count uint u0)

;; --- Maps ---

;; Registry of pool type -> implementation principal (deployer)
(define-map pool-types
    { type-id: (string-ascii 32) }
    { impl: principal }
)

;; Mapping of token pairs -> pool details
;; We store both (A, B) and (B, A) to avoid sorting issues in older Clarity versions
(define-map pools
    {
        token-a: principal,
        token-b: principal,
    }
    {
        type-id: (string-ascii 32),
        pool: principal,
        created-at: uint
    }
)

;; Reverse mapping: Pool Principal -> Pool Details
(define-map pool-details
    { pool: principal }
    {
        token-a: principal,
        token-b: principal,
        type-id: (string-ascii 32)
    }
)

;; --- Public Functions ---

;; @desc Sets the contract owner.
(define-public (set-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

;; @desc Registers a new pool type with its deployer contract.
(define-public (register-pool-type (type-id (string-ascii 32)) (impl principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map-set pool-types { type-id: type-id } { impl: impl })
        (ok true)
    )
)

;; @desc Creates a new pool for a given token pair and pool type.
(define-public (create-pool
    (type-id (string-ascii 32))
    (token-a principal)
    (token-b principal)
    (deployer <pool-deployer-trait>)
)
    (let (
        (type-entry (unwrap! (map-get? pool-types { type-id: type-id }) ERR_TYPE_NOT_FOUND))
    )
        ;; Verify deployer matches registered implementation
        (asserts! (is-eq (contract-of deployer) (get impl type-entry)) ERR_UNAUTHORIZED)
        
        ;; Verify pool doesn't exist (check both directions)
        (asserts! (is-none (map-get? pools { token-a: token-a, token-b: token-b })) ERR_POOL_ALREADY_EXISTS)
        (asserts! (is-none (map-get? pools { token-a: token-b, token-b: token-a })) ERR_POOL_ALREADY_EXISTS)
        
        ;; Deploy pool
        (let (
            (pool-principal (unwrap-panic (contract-call? deployer deploy-and-initialize token-a token-b)))
        )
            ;; Register pool in both directions
            (map-set pools { token-a: token-a, token-b: token-b } {
                type-id: type-id,
                pool: pool-principal,
                created-at: block-height
            })
            (map-set pools { token-a: token-b, token-b: token-a } {
                type-id: type-id,
                pool: pool-principal,
                created-at: block-height
            })
            
            (map-set pool-details { pool: pool-principal } {
                token-a: token-a,
                token-b: token-b,
                type-id: type-id
            })
            
            (var-set pool-count (+ (var-get pool-count) u1))
            (print { event: "pool-created", pool: pool-principal, type: type-id, token-a: token-a, token-b: token-b })
            (ok pool-principal)
        )
    )
)

;; --- Read-Only Functions ---

(define-read-only (get-pool (token-a principal) (token-b principal))
    (ok (map-get? pools { token-a: token-a, token-b: token-b }))
)

(define-read-only (get-pool-by-principal (pool principal))
    (ok (map-get? pool-details { pool: pool }))
)

(define-read-only (get-pool-count)
    (ok (var-get pool-count))
)
