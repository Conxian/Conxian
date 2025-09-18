;; dim-yield-stake.clar
;; Dimensional Yield & Staking Module
;; Responsibilities:
;; - Manage staking and lockups for different dimensions.
;; - Calculate and distribute yield based on dimension-specific metrics.

(define-constant ERR_UNAUTHORIZED u101)
(define-constant ERR_LOCKUP_NOT_EXPIRED u102)
(define-constant ERR_NO_STAKE_FOUND u103)
(define-constant ERR_INVALID_AMOUNT u104)
(define-constant ERR_DIMENSION_NOT_CONFIGURED u105)
(define-constant ERR_METRIC_NOT_FOUND u106)

;; --- Contract Dependencies ---
(use-trait sip-010 .sip-010-ft-trait.sip-010-ft-trait)

(define-data-var contract-owner principal tx-sender)
(define-data-var dim-metrics-contract principal tx-sender) ;; placeholder, should be set at deployment
(define-data-var token-contract principal tx-sender) ;; placeholder, should be set at deployment

;; --- Data Storage ---

;; Stores staking info for a user in a specific dimension
(define-map stakes {staker: principal, dim-id: uint} {amount: uint, unlock-height: uint, lock-period: uint})

;; Stores yield parameters for each dimension
;; base-rate and k are scaled by 10000 (e.g., 100 = 1%)
(define-map dimension-params {dim-id: uint} {base-rate: uint, k: uint})

;; --- Owner Functions ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (set-dim-metrics-contract (metrics-addr principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set dim-metrics-contract metrics-addr)
    (ok true)))

(define-public (set-token-contract (token-addr principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set token-contract token-addr)
    (ok true)))

(define-public (set-dimension-params (dim-id uint) (base-rate uint) (k uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set dimension-params {dim-id: dim-id} {base-rate: base-rate, k: k})
    (ok true)))


;; --- Staking Functions ---

(define-public (stake-dimension (dim-id uint) (amount uint) (lock-period uint) (token sip-010))
  (begin
    (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
    (asserts! (is-some (map-get? dimension-params {dim-id: dim-id})) (err ERR_DIMENSION_NOT_CONFIGURED))
    (let ((staker tx-sender))
      (try! (contract-call? token transfer amount staker (as-contract tx-sender) none))
      (map-set stakes
        {staker: staker, dim-id: dim-id}
        {amount: amount, unlock-height: (+ block-height lock-period), lock-period: lock-period}
      )
    )
    (ok (+ block-height lock-period))
  )
)

;; --- Claiming Functions ---

(define-public (claim-rewards (dim-id uint) (token sip-010))
  (let (
      (staker tx-sender)
      (stake-info (unwrap! (map-get? stakes {staker: staker, dim-id: dim-id}) (err ERR_NO_STAKE_FOUND)))
      (unlock-height (get unlock-height stake-info))
      (staked-amount (get amount stake-info))
    )
    (asserts! (>= block-height unlock-height) (err ERR_LOCKUP_NOT_EXPIRED))

    ;; Calculate rewards
    (let ((rewards (try! (calculate-rewards-for-stake stake-info dim-id))))
      ;; Transfer rewards from contract to the staker
      (try! (as-contract (contract-call? token transfer rewards tx-sender staker none)))
      ;; Return principal to the staker from contract
      (try! (as-contract (contract-call? token transfer staked-amount tx-sender staker none)))
      ;; Delete stake info
      (map-delete stakes {staker: staker, dim-id: dim-id})
      (ok {rewards: rewards, principal: staked-amount})
    )
  )
)


;; --- Read-Only & Private Functions ---

(define-private (calculate-rewards-for-stake (stake-info {amount: uint, unlock-height: uint, lock-period: uint}) (dim-id uint))
  (let (
      (staked-amount (get amount stake-info))
      (lock-period (get lock-period stake-info))
      (params (unwrap! (map-get? dimension-params {dim-id: dim-id}) (err ERR_DIMENSION_NOT_CONFIGURED)))
      (base-rate (get base-rate params))
      (k (get k params))
      ;; Metric ID for utilization is u1
      (metric-opt (contract-call? .dim-metrics get-metric dim-id u1))
    )
    (match metric-opt
      utilization-metric
        (let (
            (utilization (get value utilization-metric))
          )
          ;; APR = baseRate + k * Utilization
          ;; We assume base-rate, k and utilization are scaled by 10000 (e.g., 100 = 1%)
          (let ((apr (+ base-rate (/ (* k utilization) u10000))))
            ;; Reward = amount * APR * lock_period_in_years
            ;; We approximate 1 year = 52560 blocks
            ;; To avoid floating points, we calculate: (amount * apr * lock_period) / (10000 * 52560)
            (ok (/ (* staked-amount (* apr lock-period)) u525600000))
          )
        )
      (err ERR_METRIC_NOT_FOUND)
    )
  )
)

(define-read-only (get-stake-info (staker principal) (dim-id uint))
    (map-get? stakes {staker: staker, dim-id: dim-id})
)





