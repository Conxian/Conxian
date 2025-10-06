;; Conxian DEX Factory V2 - Pool creation and registry
;; This contract is responsible for creating and registering new DEX pools.

;; --- Traits ---
(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(impl-trait ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)


;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1003))
(define-constant ERR_POOL_EXISTS (err u2001))
(define-constant ERR_INVALID_TOKENS (err u2002))
(define-constant ERR_POOL_NOT_FOUND (err u2003))
(define-constant ERR_INVALID_FEE (err u2004))
(define-constant ERR_INVALID_POOL_TYPE (err u2005))
(define-constant ERR_CIRCUIT_OPEN (err u5000))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var access-control-contract principal .access-control)
(define-data-var pool-count uint u0)
(define-data-var circuit-breaker principal .circuit-breaker)

;; --- Maps ---
(define-map pools { token-a: principal, token-b: principal } principal)
(define-map pool-info principal { token-a: principal, token-b: principal, fee-bps: uint, created-at: uint })
(define-map pool-implementations uint principal)
(define-map pool-types principal uint)

;; Pool Types
(define-constant POOL_TYPE_CONSTANT_PRODUCT u1)
(define-constant POOL_TYPE_STABLE u2)
(define-constant POOL_TYPE_WEIGHTED u3)
(define-constant POOL_TYPE_CONCENTRATED_LIQUIDITY u4)
(define-constant POOL_TYPE_LIQUIDITY_BOOTSTRAP u5)


;; --- Private Functions ---

(define-private (normalize-token-pair (token-a principal) (token-b principal))
  (if (is-eq token-a token-b)
    (err ERR_INVALID_TOKENS)
    (if (< (to-uint token-a) (to-uint token-b))
      (ok { token-a: token-a, token-b: token-b })
      (ok { token-a: token-b, token-b: token-a })
    )
  )
)

(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED))
)

(define-private (check-pool-manager)
  (let ((access-control (var-get access-control-contract)))
    (ok (asserts! (unwrap! (contract-call? access-control has-role tx-sender u2) (err ERR_UNAUTHORIZED)) ERR_UNAUTHORIZED))
  )
)

(define-private (check-circuit-breaker)
  (contract-call? .circuit-breaker is-circuit-open))
)

(define-private (validate-pool-type (pool-type uint))
  (let ((pool-type-data (map-get? pool-type-info pool-type)))
    (asserts! (is-some pool-type-data) (err ERR_INVALID_POOL_TYPE))
    (asserts! (get is-active (unwrap-panic pool-type-data)) (err ERR_INVALID_POOL_TYPE))
    (ok true)
  )
)

;; --- Public Functions ---

