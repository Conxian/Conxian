;; legal-representative-registry.clar
;; Registry for Conxian Labs, Regional Wrappers, and Legal Advisors
;; Implements LEGAL_REPRESENTATIVES_AND_BOUNTIES.md

(define-constant ERR_UNAUTHORIZED (err u8100))
(define-constant ERR_INVALID_ROLE (err u8101))
(define-constant ERR_DUPLICATE_WRAPPER (err u8102))

;; Roles
(define-constant ROLE_PRIMARY_WRAPPER u1) ;; e.g. Conxian Labs (ZA)
(define-constant ROLE_LOCAL_COUNSEL u2) ;; Law firm
(define-constant ROLE_POLICY_ADVISOR u3) ;; Individual/Entity advisor

;; Status
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_PROBATION u2)
(define-constant STATUS_SUSPENDED u3)
(define-constant STATUS_RETIRED u4)

(define-data-var contract-owner principal tx-sender)

;; Registry Map
(define-map legal-representatives
  principal
  {
    region-code: (string-ascii 3), ;; e.g. "ZAF"
    role: uint,
    status: uint,
    bonded-stake: uint,
    reputation-score: uint,
    meta-hash: (buff 32), ;; IPFS hash of engagement letter / details
    updated-at: uint,
  }
)

;; Lookup by Region (to find Primary Wrapper)
(define-map primary-region-wrapper
  (string-ascii 3)
  principal
)

;; --- Authorization ---

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; --- Admin Functions ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Register or update a legal representative
;; @param rep The principal of the representative
;; @param region ISO 3166-1 alpha-3 code
;; @param role Role ID
;; @param status Status ID
;; @param meta-hash Documentation hash
(define-public (register-legal-rep
    (rep principal)
    (region (string-ascii 3))
    (role uint)
    (status uint)
    (meta-hash (buff 32))
  )
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)

    ;; If setting a primary wrapper, verify uniqueness or update index
    (if (is-eq role ROLE_PRIMARY_WRAPPER)
      (begin
        (match (map-get? primary-region-wrapper region)
          existing-rep (asserts! (is-eq existing-rep rep) ERR_DUPLICATE_WRAPPER)
          (map-set primary-region-wrapper region rep)
        )
        true
      )
      true
    )

    (map-set legal-representatives rep {
      region-code: region,
      role: role,
      status: status,
      bonded-stake: u0, ;; Bond handled by separate staking contract if needed
      reputation-score: u0,
      meta-hash: meta-hash,
      updated-at: block-height,
    })

    (print {
      event: "legal-rep-updated",
      rep: rep,
      region: region,
      role: role,
      status: status,
    })
    (ok true)
  )
)

(define-public (update-status
    (rep principal)
    (status uint)
  )
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (match (map-get? legal-representatives rep)
      data
      (begin
        (map-set legal-representatives rep
          (merge data {
            status: status,
            updated-at: block-height,
          })
        )
        (ok true)
      )
      ERR_INVALID_ROLE ;; Rep not found
    )
  )
)

;; --- Read Only ---

(define-read-only (get-legal-rep (rep principal))
  (map-get? legal-representatives rep)
)

(define-read-only (get-primary-wrapper (region (string-ascii 3)))
  (map-get? primary-region-wrapper region)
)

(define-read-only (is-active-wrapper (rep principal))
  (match (map-get? legal-representatives rep)
    data (and
      (is-eq (get role data) ROLE_PRIMARY_WRAPPER)
      (is-eq (get status data) STATUS_ACTIVE)
    )
    false
  )
)
