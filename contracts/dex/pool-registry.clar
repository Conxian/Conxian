;; SPDX-License-Identifier: TBD

;; Pool Registry
;; This contract stores and manages information about all created liquidity pools.
(define-trait pool-registry-trait
  (
    ;; @desc Adds a new pool to the registry.
    ;; @param pool-principal principal The principal of the new pool.
    ;; @param token-a principal The principal of the first token in the pool.
    ;; @param token-b principal The principal of the second token in the pool.
    ;; @param pool-type (string-ascii 64) The string identifier of the pool type.
    ;; @param fee-bps uint The fee in basis points for the pool.
    ;; @param additional-params (optional { tick-spacing: uint, initial-price: uint }) An optional tuple containing additional parameters specific to the pool type.
    ;; @returns (response bool uint) A response indicating success.
    (add-pool (principal, principal, principal, (string-ascii 64), uint, (optional { tick-spacing: uint, initial-price: uint })) (response bool uint))

    ;; @desc Retrieves the pool principal for a given token pair.
    ;; @param token-a principal The principal of the first token in the pair.
    ;; @param token-b principal The principal of the second token in the pair.
    ;; @returns (response (optional principal) uint) An optional principal of the pool or an error.
    (get-pool (principal, principal) (response (optional principal) uint))

    ;; @desc Retrieves the pool type for a given pool principal.
    ;; @param pool-principal principal The principal of the pool.
    ;; @returns (response (optional (string-ascii 64)) uint) An optional string identifier of the pool type or an error.
    (get-pool-type (principal) (response (optional (string-ascii 64)) uint))

    ;; @desc Retrieves information about a specific pool.
    ;; @param pool-principal principal The principal of the pool.
    ;; @returns (response (optional { token-a: principal, token-b: principal, fee-bps: uint, created-at: uint, additional-params: (optional { tick-spacing: uint, initial-price: uint }) }) uint) An optional tuple of pool information or an error.
    (get-pool-info (principal) (response (optional { token-a: principal, token-b: principal, fee-bps: uint, created-at: uint, additional-params: (optional { tick-spacing: uint, initial-price: uint }) }) uint))

    ;; @desc Retrieves the total number of pools created.
    ;; @returns (response uint uint) The total number of pools or an error.
    (get-pool-count () (response uint uint))
  )
)

;; --- Data Storage ---

;; @desc Maps a normalized token pair to its corresponding pool principal.
;; @param key { token-a: principal, token-b: principal } The normalized token pair.
;; @param value principal The principal of the pool contract.
(define-map pools { token-a: principal, token-b: principal } principal)

;; @desc Stores detailed information about each pool, indexed by its principal.
;; @param key principal The principal of the pool contract.
;; @param value { token-a: principal, token-b: principal, fee-bps: uint, created-at: uint, additional-params: (optional { tick-spacing: uint, initial-price: uint }) }
(define-map pool-info principal { token-a: principal, token-b: principal, fee-bps: uint, created-at: uint, additional-params: (optional { tick-spacing: uint, initial-price: uint }) })

;; @desc Maps a pool principal to its associated pool type string.
;; @param key principal The principal of the pool contract.
;; @param value (string-ascii 64) The pool type identifier.
(define-map pool-types principal (string-ascii 64))

;; @desc Stores the total count of pools created.
(define-data-var pool-count uint u0)

;; --- Private Functions ---

;; @desc Normalizes a pair of token principals to ensure consistent ordering.
;; @param token-a principal The principal of the first token.
;; @param token-b principal The principal of the second token.
;; @returns (response { token-a: principal, token-b: principal } uint) A response containing the normalized token pair or an error if tokens are identical.
(define-private (normalize-token-pair (token-a principal) (token-b principal))
  (if (is-eq token-a token-b)
      (err u2002)
      (if (is-standard token-a token-b)
          (ok { token-a: token-a, token-b: token-b })
          (ok { token-a: token-b, token-b: token-a })
      )
  )
)

;; --- Public Functions ---

;; @desc Adds a new pool to the registry. Can only be called by the DEX factory.
;; @param pool-principal principal The principal of the new pool contract.
;; @param token-a principal The principal of the first token in the pool.
;; @param token-b principal The principal of the second token in the pool.
;; @param pool-type (string-ascii 64) The string identifier of the pool type.
;; @param fee-bps uint The fee for the pool, expressed in basis points.
;; @param additional-params (optional { tick-spacing: uint, initial-price: uint }) An optional tuple containing additional parameters for the pool.
;; @returns (response bool uint) A response indicating `(ok true)` on success or an error if the caller is not authorized or the tokens are invalid.
(define-public (add-pool (pool-principal principal) (token-a principal) (token-b principal) (pool-type (string-ascii 64)) (fee-bps uint) (additional-params (optional { tick-spacing: uint, initial-price: uint })))
  (begin
    (asserts! (is-eq tx-sender .dex-factory) (err u100))
    (let ((normalized-pair (unwrap! (normalize-token-pair token-a token-b) (err u2002))))
      (map-set pools normalized-pair pool-principal)
      (map-set pool-info pool-principal
        {
          token-a: (get token-a normalized-pair),
          token-b: (get token-b normalized-pair),
          fee-bps: fee-bps,
          created-at: block-height,
          additional-params: additional-params
        }
      )
      (map-set pool-types pool-principal pool-type)
      (var-set pool-count (+ (var-get pool-count) u1))
      (ok true)
    )
  )
)

;; --- Read-Only Functions ---

;; @desc Retrieves the principal of the pool for a given pair of tokens.
;; @param token-a principal The principal of the first token in the pair.
;; @param token-b principal The principal of the second token in the pair.
;; @returns (response (optional principal) uint) A response containing the optional principal of the pool contract, or `(ok none)` if no pool is found.
(define-read-only (get-pool (token-a principal) (token-b principal))
  (let ((normalized-pair (unwrap! (normalize-token-pair token-a token-b) (err u0))))
    (ok (map-get? pools normalized-pair))
  )
)

;; @desc Retrieves the pool type for a given pool principal.
;; @param pool-principal principal The principal of the pool contract.
;; @returns (response (optional (string-ascii 64)) uint) A response containing the optional string identifier of the pool type, or `(ok none)` if the pool is not found.
(define-read-only (get-pool-type (pool-principal principal))
  (ok (map-get? pool-types pool-principal))
)

;; @desc Retrieves detailed information about a specific pool.
;; @param pool-principal principal The principal of the pool contract.
;; @returns (response (optional { token-a: principal, token-b: principal, fee-bps: uint, created-at: uint, additional-params: (optional { tick-spacing: uint, initial-price: uint }) }) uint) A response containing an optional tuple of the pool's information, or `(ok none)` if the pool is not found.
(define-read-only (get-pool-info (pool-principal principal))
  (ok (map-get? pool-info pool-principal))
)

;; @desc Retrieves the total number of liquidity pools in the registry.
;; @returns (response uint uint) A response containing the total count of pools.
(define-read-only (get-pool-count)
  (ok (var-get pool-count))
)
