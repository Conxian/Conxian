;; SPDX-License-Identifier: TBD

;; Pool Implementation Registry
;; This contract maps pool types to their smart contract implementations.
(define-trait pool-implementation-registry-trait
  (
    ;; @desc Registers a pool implementation contract for a specific pool type.
    ;; @param pool-type (string-ascii 64) The string identifier of the pool type.
    ;; @param implementation-contract principal The principal of the implementation contract for the pool type.
    ;; @returns (response bool uint) A response indicating success or an error if the pool type is invalid or unauthorized.
    (register-pool-implementation ((string-ascii 64), principal) (response bool uint))

    ;; @desc Retrieves the implementation contract for a given pool type.
    ;; @param pool-type (string-ascii 64) The string identifier of the pool type.
    ;; @returns (response (optional principal) uint) An optional principal of the implementation contract or an error.
    (get-pool-implementation ((string-ascii 64)) (response (optional principal) uint))
  )
)

;; --- Data Storage ---

;; @desc Maps a pool type string to its implementation contract principal.
;; @param key (string-ascii 64) The pool type identifier.
;; @param value principal The principal of the implementation contract.
(define-map pool-implementations (string-ascii 64) principal)

;; --- Public Functions ---

;; @desc Registers a pool implementation contract for a specific pool type. Can only be called by the DEX factory.
;; @param pool-type (string-ascii 64) The string identifier for the pool type.
;; @param implementation-contract principal The principal of the smart contract that implements the logic for this pool type.
;; @returns (response bool uint) A response indicating `(ok true)` on success or an error if the caller is not authorized.
(define-public (register-pool-implementation (pool-type (string-ascii 64)) (implementation-contract principal))
  (begin
    (asserts! (is-eq tx-sender .dex-factory) (err u100))
    (map-set pool-implementations pool-type implementation-contract)
    (ok true)
  )
)

;; --- Read-Only Functions ---

;; @desc Retrieves the implementation contract for a given pool type.
;; @param pool-type (string-ascii 64) The string identifier of the pool type.
;; @returns (response (optional principal) uint) A response containing the optional principal of the implementation contract, or `(ok none)` if no implementation is registered for the type.
(define-read-only (get-pool-implementation (pool-type (string-ascii 64)))
  (ok (map-get? pool-implementations pool-type))
)
