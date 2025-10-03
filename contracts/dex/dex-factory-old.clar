(use-trait utils-trait .all-traits.utils-trait)
(use-trait access-control-trait .all-traits.access-control-trait)
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait factory-trait .all-traits.factory-trait)
(use-trait circuit-breaker-trait .all-traits.circuit-breaker-trait)
(use-trait pool-trait .all-traits.pool-trait)

(impl-trait .all-traits.factory-trait)

;; --- Constants ---
(define-constant ACCESS_CONTROL .access-control)

;; Pool Types
(define-constant POOL_TYPE_CONSTANT_PRODUCT "constant-product")
(define-constant POOL_TYPE_STABLE "stable")
(define-constant POOL_TYPE_WEIGHTED "weighted")
(define-constant POOL_TYPE_CONCENTRATED_LIQUIDITY "concentrated-liquidity")
(define-constant POOL_TYPE_LIQUIDITY_BOOTSTRAP "liquidity-bootstrap")

;; Default implementations
(define-constant DEFAULT_CONSTANT_PRODUCT_POOL .constant-product-pool)
(define-constant DEFAULT_CONCENTRATED_LIQUIDITY_POOL .concentrated-liquidity-pool)

;; Role constants
(define-constant ROLE_POOL_MANAGER "pool-manager")

;; Error Codes
(define-constant ERR_UNAUTHORIZED (err u1003))
(define-constant ERR_POOL_EXISTS (err u2001))
(define-constant ERR_INVALID_TOKENS (err u2002))
(define-constant ERR_POOL_NOT_FOUND (err u2003))
(define-constant ERR_INVALID_FEE (err u2004))
(define-constant ERR_CIRCUIT_OPEN (err u2005))
(define-constant ERR_INVALID_POOL_TYPE (err u2006))
(define-constant ERR_IMPLEMENTATION_NOT_FOUND (err u2007))
(define-constant ERR_POOL_DEPLOY_FAILED (err u2008))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var access-control-contract principal .access-control) ;; The main access control contract
(define-data-var pool-count uint u0)
(define-data-var circuit-breaker (optional principal) none)
(define-data-var default-pool-type (string-ascii 64) POOL_TYPE_CONSTANT_PRODUCT)

;; --- Maps ---
;; Maps a pair of tokens to the principal of their pool contract.
(define-map pools { token-a: principal, token-b: principal, pool-type: (string-ascii 64) } principal)

;; Maps a pool principal to its information.
(define-map pool-info principal { 
  token-a: principal, 
  token-b: principal, 
  fee-bps: uint, 
  pool-type: (string-ascii 64),
  created-at: uint 
})

;; Stores the implementation contract for each pool type
(define-map pool-implementations (string-ascii 64) principal)

;; Stores the type of each pool
(define-map pool-types principal (string-ascii 64))

;; Stores pool type metadata
(define-map pool-type-info (string-ascii 64) {
  name: (string-ascii 32),
  description: (string-ascii 128),
  is-active: bool
})


;; --- Private Functions ---

(define-private (normalize-token-pair (token-a principal) (token-b principal))
  ;; Compare principals directly instead of converting to uint
  (if (is-eq token-a token-b)
    (err ERR_INVALID_TOKENS)
    (let ((token-a-str (contract-call? .utils principal-to-buff token-a))
          (token-b-str (contract-call? .utils principal-to-buff token-b)))
      (if (< (buff-to-uint-be token-a-str) (buff-to-uint-be token-b-str))
        (ok { token-a: token-a, token-b: token-b })
        (ok { token-a: token-b, token-b: token-a })
      )
    )
  )
)

(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED))
)

(define-private (check-pool-manager)
  (let ((access-control (var-get access-control-contract)))
    (ok (asserts! (unwrap! (contract-call? access-control has-role tx-sender ROLE_POOL_MANAGER) (err ERR_UNAUTHORIZED)) ERR_UNAUTHORIZED))
  )
)

(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker)
    (cb (contract-call? cb is-circuit-open))
    (ok false)
  )
)

