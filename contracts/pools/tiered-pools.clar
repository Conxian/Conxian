;; Tiered Pools Contract

(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_POOL_EXISTS (err u101))
(define-constant ERR_POOL_NOT_FOUND (err u102))
(define-constant ERR_INVALID_FEE (err u103))
(define-constant ERR_INVALID_POOL (err u104))
(define-constant ERR_SWAP_FAILED (err u105))
(define-constant ERR_LIQUIDITY_FAILED (err u106))
(define-constant ERR_POOL_FACTORY_MISSING (err u1001))
(define-constant ERR_FEE_MANAGER_MISSING (err u1000))
(define-constant ERR_DIM_ORACLE_MISSING (err u1002))

(define-data-var owner principal tx-sender)
(define-data-var fee-manager-contract (optional principal) none)
(define-data-var pool-factory-contract (optional principal) none)

(define-map pools
  { pool-id: principal }
  {
    token-x: principal,
    token-y: principal,
    fee-tier: uint,
    active: bool,
  }
)

(define-private (check-owner)
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (ok true)
  )
)

(define-public (set-fee-manager-contract (new-fee-manager principal))
  (begin
    (try! (check-owner))
    (var-set fee-manager-contract (some new-fee-manager))
    (ok true)
  )
)

(define-public (set-pool-factory-contract (new-pool-factory principal))
  (begin
    (try! (check-owner))
    (var-set pool-factory-contract (some new-pool-factory))
    (ok true)
  )
)

(define-public (create-pool
    (pool-id principal)
    (token-x principal)
    (token-y principal)
    (fee-tier uint)
  )
  (begin
    (try! (check-owner))
    (try! (validate-fee-tier fee-tier))
    (map-set pools { pool-id: pool-id } {
      token-x: token-x,
      token-y: token-y,
      fee-tier: fee-tier,
      active: true,
    })
    (ok true)
  )
)

(define-public (set-pool-fee-tier
    (pool-id principal)
    (new-fee-tier uint)
  )
  (begin
    (try! (check-owner))
    (let ((pool-data (unwrap! (map-get? pools { pool-id: pool-id }) ERR_POOL_NOT_FOUND)))
      (try! (validate-fee-tier new-fee-tier))
      (map-set pools { pool-id: pool-id }
        (merge pool-data { fee-tier: new-fee-tier })
      )
      (ok true)
    )
  )
)

(define-public (toggle-pool-active
    (pool-id principal)
    (active bool)
  )
  (begin
    (try! (check-owner))
    (let ((pool-data (unwrap! (map-get? pools { pool-id: pool-id }) ERR_POOL_NOT_FOUND)))
      (map-set pools { pool-id: pool-id } (merge pool-data { active: active }))
      (ok true)
    )
  )
)

(define-public (swap
    (pool-id principal)
    (token-in principal)
    (token-out principal)
    (amount-in uint)
    (min-amount-out uint)
  )
  (let ((pool-data (unwrap! (map-get? pools { pool-id: pool-id }) ERR_POOL_NOT_FOUND)))
    (asserts! (get active pool-data) ERR_POOL_NOT_FOUND)
    ;; v1: minimal swap logic; ensure token-in belongs to pool and echo amount-in
    (asserts!
      (or
        (is-eq token-in (get token-x pool-data))
        (is-eq token-in (get token-y pool-data))
      )
      ERR_INVALID_POOL
    )
    (ok amount-in)
  )
)

(define-public (add-liquidity
    (pool-id principal)
    (token-x-amount uint)
    (token-y-amount uint)
    (min-lp-tokens uint)
  )
  (let ((pool-data (unwrap! (map-get? pools { pool-id: pool-id }) ERR_POOL_NOT_FOUND)))
    (asserts! (get active pool-data) ERR_POOL_NOT_FOUND)
    ;; v1: return requested LP token amount as minted
    (ok min-lp-tokens)
  )
)

(define-public (remove-liquidity
    (pool-id principal)
    (lp-tokens uint)
    (min-token-x-amount uint)
    (min-token-y-amount uint)
  )
  (let ((pool-data (unwrap! (map-get? pools { pool-id: pool-id }) ERR_POOL_NOT_FOUND)))
    (asserts! (get active pool-data) ERR_POOL_NOT_FOUND)
    ;; v1: assume LP tokens can be burned 1:1 and ignore min amounts
    (ok lp-tokens)
  )
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (try! (check-owner))
    (var-set owner new-owner)
    (ok true)
  )
)

(define-read-only (get-pool (pool-id principal))
  (ok (map-get? pools { pool-id: pool-id }))
)

(define-read-only (get-owner)
  (ok (var-get owner))
)

(define-read-only (is-pool-active (pool-id principal))
  (match (map-get? pools { pool-id: pool-id })
    pool-data (get active pool-data)
    false
  )
)

;; Basic fee-tier validation: ensure non-zero fee; extend with additional
;; constraints as needed. Returns (response bool uint) so it composes with try!.
(define-private (validate-fee-tier (fee-tier uint))
  (begin
    (asserts! (> fee-tier u0) ERR_INVALID_FEE)
    (ok true)
  )
)