(define-public (create-pool (token-a principal) (token-b principal) (pool-type uint) (fee-bps uint) (params (buff 256)))
  (begin
    (try! (check-pool-manager))
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (try! (validate-pool-type pool-type))
    (asserts! (>= fee-bps u0) (err ERR_INVALID_FEE))
    (asserts! (<= fee-bps u10000) (err ERR_INVALID_FEE)) ;; Max 100% fee
    (asserts! (is-ok (contract-call? token-a get-symbol)) (err ERR_INVALID_TOKENS))
    (asserts! (is-ok (contract-call? token-b get-symbol)) (err ERR_INVALID_TOKENS))
    (asserts! (not (is-eq token-a token-b)) (err ERR_INVALID_TOKENS))

    (let ((normalized-pair (unwrap! (normalize-token-pair token-a token-b) (err ERR_INVALID_TOKENS)))
          (pool-impl (unwrap! (map-get? pool-implementations pool-type) (err ERR_INVALID_POOL_TYPE))))
      
      (asserts! (is-none (map-get? pools normalized-pair)) ERR_POOL_EXISTS)

      (let ((pool-principal (unwrap! (contract-call? pool-impl create-instance (get token-a normalized-pair) (get token-b normalized-pair) fee-bps params) (err u9999))))
        
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

(define-public (register-pool-implementation (pool-type uint) (implementation principal))
  (begin
    (try! (check-is-owner))
    (map-set pool-implementations pool-type implementation)
    (ok true)
  )
)

;; Register a new pool type with metadata
(define-public (register-pool-type (pool-type uint) (name (string-ascii 32)) (description (string-ascii 128)))
  (begin
    (try! (check-is-owner))
    (map-set pool-type-info pool-type {
      name: name,
      description: description,
      is-active: true
    })
    (ok true)
  )
)

;; Set the active status of a pool type
(define-public (set-pool-type-active (pool-type uint) (is-active bool))
  (begin
    (try! (check-is-owner))
    (let ((type-info (unwrap! (map-get? pool-type-info pool-type) (err ERR_INVALID_POOL_TYPE))))
      (map-set pool-type-info pool-type (merge type-info { is-active: is-active }))
      (ok true)
    )
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (try! (check-is-owner))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; --- Read-Only Functions ---

;; Gets the pool principal for a given pair of tokens and pool type
(define-read-only (get-pool-by-type (token-a principal) (token-b principal) (pool-type uint))
  (let ((normalized-pair (unwrap-panic (normalize-token-pair token-a token-b))))
    (map-get? pools { 
      token-a: (get token-a normalized-pair), 
      token-b: (get token-b normalized-pair),
      pool-type: pool-type
    })
  )
)

;; Gets the default pool for a given pair of tokens
(define-read-only (get-pool (token-a principal) (token-b principal))
  (get-pool-by-type token-a token-b (var-get default-pool-type))
)

;; Gets all pools for a given pair of tokens
(define-read-only (get-all-pools (token-a principal) (token-b principal))
  (let ((normalized-pair (unwrap-panic (normalize-token-pair token-a token-b))))
    {
      constant-product: (map-get? pools { 
        token-a: (get token-a normalized-pair), 
        token-b: (get token-b normalized-pair),
        pool-type: POOL_TYPE_CONSTANT_PRODUCT
      }),
      stable: (map-get? pools { 
        token-a: (get token-a normalized-pair), 
        token-b: (get token-b normalized-pair),
        pool-type: POOL_TYPE_STABLE
      }),
      weighted: (map-get? pools { 
        token-a: (get token-a normalized-pair), 
        token-b: (get token-b normalized-pair),
        pool-type: POOL_TYPE_WEIGHTED
      }),
      concentrated-liquidity: (map-get? pools { 
        token-a: (get token-a normalized-pair), 
        token-b: (get token-b normalized-pair),
        pool-type: POOL_TYPE_CONCENTRATED_LIQUIDITY
      }),
      liquidity-bootstrap: (map-get? pools { 
        token-a: (get token-a normalized-pair), 
        token-b: (get token-b normalized-pair),
        pool-type: POOL_TYPE_LIQUIDITY_BOOTSTRAP
      })
    }
  )
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
(define-read-only (get-pool-type-info (pool-type uint))
  (map-get? pool-type-info pool-type)
)

;; Gets the implementation contract for a pool type
(define-read-only (get-pool-implementation-contract (pool-type uint))
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

;; --- Admin Functions ---

;; Allows the contract owner to transfer ownership to a new principal.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (try! (check-is-owner))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Register a pool implementation for a specific pool type
(define-public (register-pool-implementation (pool-type uint) (implementation principal))
  (begin
    (try! (check-is-owner))
    (map-set pool-implementations pool-type implementation)
    (ok true)
  )
)

;; Register a new pool type with metadata
(define-public (register-pool-type (pool-type uint) (name (string-ascii 32)) (description (string-ascii 128)))
  (begin
    (try! (check-is-owner))
    (map-set pool-type-info pool-type {
      name: name,
      description: description,
      is-active: true
    })
    (ok true)
  )
)

;; Set the active status of a pool type
(define-public (set-pool-type-active (pool-type uint) (is-active bool))
  (begin
    (try! (check-is-owner))
    (let ((type-info (unwrap! (map-get? pool-type-info pool-type) (err ERR_INVALID_POOL_TYPE))))
      (map-set pool-type-info pool-type (merge type-info { is-active: is-active }))
      (ok true)
    )
  )
)

;; Set the default pool type
(define-public (set-default-pool-type (pool-type uint))
  (begin
    (try! (check-is-owner))
    (try! (validate-pool-type pool-type))
    (var-set default-pool-type pool-type)
    (ok true)
  )
)

;; Update the pool type for an existing pool
(define-public (set-pool-type (pool principal) (pool-type uint))
  (begin
    (try! (check-is-owner))
    (asserts! (is-some (map-get? pool-info pool)) (err ERR_POOL_NOT_FOUND))
    (try! (validate-pool-type pool-type))
    (map-set pool-types pool pool-type)
    (ok true)
  )
)

;; Gets the information for a given pool principal.
(define-read-only (get-pool-info (pool principal))
  (map-get? pool-info pool)
)

(define-read-only (get-pool-count)
  (ok (var-get pool-count))
)

(define-read-only (get-owner)
  (ok (var-get contract-owner))
)


(define-public (create-pool (
  token-a principal)
  (token-b principal)
  (fee-bps uint)
  (pool-type uint)
)
  (let (
    (sorted-tokens (unwrap! (normalize-token-pair token-a token-b) (err ERR_INVALID_TOKENS)))
    (normalized-token-a (get token-a sorted-tokens))
    (normalized-token-b (get token-b sorted-tokens))
    (pool-key { token-a: normalized-token-a, token-b: normalized-token-b, pool-type: pool-type })
  )
    (asserts! (is-none (map-get? pools pool-key)) ERR_POOL_EXISTS)
    (asserts! (not (is-err (check-circuit-breaker))) ERR_CIRCUIT_OPEN)

    (let (
      (pool-implementation (unwrap! (map-get? pool-implementations pool-type) ERR_IMPLEMENTATION_NOT_FOUND))
      (new-pool-id (+ (var-get pool-count) u1))
      (deploy-result (as-contract (contract-call? pool-implementation deploy-pool normalized-token-a normalized-token-b fee-bps new-pool-id)))
      (new-pool-address (unwrap! deploy-result ERR_SWAP_FAILED)) ;; Assuming deploy-pool returns the new pool principal
    )
      (map-set pools pool-key new-pool-address)
      (map-set pool-info new-pool-address {
        token-a: normalized-token-a,
        token-b: normalized-token-b,
        fee-bps: fee-bps,
        pool-type: pool-type,
        created-at: block-height
      })
      (var-set pool-count new-pool-id)
      (ok new-pool-address)
    )
  )
)

(define-public (set-pool-implementation (pool-type uint) (implementation-contract principal))
  (begin
    (unwrap! (check-is-owner) (err ERR_UNAUTHORIZED))
    (map-set pool-implementations pool-type implementation-contract)
    (ok true)
  )
)

(define-public (set-pool-type-info (pool-type uint) (name (string-ascii 32)) (description (string-ascii 128)) (is-active bool))
  (begin
    (unwrap! (check-is-owner) (err ERR_UNAUTHORIZED))
    (map-set pool-type-info pool-type { name: name, description: description, is-active: is-active })
    (ok true)
  )
)

(define-read-only (get-pool-implementation (pool-type uint))
  (ok (map-get? pool-implementations pool-type))
)

(define-read-only (get-pool-type-info (pool-type uint))
  (ok (map-get? pool-type-info pool-type))
)

;; Stores pool type metadata
(define-map pool-type-info uint {
  name: (string-ascii 32),
  description: (string-ascii 128),
  is-active: bool
})
