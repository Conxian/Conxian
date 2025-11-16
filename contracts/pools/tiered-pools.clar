;; Tiered Pools Contract

(use-trait pool-factory-trait .pool-factory-trait.pool-factory-trait)
(use-trait fee-manager-trait .new-file.fee-manager-trait)
(use-trait dimensional-oracle-trait .dimensional-traits.dimensional-oracle-trait)

(define-constant ERR_UNAUTHORIZED u100 "Unauthorized operation")
(define-constant ERR_POOL_EXISTS u101 "Pool already exists")
(define-constant ERR_POOL_NOT_FOUND u102 "Pool not found")
(define-constant ERR_INVALID_FEE u103 "Invalid fee tier")
(define-constant ERR_INVALID_POOL u104 "Invalid pool contract")
(define-constant ERR_SWAP_FAILED u105 "Swap failed")
(define-constant ERR_LIQUIDITY_FAILED u106 "Liquidity operation failed")
(define-constant ERR_POOL_FACTORY_MISSING u1001 "Pool factory not set")
(define-constant ERR_FEE_MANAGER_MISSING u1000 "Fee manager not set")

(define-data-var owner principal tx-sender)

(define-map pools
  {pool-id: principal}
  {token-x: principal, token-y: principal, fee-tier: uint, active: bool})

(define-private (check-owner)
  (ok (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)))

(define-public (set-fee-manager-contract (new-fee-manager principal))
  (begin
    (unwrap-panic (check-owner))
    (var-set fee-manager-contract (some new-fee-manager))))

(define-public (set-pool-factory-contract (new-pool-factory principal))
  (begin
    (unwrap-panic (check-owner))
    (var-set pool-factory-contract (some new-pool-factory))))

(define-public (create-pool (pool-id principal) (token-x principal) (token-y principal) (fee-tier uint))
  (begin
    (unwrap-panic (check-owner))
    (asserts! (validate-fee-tier fee-tier) ERR_INVALID_FEE)
    (let ((factory (unwrap! (var-get pool-factory-contract) ERR_POOL_FACTORY_MISSING)))
      (try! (contract-call? factory create-pool token-x token-y "tiered-pool"))
      (map-set pools {pool-id: pool-id}
               {token-x: token-x, token-y: token-y, fee-tier: fee-tier, active: true}))))

(define-public (set-pool-fee-tier (pool-id principal) (new-fee-tier uint))
  (begin
    (try! (check-owner))
    (let ((pool-data (unwrap! (map-get? pools {pool-id: pool-id}) ERR_POOL_NOT_FOUND)))
      (try! (validate-fee-tier new-fee-tier))
      (map-set pools {pool-id: pool-id}
               (merge pool-data {fee-tier: new-fee-tier})))))

(define-public (toggle-pool-active (pool-id principal) (active bool))
  (begin
    (try! (check-owner))
    (let ((pool-data (unwrap! (map-get? pools {pool-id: pool-id}) ERR_POOL_NOT_FOUND)))
      (map-set pools {pool-id: pool-id}
               (merge pool-data {active: active})))))

(define-public (swap (pool-id principal) (token-in principal) (token-out principal) (amount-in uint)
                    (min-amount-out uint))
  (let ((pool-data (unwrap! (map-get? pools {pool-id: pool-id}) ERR_POOL_NOT_FOUND)))
    (asserts! (get active pool-data) ERR_POOL_NOT_FOUND)
    (let ((dim-oracle (unwrap! (var-get dimensional-oracle-contract) ERR_DIM_ORACLE_MISSING)))
      (try! (contract-call? dim-oracle check-fee-tier (get fee-tier pool-data))))
    (match (as-contract (contract-call? pool-id swap token-in token-out amount-in min-amount-out))
      success (ok success)
      error ERR_SWAP_FAILED)))

(define-public (add-liquidity (pool-id principal) (token-x-amount uint) (token-y-amount uint)
                             (min-lp-tokens uint))
  (let ((pool-data (unwrap! (map-get? pools {pool-id: pool-id}) ERR_POOL_NOT_FOUND)))
    (asserts! (get active pool-data) ERR_POOL_NOT_FOUND)
    (match (as-contract (contract-call? pool-id add-liquidity token-x-amount token-y-amount
                                         min-lp-tokens))
      success (ok success)
      error ERR_LIQUIDITY_FAILED)))

(define-public (remove-liquidity (pool-id principal) (lp-tokens uint) (min-token-x-amount uint)
                                (min-token-y-amount uint))
  (let ((pool-data (unwrap! (map-get? pools {pool-id: pool-id}) ERR_POOL_NOT_FOUND)))
    (asserts! (get active pool-data) ERR_POOL_NOT_FOUND)
    (match (as-contract (contract-call? pool-id remove-liquidity lp-tokens min-token-x-amount
                                         min-token-y-amount))
      success (ok success)
      error ERR_LIQUIDITY_FAILED)))

(define-public (set-contract-owner (new-owner principal))
  (begin
    (try! (check-owner))
    (var-set owner new-owner)))

(define-read-only (get-pool (pool-id principal))
  (ok (map-get? pools {pool-id: pool-id})))

(define-read-only (get-owner)
  (ok (var-get owner)))

(define-read-only (is-pool-active (pool-id principal))
  (match (map-get? pools {pool-id: pool-id})
    pool-data (ok (get active pool-data))
    (ok false)))

(define-private (validate-fee-tier (fee-tier uint))
  (let ((fee-manager (unwrap! (var-get fee-manager-contract) ERR_FEE_MANAGER_MISSING)))
    (match (contract-call? fee-manager get-fee-tier fee-tier)
      success (ok true)
      error ERR_INVALID_FEE)))
