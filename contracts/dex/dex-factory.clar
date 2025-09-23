;; Conxian DEX Factory - Pool creation and registry
;; This contract is responsible for creating and registering new DEX pools.

;; --- Traits ---
(use-trait access-control-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.access-control-trait)
(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(use-trait factory-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.factory-trait)
(use-trait circuit-breaker-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.circuit-breaker-trait)

(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.factory-trait)

;; --- Constants ---
(define-constant ACCESS_CONTROL 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.access-control)

;; --- Constants ---
;; Error Codes
(define-constant ERR_UNAUTHORIZED (err u1003))
(define-constant ERR_POOL_EXISTS (err u2001))
(define-constant ERR_INVALID_TOKENS (err u2002))
(define-constant ERR_POOL_NOT_FOUND (err u2003))
(define-constant ERR_INVALID_FEE (err u2004))
(define-constant ERR_CIRCUIT_OPEN (err u2005))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var access-control-contract principal 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.access-control) ;; The main access control contract
(define-data-var pool-count uint u0)
(define-data-var circuit-breaker (optional principal) none)

;; --- Maps ---
;; Maps a pair of tokens to the principal of their pool contract.
(define-map pools { token-a: principal, token-b: principal } principal)

;; Maps a pool principal to its information.
(define-map pool-info principal { token-a: principal, token-b: principal, fee-bps: uint, created-at: uint })

;; Stores the implementation contract for each pool type
(define-map pool-implementations uint principal)

;; Stores the type of each pool
(define-map pool-types principal uint)


;; --- Private Functions ---

(define-private (normalize-token-pair (token-a principal) (token-b principal))
  ;; Compare principals directly instead of converting to uint
  (if (is-eq token-a token-b)
    (err ERR_INVALID_TOKENS)
    (let ((token-a-str (unwrap! (as-max-len? (to-buff token-a) u20) token-a))
          (token-b-str (unwrap! (as-max-len? (to-buff token-b) u20) token-b)))
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
    (cb (contract-call? cb is-tripped))
    (ok false)
  )
)


;; --- Public Functions ---

;; Creates a new DEX pool by deploying a new contract
(define-public (create-pool (token-a principal) (token-b principal) (fee-bps uint) (pool-type uint))
  (begin
    (try! (check-circuit-breaker))
    (try! (check-pool-manager))
    (asserts! (>= fee-bps u0) (err ERR_INVALID_FEE))
    (asserts! (<= fee-bps u10000) (err ERR_INVALID_FEE)) ;; Max 100% fee
    (asserts! (is-ok (contract-call? token-a get-symbol)) (err ERR_INVALID_TOKENS))
    (asserts! (is-ok (contract-call? token-b get-symbol)) (err ERR_INVALID_TOKENS))
    (asserts! (not (is-eq token-a token-b)) (err ERR_INVALID_TOKENS))

    (let ((normalized-pair (unwrap! (normalize-token-pair token-a token-b) (err ERR_INVALID_TOKENS)))
          (pool-impl (unwrap! (map-get? pool-implementations pool-type) (err ERR_POOL_NOT_FOUND))))
      
      (asserts! (is-none (map-get? pools normalized-pair)) ERR_POOL_EXISTS)

      (let ((pool-principal (unwrap! (contract-call? pool-impl create-pool token-a token-b fee-bps) (err u9999))))
        
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
          token-b: (get token-b normalized-pair)
        })
        
        (ok pool-principal)
      )
    )
  )
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

;; Gets the pool principal for a given pair of tokens.
(define-read-only (get-pool (token-a principal) (token-b principal))
  (let ((normalized-pair (unwrap-panic (normalize-token-pair token-a token-b))))
    (map-get? pools normalized-pair)
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

;; Allows the contract owner to transfer ownership to a new principal.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (try! (check-is-owner))
    (var-set contract-owner new-owner)
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

(define-public (set-pool-type (pool principal) (pool-type uint))
    (begin
        (try! (check-is-owner))
        (asserts! (is-some (map-get? pool-info pool)) (err ERR_POOL_NOT_FOUND))
        (map-set pool-types pool pool-type)
        (ok true)
    )
)

;; --- Read-Only Functions ---

;; Gets the pool principal for a given pair of tokens.
(define-read-only (get-pool (token-a principal) (token-b principal))
  (let ((normalized-pair (unwrap-panic (normalize-token-pair token-a token-b))))
    (map-get? pools normalized-pair)
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
