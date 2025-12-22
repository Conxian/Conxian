;; dim-yield-stake.clar
;; Dimensional Yield & Staking Module
;; Responsibilities:
;; - Manage staking and lockups for different dimensions.
;; - Calculate and distribute yield based on dimension-specific metrics.

(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)

;; ===== Constants =====
;; Standardized Conxian error codes (800-range for dimensional modules)
(define-constant ERR_UNAUTHORIZED u800)
(define-constant ERR_LOCKUP_NOT_EXPIRED u11707200)
(define-constant ERR_NO_STAKE_FOUND u814)
(define-constant ERR_INVALID_AMOUNT u801)
(define-constant ONE_DAY u17280)
(define-constant ERR_DIMENSION_NOT_CONFIGURED u815)
(define-constant ERR_METRIC_NOT_FOUND u816)
(define-constant ERR_INVALID_LOCK_PERIOD u11764800)
(define-constant ERR_TRANSFER_FAILED u818)

(define-constant BLOCKS_PER_YEAR u90823680000) ;; 52560 * 120
(define-constant PRECISION u10000)
(define-constant MIN_LOCK_PERIOD u248832000) ;; ~1 day
(define-constant MAX_LOCK_PERIOD u454118400000) ;; ~5 years (262800 * 120)

;; ===== Utility Functions =====
(define-read-only (max
    (a uint)
    (b uint)
  )
  (if (> a b)
    a
    b
  )
)

;; ===== Contract State =====
(define-data-var contract-owner principal tx-sender)
(define-data-var dim-metrics-contract principal tx-sender)
(define-data-var token-contract principal tx-sender)
(define-data-var paused bool false)

;; ===== Data Maps =====
;; Stores staking info for a user in a specific dimension
(define-map stakes
  {
    staker: principal,
    dim-id: uint,
  }
  {
    amount: uint,
    unlock-height: uint,
    lock-period: uint,
    stake-height: uint,
    last-claim-height: uint,
  }
)

;; Stores yield parameters for each dimension
;; base-rate and k are scaled by 10000 (e.g., 100 = 1%)
(define-map dimension-params
  { dim-id: uint }
  {
    base-rate: uint,
    k: uint,
    enabled: bool,
  }
)

;; Track total staked per dimension
(define-map dimension-totals
  { dim-id: uint }
  { total-staked: uint }
)

;; ===== Access Control =====
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-not-paused)
  (not (var-get paused))
)

;; ===== Administration Functions =====
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-dim-metrics-contract (metrics-addr principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set dim-metrics-contract metrics-addr)
    (ok true)
  )
)

(define-public (set-token-contract (token-addr principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set token-contract token-addr)
    (ok true)
  )
)

(define-public (set-dimension-params
    (dim-id uint)
    (base-rate uint)
    (k uint)
  )
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (asserts! (<= base-rate u5000) (err ERR_INVALID_AMOUNT)) ;; Max 50% base rate
    (asserts! (<= k u10000) (err ERR_INVALID_AMOUNT)) ;; Max 100% multiplier
    (map-set dimension-params { dim-id: dim-id } {
      base-rate: base-rate,
      k: k,
      enabled: true,
    })
    (ok true)
  )
)

(define-public (toggle-dimension
    (dim-id uint)
    (enabled bool)
  )
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (let ((params (unwrap! (map-get? dimension-params { dim-id: dim-id })
        (err ERR_DIMENSION_NOT_CONFIGURED)
      )))
      (map-set dimension-params { dim-id: dim-id }
        (merge params { enabled: enabled })
      )
      (ok true)
    )
  )
)

(define-public (pause-contract (pause bool))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set paused pause)
    (ok true)
  )
)

