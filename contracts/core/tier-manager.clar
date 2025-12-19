;; tier-manager.clar
;; Dynamic Tier Management System for Enterprise Clients
;; Manages access levels, discounts, and subscription status

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_TIER (err u1001))
(define-constant ERR_SUBSCRIPTION_EXPIRED (err u1002))

;; Tier IDs
(define-constant TIER_FREE u0)
(define-constant TIER_BASIC u1)
(define-constant TIER_PRO u2)
(define-constant TIER_ENTERPRISE u3)

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var economic-policy-engine principal tx-sender)

;; --- Data Maps ---

;; User Subscription Status
(define-map user-tiers
  principal
  {
    tier: uint,
    expiry: uint,
    discount-bps: uint,
    api-credits: uint,
  }
)

;; Tier Configurations (Dynamic)
(define-map tier-config
  uint ;; Tier ID
  {
    price-usd: uint, ;; In cents
    discount-bps: uint,
    api-limit: uint,
  }
)

;; --- Authorization ---
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-policy-engine)
  (is-eq tx-sender (var-get economic-policy-engine))
)

;; --- Admin ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-policy-engine (engine principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set economic-policy-engine engine)
    (ok true)
  )
)

;; @desc Configure a tier's pricing and limits
(define-public (configure-tier
    (tier-id uint)
    (price uint)
    (discount uint)
    (limit uint)
  )
  (begin
    (asserts! (or (is-owner) (is-policy-engine)) ERR_UNAUTHORIZED)
    (map-set tier-config tier-id {
      price-usd: price,
      discount-bps: discount,
      api-limit: limit,
    })
    (ok true)
  )
)

;; @desc Grant a tier to a user (e.g., after payment)
(define-public (grant-tier
    (user principal)
    (tier-id uint)
    (duration uint)
  )
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED) ;; Or payment contract
    (let ((config (unwrap! (map-get? tier-config tier-id) ERR_INVALID_TIER)))
      (map-set user-tiers user {
        tier: tier-id,
        expiry: (+ block-height duration),
        discount-bps: (get discount-bps config),
        api-credits: (get api-limit config),
      })
      (ok true)
    )
  )
)

;; --- Public Read ---

(define-read-only (get-user-tier (user principal))
  (let ((info (default-to {
      tier: TIER_FREE,
      expiry: u0,
      discount-bps: u0,
      api-credits: u0,
    }
      (map-get? user-tiers user)
    )))
    (if (< (get expiry info) block-height)
      (ok {
        tier: TIER_FREE,
        expiry: u0,
        discount-bps: u0,
        api-credits: u0,
      })
      ;; Expired -> Free
      (ok info)
    )
  )
)

(define-read-only (get-discount (user principal))
  (let ((info (unwrap-panic (get-user-tier user))))
    (if true
      (ok (get discount-bps info))
      (err u0) ;; Unreachable, forces type inference
    )
  )
)