(define-private (validate-pool-type (pool-type (string-ascii 64)))
  (let ((pool-type-data (map-get? pool-type-info pool-type)))
    (asserts! (is-some pool-type-data) (err ERR_INVALID_POOL_TYPE))
    (asserts! (get is-active (unwrap-panic pool-type-data)) (err ERR_INVALID_POOL_TYPE))
    (ok true)
  )
)

(define-private (get-pool-implementation (pool-type (string-ascii 64)))
  (let ((implementation (map-get? pool-implementations pool-type)))
    (asserts! (is-some implementation) (err ERR_IMPLEMENTATION_NOT_FOUND))
    (ok (unwrap-panic implementation))
  )
)

;; --- Public Functions ---

;; Creates a new DEX pool by deploying a new contract
(define-public (create-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint) (pool-type (string-ascii 64)))
  (begin
    (try! (check-circuit-breaker))
    (try! (check-pool-manager))
    (try! (validate-pool-type pool-type))
    (asserts! (>= fee-bps u0) (err ERR_INVALID_FEE))
    (asserts! (<= fee-bps u10000) (err ERR_INVALID_FEE)) ;; Max 100% fee
    (asserts! (is-ok (contract-call? token-a get-symbol)) (err ERR_INVALID_TOKENS))
    (asserts! (is-ok (contract-call? token-b get-symbol)) (err ERR_INVALID_TOKENS))
    (asserts! (not (is-eq token-a token-b)) (err ERR_INVALID_TOKENS))

    (let ((normalized-pair (unwrap! (normalize-token-pair token-a token-b) (err ERR_INVALID_TOKENS)))
          (pool-impl (unwrap! (get-pool-implementation pool-type) (err ERR_IMPLEMENTATION_NOT_FOUND))))
      
      (asserts! (is-none (map-get? pools { 
        token-a: (get token-a normalized-pair), 
        token-b: (get token-b normalized-pair),
        pool-type: pool-type
      })) ERR_POOL_EXISTS)

      (let ((pool-principal (unwrap! (contract-call? pool-impl create-pool 
                                      (get token-a normalized-pair) 
                                      (get token-b normalized-pair) 
                                      fee-bps
                                      pool-type) 
                            (err u9999))))
        
        (map-set pools { 
          token-a: (get token-a normalized-pair), 
          token-b: (get token-b normalized-pair),
          pool-type: pool-type
        } pool-principal)
        
        (map-set pool-info pool-principal
          {
            token-a: (get token-a normalized-pair),
            token-b: (get token-b normalized-pair),
            fee-bps: fee-bps,
            pool-type: pool-type,
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

;; Creates a new DEX pool with default pool type
(define-public (create-default-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint))
  (create-pool token-a token-b fee-bps (var-get default-pool-type))
)

(define-public (set-circuit-breaker (cb principal))
    (begin
        (try! (check-is-owner))
        (var-set circuit-breaker (some cb))
        (ok true)
    )
)

;; Allows the contract owner to set the address of the access control contract.
(define-public (set-access-control-contract (new-access-control principal))
  (begin
    (try! (check-is-owner))
    (var-set access-control-contract new-access-control)
    (ok true)
  )
)

;; --- Read-Only Functions ---

;; Gets the pool principal for a given pair of tokens and pool type
(define-read-only (get-pool-by-type (token-a principal) (token-b principal) (pool-type (string-ascii 64)))
  (let ((normalized-pair (unwrap-panic (normalize-token-pair token-a token-b))))
    (map-get? pools { 
      token-a: (get token-a normalized-pair), 
      token-b: (get token-b normalized-pair),
      pool-type: pool-type
    })
  )
)

;; Gets the default pool for a given pair of tokens
(define-public (get-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (pool-type (string-ascii 64)))
  (let ((normalized-pair (unwrap-panic (normalize-token-pair token-a token-b))))
    (ok (map-get? pools { 
      token-a: (get token-a normalized-pair), 
      token-b: (get token-b normalized-pair),
      pool-type: pool-type
    }))
  )
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
(define-read-only (get-pool-type-info (pool-type (string-ascii 64)))
  (map-get? pool-type-info pool-type)
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
(define-public (register-pool-implementation (pool-type (string-ascii 64)) (implementation principal))
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
;; (function already defined above)

