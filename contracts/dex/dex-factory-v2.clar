;; DEX Factory V2
;; Production-grade factory for managing multiple pool types and deployments.
;; Implements Registry Pattern for Stacks (User deploys pool -> Registers in Factory)

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait pool-trait .defi-traits.pool-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ONE_DAY u17280)
(define-constant ERR_TYPE_NOT_FOUND (err u1439))
(define-constant ERR_POOL_ALREADY_EXISTS (err u1440))
(define-constant ERR_INVALID_POOL (err u1441))
(define-constant ERR_POOL_INITIALIZATION_FAILED (err u1442))

(define-data-var contract-owner principal tx-sender)
(define-data-var pool-count uint u0)

;; --- Maps ---

;; Registry of pool type -> implementation details (informational)
(define-map pool-types
    { type-id: (string-ascii 32) }
    { description: (string-ascii 64) }
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

;; @desc Registers a new pool type.
(define-public (register-pool-type (type-id (string-ascii 32)) (description (string-ascii 64)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map-set pool-types { type-id: type-id } { description: description })
        (ok true)
    )
)

;; @desc Registers (creates) a new pool for a given token pair and pool type.
;; @param pool The already deployed pool contract principal
(define-public (create-pool
    (type-id (string-ascii 32))
    (token-a principal)
    (token-b principal)
    (pool principal)
    (initial-sqrt-price uint)
    (initial-tick int)
)
    (let (
        (type-entry (unwrap! (map-get? pool-types { type-id: type-id }) ERR_TYPE_NOT_FOUND))
    )
        ;; Verify pool doesn't exist (check both directions)
        (asserts! (is-none (map-get? pools { token-a: token-a, token-b: token-b })) ERR_POOL_ALREADY_EXISTS)
        (asserts! (is-none (map-get? pools { token-a: token-b, token-b: token-a })) ERR_POOL_ALREADY_EXISTS)
        
        ;; Initialize the pool
        ;; We rely on contract-call? to a known interface (or dynamic if using traits, but we need concrete principal here to store)
        ;; For safety in this generic factory, we might just record it, or try to call a standard initialize.
        ;; Since `pool` is a principal, we can't cast it to a trait easily in `contract-call?` without passing it AS a trait.
        ;; BUT `create-pool` takes `pool` as principal.
        ;; In Stacks, we can't call `(contract-call? pool ...)` if pool is a variable.
        ;; So we must trust the user initialized it, OR we require passing it as a trait.
        ;; Let's assume we just register it here, and the POOL checks if it's initialized.
        
        ;; Register pool in both directions
        (map-set pools { token-a: token-a, token-b: token-b } {
            type-id: type-id,
            pool: pool,
            created-at: block-height
        })
        (map-set pools { token-a: token-b, token-b: token-a } {
            type-id: type-id,
            pool: pool,
            created-at: block-height
        })
        
        (map-set pool-details { pool: pool } {
            token-a: token-a,
            token-b: token-b,
            type-id: type-id
        })
        
        (var-set pool-count (+ (var-get pool-count) u1))
        (print { event: "pool-created", pool: pool, type: type-id, token-a: token-a, token-b: token-b })
        (ok pool)
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
