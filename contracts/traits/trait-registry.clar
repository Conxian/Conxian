;; trait-registry.clar
;; Central registry for managing trait implementations in the Conxian protocol

(define-constant contract-owner tx-sender)
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
    ERR_TRAIT_NOT_FOUND
  )
)

;; Deprecate a trait
(define-public (deprecate-trait (name (string-ascii 32)) (replacement (optional (string-ascii 32))))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR_UNAUTHORIZED)
    (match (map-get? trait-metadata {name: name})
      current (begin
        (map-set trait-metadata {name: name} {
          version: (get version current),
          description: (get description current),
          deprecated: true,
          replaced-by: replacement
        })
        (ok true)
      )
      ERR_TRAIT_NOT_FOUND
    )
  )
)

;; Check if a trait is deprecated
(define-read-only (is-trait-deprecated (name (string-ascii 32)))
  (match (map-get? trait-metadata {name: name})
    metadata (ok (get deprecated metadata))
    ERR_TRAIT_NOT_FOUND
  )
)

;; Get the recommended replacement for a deprecated trait
(define-read-only (get-trait-replacement (name (string-ascii 32)))
  (match (map-get? trait-metadata {name: name})
    metadata (ok (get replaced-by metadata))
    ERR_TRAIT_NOT_FOUND
  )
)

;; Helper function to use in other contracts
(define-read-only (use-trait (trait-name (string-ascii 32)))
  (match (get-trait-contract trait-name)
    (ok contract) (ok contract)
    error error
  )
)
