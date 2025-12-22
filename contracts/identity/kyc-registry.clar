;; kyc-registry.clar
;; Central identity registry for Conxian Protocol
;; Implements the Identity, KYC & POPIA Charter
;; Does NOT store PII on-chain. Stores only tiers, flags, and status.

(define-constant ERR_UNAUTHORIZED (err u8000))
(define-constant ERR_INVALID_TIER (err u8001))
(define-constant ERR_ALREADY_REGISTERED (err u8002))

;; KYC Tiers (aligned with IDENTITY_KYC_POPIA.md)
(define-constant TIER_UNVERIFIED u0)
(define-constant TIER_BASIC u1) ;; Natural persons, basic KYC
(define-constant TIER_PROFESSIONAL u2) ;; Pro operators / Institutions, Enhanced KYC/KYB
(define-constant TIER_REGULATED u3) ;; Licensed Banks/Funds

;; Roles
(define-data-var contract-owner principal tx-sender)
(define-map attestors
  principal
  bool
)
;; Principals authorized to update KYC status

;; Identity Store
(define-map identity-status
  principal
  {
    tier: uint,
    status-flags: uint, ;; Bitmask for flags (0x1=Review, 0x2=Sanctioned, 0x4=Institutional)
    region-code: (string-ascii 3), ;; ISO 3166-1 alpha-3 (e.g. "ZAF", "USA")
    updated-at: uint,
    updated-by: principal,
  }
)

;; Badge Integration
(define-data-var badge-token principal .identity-badge)

;; --- Authorization ---

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-attestor)
  (default-to false (map-get? attestors tx-sender))
)

(define-private (is-authorized)
  (or (is-contract-owner) (is-attestor))
)

;; --- Admin Functions ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-attestor
    (attestor principal)
    (enabled bool)
  )
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (map-set attestors attestor enabled)
    (ok true)
  )
)

(define-public (set-badge-token (token principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set badge-token token)
    (ok true)
  )
)

;; --- Core Identity Functions ---

;; @desc Update or set KYC status for a subject
;; @param subject The principal being updated
;; @param tier The KYC tier (0-3)
;; @param flags Status bitmask
;; @param region Region code (e.g. "ZAF")
(define-public (set-identity-status
    (subject principal)
    (tier uint)
    (flags uint)
    (region (string-ascii 3))
  )
  (begin
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (asserts! (<= tier TIER_REGULATED) ERR_INVALID_TIER)

    (map-set identity-status subject {
      tier: tier,
      status-flags: flags,
      region-code: region,
      updated-at: block-height,
      updated-by: tx-sender,
    })

    ;; Manage Identity Badge
    (if (> tier TIER_UNVERIFIED)
      (begin
        (unwrap-panic (contract-call? .identity-badge mint subject))
        true
      )
      (begin
        (unwrap-panic (contract-call? .identity-badge burn subject))
        true
      )
    )
    (print {
      event: "identity-updated",
      subject: subject,
      tier: tier,
      flags: flags,
      region: region,
    })
    (ok true)
  )
)

;; --- Read Only Views ---

(define-read-only (get-identity-status (subject principal))
  (map-get? identity-status subject)
)

(define-read-only (get-kyc-tier (subject principal))
  (match (map-get? identity-status subject)
    data (ok (get tier data))
    (ok TIER_UNVERIFIED)
  )
)

(define-read-only (is-tier-or-higher
    (subject principal)
    (required-tier uint)
  )
  (let ((user-tier (default-to TIER_UNVERIFIED (get-kyc-tier-simple subject))))
    (>= user-tier required-tier)
  )
)

;; Internal helper for read-only checks without Result wrapper
(define-private (get-kyc-tier-simple (subject principal))
  (match (map-get? identity-status subject)
    data (some (get tier data))
    none
  )
)
