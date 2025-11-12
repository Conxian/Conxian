;; tiered-pools.clar

;; ===== Traits =====
(use-trait pool-factory-trait .all-traits.pool-factory-trait)
(use-trait fee-manager-trait .all-traits.fee-manager-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_POOL_ALREADY_EXISTS (err u101))
(define-constant ERR_POOL_NOT_FOUND (err u102))
(define-constant ERR_INVALID_FEE_TIER (err u103))
(define-constant ERR_INVALID_POOL_CONTRACT (err u104))
(define-constant ERR_SWAP_FAILED (err u105))
(define-constant ERR_LIQUIDITY_FAILED (err u106))

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)

;; ===== Data Maps =====
(define-map pools 
  {pool-id: principal} 
  {
    token-x: principal,
    token-y: principal,
    fee-tier-id: uint,
    active: bool
  })

;; ===== Private Functions =====
(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)))

(define-data-var fee-manager-contract (optional principal) none)

(define-private (validate-fee-tier (fee-tier-id uint))
  (let ((fee-manager (unwrap! (var-get fee-manager-contract) (err ERR_FEE_MANAGER_NOT_SET))))
    (match (contract-call? fee-manager get-fee-tier fee-tier-id)
      success (ok true)
      error ERR_INVALID_FEE_TIER)))

(define-constant ERR_FEE_MANAGER_NOT_SET (err u1000))

;; ===== Admin Functions =====
(define-public (set-fee-manager-contract (new-fee-manager principal))
  (begin
    (unwrap-panic (check-is-owner))
    (var-set fee-manager-contract (some new-fee-manager))
    (ok true)
  )
) 
;; ===== Public Functions =====
(define-public (create-pool 
  (pool-id principal) 
  (token-x principal) 
  (token-y principal) 
  (fee-tier-id uint))
  (begin
    (unwrap-panic (check-is-owner))
    (asserts! (is-none (contract-call? .pool-registry get-pool-data pool-id)) ERR_POOL_ALREADY_EXISTS)
    (asserts! (validate-fee-tier fee-tier-id) ERR_INVALID_FEE_TIER)
    (ok (contract-call? .pool-factory create-pool pool-id token-x token-y fee-tier-id))
  )
)


(define-public (set-pool-fee-tier (pool-id principal) (new-fee-tier-id uint))
  (begin
    (try! (check-is-owner))
    
    (let ((pool-data (unwrap! (map-get? pools {pool-id: pool-id}) ERR_POOL_NOT_FOUND)))
      (try! (validate-fee-tier new-fee-tier-id))
      
      (map-set pools {pool-id: pool-id}
        (merge pool-data {fee-tier-id: new-fee-tier-id}))
      (ok true))))

(define-public (toggle-pool-active (pool-id principal) (active bool))
  (begin
    (try! (check-is-owner))
    
    (let ((pool-data (unwrap! (map-get? pools {pool-id: pool-id}) ERR_POOL_NOT_FOUND)))
      (map-set pools {pool-id: pool-id}
        (merge pool-data {active: active}))
      (ok true))))

(define-public (swap 
  (pool-id principal) 
  (token-in principal) 
  (token-out principal) 
  (amount-in uint) 
  (min-amount-out uint))
  (let ((pool-data (unwrap! (map-get? pools {pool-id: pool-id}) ERR_POOL_NOT_FOUND)))
    (asserts! (get active pool-data) ERR_POOL_NOT_FOUND)
    
    ;; Delegate to actual pool contract
    (match (as-contract (contract-call? pool-id swap token-in token-out amount-in min-amount-out))
      success (ok success)
      error ERR_SWAP_FAILED)))

(define-public (add-liquidity 
  (pool-id principal) 
  (token-x-amount uint) 
  (token-y-amount uint) 
  (min-lp-tokens uint))
  (let ((pool-data (unwrap! (map-get? pools {pool-id: pool-id}) ERR_POOL_NOT_FOUND)))
    (asserts! (get active pool-data) ERR_POOL_NOT_FOUND)
    
    ;; Delegate to actual pool contract
    (match (as-contract (contract-call? pool-id add-liquidity token-x-amount token-y-amount min-lp-tokens))
      success (ok success)
      error ERR_LIQUIDITY_FAILED)))

(define-public (remove-liquidity 
  (pool-id principal) 
  (lp-tokens uint) 
  (min-token-x-amount uint) 
  (min-token-y-amount uint))
  (let ((pool-data (unwrap! (map-get? pools {pool-id: pool-id}) ERR_POOL_NOT_FOUND)))
    (asserts! (get active pool-data) ERR_POOL_NOT_FOUND)
    
    ;; Delegate to actual pool contract
    (match (as-contract (contract-call? pool-id remove-liquidity lp-tokens min-token-x-amount min-token-y-amount))
      success (ok success)
      error ERR_LIQUIDITY_FAILED)))

(define-public (set-contract-owner (new-owner principal))
  (begin
    (try! (check-is-owner))
    (var-set contract-owner new-owner)
    (ok true)))

;; ===== Read-Only Functions =====
(define-read-only (get-pool (pool-id principal))
  (ok (map-get? pools {pool-id: pool-id})))

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner)))

(define-read-only (is-pool-active (pool-id principal))
  (match (map-get? pools {pool-id: pool-id})
    pool-data (ok (get active pool-data))
    (ok false)))