;; ===== Staking Core Functions =====
(define-public (stake-dimension
    (dim-id uint)
    (amount uint)
    (lock-period uint)
    (token <sip-010-ft-trait>)
  )
  (begin
    (asserts! (is-not-paused) (err ERR_UNAUTHORIZED))
    (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
    (asserts!
      (and (>= lock-period MIN_LOCK_PERIOD) (<= lock-period MAX_LOCK_PERIOD))
      (err ERR_INVALID_LOCK_PERIOD)
    )

    (let (
        (staker tx-sender)
        (params (unwrap! (map-get? dimension-params { dim-id: dim-id })
          (err ERR_DIMENSION_NOT_CONFIGURED)
        ))
        (current-height block-height)
        (unlock-height (+ current-height lock-period))
        (existing-stake (map-get? stakes {
          staker: staker,
          dim-id: dim-id,
        }))
      )
      (asserts! (get enabled params) (err ERR_DIMENSION_NOT_CONFIGURED))

      ;; Transfer tokens to contract
      (try! (contract-call? token transfer amount staker (as-contract tx-sender) none))

      ;; Update or create stake
      (match existing-stake
        stake
        ;; Add to existing stake
        (map-set stakes {
          staker: staker,
          dim-id: dim-id,
        } {
          amount: (+ (get amount stake) amount),
          unlock-height: (max unlock-height (get unlock-height stake)),
          lock-period: (max lock-period (get lock-period stake)),
          stake-height: (get stake-height stake),
          last-claim-height: current-height,
        })
        ;; Create new stake
        (map-set stakes {
          staker: staker,
          dim-id: dim-id,
        } {
          amount: amount,
          unlock-height: unlock-height,
          lock-period: lock-period,
          stake-height: current-height,
          last-claim-height: current-height,
        })
      )

      ;; Update dimension totals
      (let ((totals (default-to { total-staked: u0 }
          (map-get? dimension-totals { dim-id: dim-id })
        )))
        (map-set dimension-totals { dim-id: dim-id } { total-staked: (+ (get total-staked totals) amount) })
      )

      (ok {
        unlock-height: unlock-height,
        amount: amount,
      })
    )
  )
)

;; ===== Reward Distribution Functions =====
(define-public (claim-rewards
    (dim-id uint)
    (token <sip-010-ft-trait>)
  )
  (let (
      (staker tx-sender)
      (stake-info (unwrap!
        (map-get? stakes {
          staker: staker,
          dim-id: dim-id,
        })
        (err ERR_NO_STAKE_FOUND)
      ))
      (unlock-height (get unlock-height stake-info))
      (staked-amount (get amount stake-info))
    )
    (asserts! (>= block-height unlock-height) (err ERR_LOCKUP_NOT_EXPIRED))

    ;; Calculate rewards
    (let ((rewards (try! (calculate-rewards-for-stake stake-info dim-id))))
      ;; Transfer rewards from contract to the staker
      (try! (contract-call? token transfer rewards (as-contract tx-sender) staker none))

      ;; Return principal to the staker from contract
      (try! (contract-call? token transfer staked-amount (as-contract tx-sender) staker
        none
      ))

      ;; Update dimension totals
      (let ((totals (unwrap! (map-get? dimension-totals { dim-id: dim-id })
          (err ERR_DIMENSION_NOT_CONFIGURED)
        )))
        (map-set dimension-totals { dim-id: dim-id } { total-staked: (- (get total-staked totals) staked-amount) })
      )

      ;; Delete stake info
      (map-delete stakes {
        staker: staker,
        dim-id: dim-id,
      })

      (ok {
        rewards: rewards,
        principal: staked-amount,
      })
    )
  )
)

(define-public (claim-partial-rewards
    (dim-id uint)
    (token <sip-010-ft-trait>)
  )
  (let (
      (staker tx-sender)
      (stake-info (unwrap!
        (map-get? stakes {
          staker: staker,
          dim-id: dim-id,
        })
        (err ERR_NO_STAKE_FOUND)
      ))
      (current-height block-height)
    )
    ;; Calculate rewards since last claim
    (let ((rewards (try! (calculate-rewards-for-stake stake-info dim-id))))
      ;; Transfer rewards
      (try! (contract-call? token transfer rewards (as-contract tx-sender) staker none))

      ;; Update last claim height
      (map-set stakes {
        staker: staker,
        dim-id: dim-id,
      }
        (merge stake-info { last-claim-height: current-height })
      )

      (ok { rewards: rewards })
    )
  )
)

;; ===== Internal Calculations =====
(define-read-only (calculate-rewards-for-stake
    (stake-info {
      amount: uint,
      unlock-height: uint,
      lock-period: uint,
      stake-height: uint,
      last-claim-height: uint,
    })
    (dim-id uint)
  )
  (let (
      (staked-amount (get amount stake-info))
      (lock-period (get lock-period stake-info))
      (last-claim (get last-claim-height stake-info))
      (current-height block-height)
      (blocks-staked (- current-height last-claim))
      (params (unwrap! (map-get? dimension-params { dim-id: dim-id })
        (err ERR_DIMENSION_NOT_CONFIGURED)
      ))
      (base-rate (get base-rate params))
      (k (get k params))
    )
    ;; (contract-call? (var-get dim-metrics-contract) get-dimension-metrics dim-id)
    (ok u0)
    ;; Stubbed reward calculation
  )
)

;; ===== Query Functions =====
(define-read-only (get-stake-info
    (staker principal)
    (dim-id uint)
  )
  (map-get? stakes {
    staker: staker,
    dim-id: dim-id,
  })
)

(define-read-only (get-dimension-params (dim-id uint))
  (map-get? dimension-params { dim-id: dim-id })
)

(define-read-only (get-dimension-totals (dim-id uint))
  (map-get? dimension-totals { dim-id: dim-id })
)

(define-read-only (get-pending-rewards
    (staker principal)
    (dim-id uint)
  )
  (match (map-get? stakes {
    staker: staker,
    dim-id: dim-id,
  })
    stake-info (calculate-rewards-for-stake stake-info dim-id)
    (err ERR_NO_STAKE_FOUND)
  )
)

(define-read-only (is-contract-paused)
  (var-get paused)
)
