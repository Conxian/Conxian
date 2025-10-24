;; Conxian DEX Factory V2 - DIMENSIONAL INTEGRATION
;; Pool creation and registration through dimensional registry
;; All pools registered as dimensional nodes for unified routing

(use-trait factory-trait .all-traits.factory-trait)
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait access-control-trait .all-traits.access-control-trait)
(use-trait circuit-breaker-trait .all-traits.circuit-breaker-trait)
(use-trait dim-registry-trait .all-traits.dim-registry-trait)

;; --- Dimensional Integration ---
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
;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var access-control-contract principal .access-control)
(define-data-var pool-count uint u0)
(define-data-var circuit-breaker principal .circuit-breaker)
(define-data-var default-pool-type (string-ascii 64) POOL_TYPE_WEIGHTED)

;; --- Maps ---
(define-map pools { token-a: principal, token-b: principal } principal)
(define-map pool-info principal { token-a: principal, token-b: principal, fee-bps: uint, created-at: uint })
(define-map pool-implementations (string-ascii 64) principal)
(define-map pool-types principal (string-ascii 64))
;; Deterministic ordering registry for principals (owner-managed)
(define-map token-order principal uint)

;; Stores pool type metadata
(define-map pool-type-info (string-ascii 64) {
  name: (string-ascii 32),
  description: (string-ascii 128),
  is-active: bool
})

;; Pool Types
(define-constant POOL_TYPE_WEIGHTED "weighted")
(define-constant POOL_TYPE_CONCENTRATED_LIQUIDITY "concentrated-liquidity")
(define-constant POOL_TYPE_LIQUIDITY_BOOTSTRAP "liquidity-bootstrap")

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


(define-private (check-is-owner)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok true)
  )
)

(define-private (check-pool-manager)
  (let ((access-control (var-get access-control-contract)))
    (ok (asserts! (unwrap! (contract-call? access-control has-role tx-sender u2) (err ERR_UNAUTHORIZED)) ERR_UNAUTHORIZED))
  )
)

(define-private (check-circuit-breaker)
  (contract-call? .circuit-breaker is-circuit-open))

(define-private (validate-pool-type (pool-type (string-ascii 64)))
  (let ((pool-type-data (map-get? pool-type-info pool-type)))
    (asserts! (is-some pool-type-data) (err ERR_INVALID_POOL_TYPE))
    (asserts! (get is-active (unwrap-panic pool-type-data)) (err ERR_INVALID_POOL_TYPE))
    (ok true)
  )
)

;; --- Public Functions ---

(define-public (create-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (pool-type (string-ascii 64)) (fee-bps uint))
  (begin
    (try! (check-pool-manager))
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (try! (validate-pool-type pool-type))
    (asserts! (>= fee-bps u0) (err ERR_INVALID_FEE))
    (asserts! (<= fee-bps u10000) (err ERR_INVALID_FEE)) ;; Max 100% fee
    (asserts! (is-ok (contract-call? token-a get-symbol)) (err ERR_INVALID_TOKENS))
    (asserts! (is-ok (contract-call? token-b get-symbol)) (err ERR_INVALID_TOKENS))
    (asserts! (not (is-eq (contract-of token-a) (contract-of token-b))) (err ERR_INVALID_TOKENS))

    (let ((normalized-pair (unwrap! (normalize-token-pair (contract-of token-a) (contract-of token-b)) (err ERR_INVALID_TOKENS)))
          (pool-impl (unwrap! (map-get? pool-implementations pool-type) (err ERR_IMPLEMENTATION_NOT_FOUND))))
      
      (asserts! (is-none (map-get? pools normalized-pair)) ERR_POOL_EXISTS)

      (let ((pool-principal (unwrap! (contract-call? pool-impl create-pool (get token-a normalized-pair) (get token-b normalized-pair) fee-bps) (err ERR_SWAP_FAILED))))

        ;; Register pool with dimensional registry
        (try! (contract-call? .dim-registry register-dimension pool-principal u100))  ;; Register pool as dimension with weight 100

        (map-set pools normalized-pair pool-principal)
        (map-set pool-info pool-principal
          {
            token-a: (get token-a normalized-pair),
            token-b: (get token-b normalized-pair),
            fee-bps: fee-bps,
            created-at: block-height
          }
        )
        (map-set pool-types pool-principal pool-type)

        (var-set pool-count (+ (var-get pool-count) u1))

        (print {
          event: "pool-created",
          pool-address: pool-principal,
          token-a: (get token-a normalized-pair),
          token-b: (get token-b normalized-pair),
          pool-type: pool-type
        })

        (ok pool-principal)
      )
    )
  )
)

