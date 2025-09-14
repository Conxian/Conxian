;; Conxian DEX Factory - Pool creation and registry
;; This contract is responsible for creating and registering new DEX pools.

;; --- Traits ---
(use-trait access-control-trait .access-control-trait.access-control-trait)
(use-trait pool-trait .pool-trait.pool-trait)

;; --- Constants ---
;; Error Codes
(define-constant ERR_UNAUTHORIZED (err u1003))
(define-constant ERR_POOL_EXISTS (err u2001))
(define-constant ERR_INVALID_TOKENS (err u2002))
(define-constant ERR_POOL_NOT_FOUND (err u2003))
(define-constant ERR_INVALID_FEE (err u2004))

;; Roles - These would be defined in the access-control-trait contract
(define-constant ROLE_POOL_MANAGER "pool-manager")

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var access-control-contract principal .access-control) ;; The main access control contract
(define-data-var pool-count uint u0)

;; --- Maps ---
;; Maps a pair of tokens to the principal of their pool contract.
(define-map pools { token-a: principal, token-b: principal } principal)

;; Maps a pool principal to its information.
(define-map pool-info principal { token-a: principal, token-b: principal, fee-bps: uint, created-at: uint })


;; --- Private Functions ---

(define-private (normalize-token-pair (token-a principal) (token-b principal))
  ;; Lexicographical comparison of principals to ensure consistent keying.
  (if (is-eq (principal-to-buff token-a) (principal-to-buff token-b))
    (err ERR_INVALID_TOKENS)
    (ok (if (< (principal-to-buff token-a) (principal-to-buff token-b))
      { token-a: token-a, token-b: token-b }
      { token-a: token-b, token-b: token-a }
    ))
  )
)

(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED))
)

(define-private (check-pool-manager)
  (let ((access-control (var-get access-control-contract)))
    (ok (asserts! (unwrap! (contract-call? access-control has-role ROLE_POOL_MANAGER tx-sender) (err ERR_UNAUTHORIZED)) ERR_UNAUTHORIZED))
  )
)


;; --- Public Functions ---

;; Creates a new DEX pool by publishing a new contract.
(define-public (create-pool (pool-template <pool-trait>) (token-a principal) (token-b principal) (fee-bps uint))
  (begin
    (try! (check-pool-manager))

    (let ((normalized-pair (unwrap! (normalize-token-pair token-a token-b) (err ERR_INVALID_TOKENS))))
      
      (asserts! (is-none (map-get? pools normalized-pair)) ERR_POOL_EXISTS)

      ;; Publish the new pool contract from the provided template trait
      (let ((pool-principal (contract-publish pool-template)))
        
        ;; Initialize the newly published pool
        (try! (contract-call? pool-principal initialize
          (get token-a normalized-pair)
          (get token-b normalized-pair)
          fee-bps
          tx-sender ;; set the factory as the initial owner/admin of the pool
        ))

        ;; Register the new pool
        (map-set pools normalized-pair pool-principal)
        (map-set pool-info pool-principal
          {
            token-a: (get token-a normalized-pair),
            token-b: (get token-b normalized-pair),
            fee-bps: fee-bps,
            created-at: block-height
          }
        )
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

;; Allows the contract owner to set the address of the access control contract.
(define-public (set-access-control-contract (new-access-control principal))
  (begin
    (try! (check-is-owner))
    (var-set access-control-contract new-access-control)
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
