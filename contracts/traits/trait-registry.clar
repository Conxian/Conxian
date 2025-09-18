;; trait-registry.clar
;; Central registry for managing trait implementations in the Conxian protocol

(define-constant contract-owner 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_TRAIT_EXISTS (err u101))
(define-constant ERR_TRAIT_NOT_FOUND (err u404))

;; Main registry mapping trait names to their implementations
(define-map trait-registry {name: (string-ascii 32)} {contract: principal})

;; Extended metadata for each trait
(define-map trait-metadata 
  {name: (string-ascii 32)} 
  {
    version: uint, 
    description: (string-utf8 256),
    deprecated: bool,
    replaced-by: (optional (string-ascii 32))
  }
)

;; Register a new trait implementation or update an existing one
(define-public (register-trait 
    (name (string-ascii 32)) 
    (version uint) 
    (description (string-utf8 256)) 
    (contract principal)
    (deprecated bool)
    (replaced-by (optional (string-ascii 32)))
)
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (map-set trait-registry {name: name} {contract: contract})
    (map-set trait-metadata {name: name} {
      version: version, 
      description: description,
      deprecated: deprecated,
      replaced-by: replaced-by
    })
    (ok true)
  )
)

;; Get the contract implementing a specific trait
(define-read-only (get-trait-contract (name (string-ascii 32)))
  (match (map-get? trait-registry {name: name})
    entry (ok (get contract entry))
    (err ERR_TRAIT_NOT_FOUND)
  )
)

;; Get metadata for a specific trait
(define-read-only (get-trait-metadata (name (string-ascii 32)))
  (match (map-get? trait-metadata {name: name})
    metadata (ok metadata)
    (err ERR_TRAIT_NOT_FOUND)
  )
)

;; List all registered traits with their implementations
(define-read-only (list-traits)
  (let ((traits (list)))
    (map-get-keys trait-registry (element (name) 
      (set! traits (append traits (list name)))))
    (ok traits)
  )
)

;; Deprecate a trait
(define-public (deprecate-trait (name (string-ascii 32)) (replacement (optional (string-ascii 32))))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (match (map-get? trait-metadata {name: name})
      metadata (let ((current (unwrap-panic metadata)))
        (map-set trait-metadata {name: name} {
          version: (get version current),
          description: (get description current),
          deprecated: true,
          replaced-by: replacement
        })
        (ok true)
      )
      (err ERR_TRAIT_NOT_FOUND)
    )
  )
)

;; Check if a trait is deprecated
(define-read-only (is-trait-deprecated (name (string-ascii 32)))
  (match (map-get? trait-metadata {name: name})
    metadata (ok (get deprecated (unwrap-panic metadata)))
    (err ERR_TRAIT_NOT_FOUND)
  )
)

;; Get the recommended replacement for a deprecated trait
(define-read-only (get-trait-replacement (name (string-ascii 32)))
  (match (map-get? trait-metadata {name: name})
    metadata (ok (get replaced-by (unwrap-panic metadata)))
    (err ERR_TRAIT_NOT_FOUND)
  )
)

;; Helper function to use in other contracts
(define-read-only (use-trait (trait-name (string-ascii 32)))
  (match (get-trait-contract trait-name)
    (ok contract) (ok contract)
    error error
  )
)

(define-read-only (get-trait-metadata (name (string-ascii 32)))
  (match (map-get? trait-metadata {name: name})
    entry (ok entry)
    (err u404)))
