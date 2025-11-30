;; ===========================================
;; POOL REGISTRY CONTRACT
;; ===========================================
;; Manages registration and tracking of liquidity pools

;; Use decentralized traits
(use-trait rbac-trait .core-traits.rbac-trait)

;; ===========================================
;; DATA STRUCTURES
;; ===========================================

(define-data-var next-pool-id uint u0)

(define-map pools
  { pool-id: uint }
  {
    token-x: principal,
    token-y: principal,
    fee-tier: uint,
    pool-address: principal,
    created-at: uint,
    creator: principal,
    is-active: bool
  }
)

;; ===========================================
;; PUBLIC FUNCTIONS
;; ===========================================

(define-public (register-pool
    (token-x principal)
    (token-y principal)
    (fee-tier uint)
    (pool-address principal)
  )
  (let ((pool-id (var-get next-pool-id)))
    ;; Validate inputs
    (asserts! (not (is-eq token-x token-y)) (err u100))
    (asserts! (> fee-tier u0) (err u101))

    ;; Register pool
    (map-set pools { pool-id: pool-id } {
      token-x: token-x,
      token-y: token-y,
      fee-tier: fee-tier,
      pool-address: pool-address,
      created-at: block-height,
      creator: tx-sender,
      is-active: true
    })

    (var-set next-pool-id (+ pool-id u1))
    (ok pool-id)
  )
)

;; ===========================================
;; READ FUNCTIONS
;; ===========================================

(define-read-only (get-pool-data (pool-id uint))
  (map-get? pools { pool-id: pool-id })
)

(define-read-only (get-pool-count)
  (ok (var-get next-pool-id))
)
