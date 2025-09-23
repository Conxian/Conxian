;; Conxian DEX Factory V2 - Pool creation and registry
;; This contract is responsible for creating and registering new DEX pools.

;; --- Traits ---
(use-trait access-control-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.access-control-trait)
(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(use-trait factory-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.factory-trait)
(use-trait pool-creation-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.pool-creation-trait)
(use-trait circuit-breaker-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.circuit-breaker-trait)

(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.factory-trait)

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
(define-data-var access-control-contract principal 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.access-control)
(define-data-var pool-count uint u0)
(define-data-var circuit-breaker principal .circuit-breaker)

;; --- Maps ---
(define-map pools { token-a: principal, token-b: principal } principal)
(define-map pool-info principal { token-a: principal, token-b: principal, fee-bps: uint, created-at: uint })
(define-map pool-implementations uint principal)
(define-map pool-types principal uint)


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
  (contract-call? (var-get circuit-breaker) is-circuit-open)
)

;; --- Public Functions ---

(define-public (create-pool (token-a principal) (token-b principal) (pool-type uint) (params (buff 256)))
  (begin
    (try! (check-pool-manager))
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (is-ok (contract-call? token-a get-symbol)) (err ERR_INVALID_TOKENS))
    (asserts! (is-ok (contract-call? token-b get-symbol)) (err ERR_INVALID_TOKENS))
    (asserts! (not (is-eq token-a token-b)) (err ERR_INVALID_TOKENS))

    (let ((normalized-pair (unwrap! (normalize-token-pair token-a token-b) (err ERR_INVALID_TOKENS)))
          (pool-impl (unwrap! (map-get? pool-implementations pool-type) (err ERR_INVALID_POOL_TYPE))))
      
      (asserts! (is-none (map-get? pools normalized-pair)) ERR_POOL_EXISTS)

      (let ((pool-principal (unwrap! (contract-call? pool-impl create-instance (get token-a normalized-pair) (get token-b normalized-pair) params) (err u9999))))
        
        (map-set pools normalized-pair pool-principal)
        (map-set pool-info pool-principal
          {
            token-a: (get token-a normalized-pair),
            token-b: (get token-b normalized-pair),
            fee-bps: u0, ;; Fee is managed by the pool
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

(define-public (transfer-ownership (new-owner principal))
  (begin
    (try! (check-is-owner))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; --- Read-Only Functions ---

(define-read-only (get-pool (token-a principal) (token-b principal))
  (let ((normalized-pair (unwrap-panic (normalize-token-pair token-a token-b))))
    (map-get? pools normalized-pair)
  )
)

(define-read-only (get-pool-info (pool principal))
  (map-get? pool-info pool)
)

(define-read-only (get-pool-count)
  (ok (var-get pool-count))
)

(define-read-only (get-owner)
  (ok (var-get contract-owner))
)

(define-read-only (get-pool-implementation (pool-type uint))
    (map-get? pool-implementations pool-type)
)