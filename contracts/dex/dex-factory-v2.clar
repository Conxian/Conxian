;; DEX Factory v2 - Minimal trait-compliant implementation

;; TODO: dex-factory-v2-trait not defined in all-traits.clar
;; (use-trait dex-factory-v2-trait .all-traits.dex-factory-v2-trait)
;; Import SIP-010 FT trait for contract-of typing
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u2001))
(define-constant ERR_TYPE_NOT_FOUND (err u2002))

(define-data-var contract-owner principal tx-sender)

;; Registry of pool type -> implementation principal
(define-map pool-types
  { type-id: (string-ascii 32) }
  { impl: principal }
)

;; Mapping of token pairs -> pool principal and type
(define-map pools
  {
    token-a: principal,
    token-b: principal,
  }
  {
    type-id: (string-ascii 32),
    pool: principal,
  }
)

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (register-pool-type
    (type-id (string-ascii 32))
    (impl principal)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set pool-types { type-id: type-id } { impl: impl })
    (ok true)
  )
)

(define-public (create-pool
    (type-id (string-ascii 32))
    (token-a principal)
    (token-b principal)
  )
  (let ((type-entry (map-get? pool-types { type-id: type-id })))
    (asserts! (is-some type-entry) ERR_TYPE_NOT_FOUND)
    (let ((impl (get impl (unwrap-panic type-entry))))
      ;; For minimal implementation, we simply record the mapping and return impl
      (map-set pools {
        token-a: token-a,
        token-b: token-b,
      } {
        type-id: type-id,
        pool: impl,
      })
      (ok impl)
    )
  )
)

(define-read-only (get-pool
    (token-a principal)
    (token-b principal)
  )
  (let ((entry (map-get? pools {
      token-a: token-a,
      token-b: token-b,
    })))
    (ok (match entry
      e (some (get pool e))
      none
    ))
  )
)
