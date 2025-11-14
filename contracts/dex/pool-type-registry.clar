;; SPDX-License-Identifier: TBD

;; Pool Type Registry
;; This contract manages the registration and lifecycle of different pool types.
(define-trait pool-type-registry-trait
  (
    ;; @desc Registers a new pool type with its metadata.
    ;; @param pool-type (string-ascii 64) The string identifier of the new pool type.
    ;; @param name (string-ascii 32) The human-readable name of the pool type.
    ;; @param description (string-ascii 128) A description of the pool type.
    ;; @param is-active bool A boolean indicating if the pool type is active.
    ;; @returns (response bool uint) A response indicating success or an unauthorized error.
    (register-pool-type ((string-ascii 64), (string-ascii 32), (string-ascii 128), bool) (response bool uint))

    ;; @desc Sets the active status of a registered pool type.
    ;; @param pool-type (string-ascii 64) The string identifier of the pool type.
    ;; @param is-active bool A boolean indicating whether the pool type should be active.
    ;; @returns (response bool uint) A response indicating success or an error if the pool type is invalid or unauthorized.
    (set-pool-type-active ((string-ascii 64), bool) (response bool uint))

    ;; @desc Retrieves detailed information for a given pool type.
    ;; @param pool-type (string-ascii 64) The string identifier of the pool type.
    ;; @returns (response (optional { name: (string-ascii 32), description: (string-ascii 128), is-active: bool }) uint) An optional map of pool type metadata, or an error.
    (get-pool-type-info ((string-ascii 64)) (response (optional { name: (string-ascii 32), description: (string-ascii 128), is-active: bool }) uint))

    ;; @desc Retrieves a list of all registered pool types.
    ;; @returns (response (list (string-ascii 64)) uint) A response containing a list of all registered pool type strings.
    (get-all-pool-types () (response (list (string-ascii 64)) uint))
  )
)

;; --- Data Storage ---

;; @desc Stores metadata for each registered pool type.
;; @param key (string-ascii 64) The pool type identifier.
;; @param value { name: (string-ascii 32), description: (string-ascii 128), is-active: bool }
(define-map pool-type-info (string-ascii 64) {
  name: (string-ascii 32),
  description: (string-ascii 128),
  is-active: bool
})

;; --- Public Functions ---

;; @desc Registers a new pool type with its metadata. Can only be called by the DEX factory.
;; @param pool-type (string-ascii 64) The string identifier for the new pool type.
;; @param name (string-ascii 32) The human-readable name of the pool type.
;; @param description (string-ascii 128) A description of the pool type and its characteristics.
;; @param is-active bool A boolean indicating if the pool type is currently active.
;; @returns (response bool uint) A response indicating `(ok true)` on success or an error if the caller is not authorized.
(define-public (register-pool-type (pool-type (string-ascii 64)) (name (string-ascii 32)) (description (string-ascii 128)) (is-active bool))
  (begin
    (asserts! (is-eq tx-sender .dex-factory) (err u100))
    (map-set pool-type-info pool-type {
      name: name,
      description: description,
      is-active: is-active
    })
    (ok true)
  )
)

;; @desc Sets the active status of a registered pool type. Can only be called by the DEX factory.
;; @param pool-type (string-ascii 64) The string identifier of the pool type to update.
;; @param is-active bool The new active status for the pool type.
;; @returns (response bool uint) A response indicating `(ok true)` on success or an error if the caller is not authorized or the pool type does not exist.
(define-public (set-pool-type-active (pool-type (string-ascii 64)) (is-active bool))
  (begin
    (asserts! (is-eq tx-sender .dex-factory) (err u100))
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

;; --- Read-Only Functions ---

;; @desc Retrieves detailed information for a given pool type.
;; @param pool-type (string-ascii 64) The string identifier of the pool type.
;; @returns (response (optional { name: (string-ascii 32), description: (string-ascii 128), is-active: bool }) uint) A response containing an optional tuple of the pool type's metadata, or `(ok none)` if the pool type is not found.
(define-read-only (get-pool-type-info (pool-type (string-ascii 64)))
  (ok (map-get? pool-type-info pool-type))
)

;; @desc Retrieves a list of all registered pool types.
;; @returns (response (list (string-ascii 64)) uint) A response containing a list of all registered pool type identifiers.
(define-read-only (get-all-pool-types)
  (ok (map-keys pool-type-info))
)