(define-public (set-circuit-breaker (new-circuit-breaker principal))
  (begin
    (try! (check-is-owner))
    (var-set circuit-breaker new-circuit-breaker)
    (ok true)
  )
)

(define-public (set-access-control-contract (new-access-control principal))
  (begin
    (try! (check-is-owner))
    (var-set access-control-contract new-access-control)
    (ok true)
  )
)

;; Owner-only: set deterministic order index for a token principal
(define-public (set-token-order (token principal) (order uint))
  (begin
    (try! (check-is-owner))
    (map-set token-order token order)
    (ok true)
  )
)

;; Register a pool implementation for a specific pool type
(define-public (register-pool-implementation (pool-type (string-ascii 64)) (implementation-contract principal))
  (begin
    (try! (check-is-owner))
    (asserts! (is-some (map-get? pool-type-info pool-type)) (err ERR_INVALID_POOL_TYPE))
    (map-set pool-implementations pool-type implementation-contract)
    (ok true)
  )
)

;; Register a new pool type
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

;; Set a pool type as active or inactive
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

;; Set the default pool type for new pool creations
(define-public (set-default-pool-type (pool-type (string-ascii 64)))
  (begin
    (try! (check-is-owner))
    (asserts! (is-some (map-get? pool-type-info pool-type)) (err ERR_INVALID_POOL_TYPE))
    (var-set default-pool-type pool-type)
    (ok true)
  )
)

;; Update the pool type for an existing pool
(define-public (set-pool-type (pool principal) (pool-type (string-ascii 64)))
  (begin
    (try! (check-is-owner))
    (asserts! (is-some (map-get? pool-info pool)) (err ERR_POOL_NOT_FOUND))
    (asserts! (is-some (map-get? pool-type-info pool-type)) (err ERR_INVALID_POOL_TYPE))
    (map-set pool-types pool pool-type)
    (ok true)
  )
)

;; Allows the contract owner to transfer ownership to a new principal.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (try! (check-is-owner))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Gets the pool principal for a given pair of tokens and pool type
(define-read-only (get-pool-by-type (token-a principal) (token-b principal) (pool-type (string-ascii 64)) (fee-bps uint))
  (let ((normalized-pair (unwrap-panic (normalize-token-pair token-a token-b))))
    (map-get? pools { 
      token-a: (get token-a normalized-pair), 
      token-b: (get token-b normalized-pair)
    })
  )
)

;; Gets the default pool for a given pair of tokens
(define-read-only (get-pool (token-a principal) (token-b principal) (fee-bps uint)) 
  (get-pool-by-type token-a token-b (var-get default-pool-type) fee-bps)
)

;; Gets the information for a given pool principal.
(define-read-only (get-pool-info (pool principal))
  (map-get? pool-info pool)
)

;; Gets the pool type for a given pool principal
(define-read-only (get-pool-type (pool principal))
  (map-get? pool-types pool)
)

;; Gets the pool type information
(define-read-only (get-pool-type-info (pool-type (string-ascii 64)))
  (ok (map-get? pool-type-info pool-type))
)

;; Gets the implementation contract for a pool type
(define-read-only (get-pool-implementation-contract (pool-type (string-ascii 64)))
  (map-get? pool-implementations pool-type)
)

(define-read-only (get-pool-count)
  (ok (var-get pool-count))
)

(define-read-only (get-owner)
  (ok (var-get contract-owner))
)

(define-read-only (get-default-pool-type)
  (var-get default-pool-type)
)

(define-public (initialize-concentrated-liquidity-pool (pool-contract principal))
  (begin
    (try! (check-is-owner))
    (try! (register-pool-type POOL_TYPE_CONCENTRATED_LIQUIDITY "Concentrated Liquidity Pool" "Pools with concentrated liquidity for enhanced capital efficiency" true))
    (try! (register-pool-implementation POOL_TYPE_CONCENTRATED_LIQUIDITY pool-contract))
    (ok true)
  )
)