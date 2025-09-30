;; fee-manager.clar
;; Manages fee structures and dynamic adjustments

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait fee-manager-trait .all-traits.fee-manager-trait)

(impl-trait fee-manager-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_FEE_TIER (err u101))
(define-constant ERR_FEE_TIER_EXISTS (err u102))
(define-constant ERR_FEE_TIER_NOT_FOUND (err u103))

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)

;; fee-tiers: {tier-id: uint} {fee-rate: uint, description: (string-ascii 64)}
(define-map fee-tiers {
  tier-id: uint
} {
  fee-rate: uint, ;; in basis points (e.g., u30 for 0.3%)
  description: (string-ascii 64)
})

;; pool-fee-tiers: {pool-id: principal} {tier-id: uint}
(define-map pool-fee-tiers {
  pool-id: principal
} {
  tier-id: uint
})

;; ===== Public Functions =====

(define-public (add-fee-tier (tier-id uint) (fee-rate uint) (description (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? fee-tiers {tier-id: tier-id})) ERR_FEE_TIER_EXISTS)
    (asserts! (and (>= fee-rate u0) (<= fee-rate u10000)) ERR_INVALID_FEE_TIER) ;; 0-10000 basis points (0-100%)
    (map-set fee-tiers {tier-id: tier-id} {
      fee-rate: fee-rate,
      description: description
    })
    (ok true)
  )
)

(define-public (update-fee-tier (tier-id uint) (fee-rate uint) (description (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? fee-tiers {tier-id: tier-id})) ERR_FEE_TIER_NOT_FOUND)
    (asserts! (and (>= fee-rate u0) (<= fee-rate u10000)) ERR_INVALID_FEE_TIER)
    (map-set fee-tiers {tier-id: tier-id} {
      fee-rate: fee-rate,
      description: description
    })
    (ok true)
  )
)

(define-public (set-pool-fee-tier (pool-id principal) (tier-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? fee-tiers {tier-id: tier-id})) ERR_FEE_TIER_NOT_FOUND)
    (map-set pool-fee-tiers {pool-id: pool-id} {tier-id: tier-id})
    (ok true)
  )
)

;; ===== Read-Only Functions =====

(define-read-only (get-fee-tier (tier-id uint))
  (ok (map-get? fee-tiers {tier-id: tier-id}))
)

(define-read-only (get-pool-fee-tier (pool-id principal))
  (ok (map-get? pool-fee-tiers {pool-id: pool-id}))
)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)
