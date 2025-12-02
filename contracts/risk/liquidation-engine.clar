;; liquidation-engine.clar
;; Handles position liquidations in the dimensional engine

(use-trait liquidation-trait .dimensional-traits.liquidation-trait)
(use-trait risk-trait .dimensional-traits.risk-manager-trait)
(use-trait oracle-aggregator-v2-trait .oracle-pricing.oracle-aggregator-v2-trait)
(use-trait dimensional-trait .dimensional-traits.dimensional-trait)
(use-trait position-manager-trait .dimensional-traits.position-manager-trait)
(use-trait ft-trait .defi-traits.sip-010-ft-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u4000))
(define-constant ERR_POSITION_SAFE (err u4001))
(define-constant ERR_LIQUIDATION_FAILED (err u4002))
(define-constant ERR_INSUFFICIENT_REWARD (err u4003))
(define-constant ERR_INVALID_POSITION (err u4004))
(define-constant ERR_ORACLE_FAILURE (err u4005))
(define-constant ERR_RISK_MANAGER_FAILURE (err u4006))
(define-constant ERR_POSITION_NOT_ACTIVE (err u4007))
(define-constant ERR_INVALID_REWARD_RANGE (err u4008))
(define-constant ERR_INVALID_ASSET (err u4009))
(define-constant ACTIVE "active")

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var oracle-contract principal tx-sender)
(define-data-var risk-manager-contract principal tx-sender)
(define-data-var dimensional-engine-contract principal tx-sender)
(define-data-var min-liquidation-reward uint u100)
(define-data-var max-liquidation-reward uint u1000)
(define-data-var insurance-fund principal tx-sender)

;; Liquidation history
(define-map liquidations
  {
    position-id: uint,
    timestamp: uint,
  }
  {
    liquidator: principal,
    collateral-reclaimed: uint,
    reward: uint,
    price: uint,
    pnl: int,
  }
)

;; ===== Initialization =====
(define-public (initialize
    (new-owner principal)
    (oracle principal)
    (risk-manager principal)
    (dimensional-engine principal)
    (new-insurance-fund principal)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set owner new-owner)
    (var-set oracle-contract oracle)
    (var-set risk-manager-contract risk-manager)
    (var-set dimensional-engine-contract dimensional-engine)
    (var-set insurance-fund new-insurance-fund)
    (ok true)
  )
)

;; ===== Core Functions =====
(define-private (liquidate-position-internal
    (position-owner principal)
    (position-id uint)
    (max-slippage uint)
    (caller principal)
    (dim-engine <dimensional-trait>)
    (oracle <oracle-aggregator-v2-trait>)
    (asset-trait <ft-trait>)
  )
  (let (
      (current-block block-height)
      (position (unwrap!
        (unwrap! (contract-call? dim-engine get-position position-id)
          ERR_INVALID_POSITION
        )
        ERR_INVALID_POSITION
      ))
      (asset (get asset position))
      (price (unwrap! (contract-call? oracle get-real-time-price (get asset position))
        ERR_ORACLE_FAILURE
      ))
    )
    ;; Verify passed traits match configured contracts
    (asserts!
      (is-eq (contract-of dim-engine) (var-get dimensional-engine-contract))
      ERR_UNAUTHORIZED
    )
    (asserts! (is-eq (contract-of oracle) (var-get oracle-contract))
      ERR_UNAUTHORIZED
    )
    (asserts! (is-eq (contract-of asset-trait) asset) ERR_INVALID_ASSET)

    ;; Verify position can be liquidated
    ;; (asserts! (is-eq (get status position) ACTIVE) ERR_POSITION_NOT_ACTIVE)

    ;; Check if position is underwater
    (let (
        (margin-ratio (calculate-margin-ratio position price))
        (maintenance-margin u500)
      )
      (asserts! (< margin-ratio maintenance-margin) ERR_POSITION_SAFE)

      ;; Calculate liquidation reward
      (let ((collateral-value (get collateral position)))
        (let ((reward-amount (min
            (max (/ (* collateral-value (var-get min-liquidation-reward)) u10000)
              (var-get min-liquidation-reward)
            )
            (var-get max-liquidation-reward)
          )))
          (let ((remaining-collateral (- collateral-value reward-amount)))
            ;; Transfer reward to liquidator
            (try! (contract-call? asset-trait transfer reward-amount tx-sender caller
              none
            ))
            ;; Transfer remaining to insurance fund
            (try! (contract-call? asset-trait transfer remaining-collateral tx-sender
              (var-get insurance-fund) none
            ))
            ;; Close the position
            (try! (contract-call? dim-engine liquidate-position position-id caller))
            ;; Record liquidation
            (map-set liquidations {
              position-id: position-id,
              timestamp: current-block,
            } {
              liquidator: caller,
              collateral-reclaimed: collateral-value,
              reward: reward-amount,
              price: price,
              pnl: (calculate-pnl position price),
            })
            (ok true)
          )
        )
      )
    )
  )
)

(define-public (liquidate-position
    (position-owner principal)
    (position-id uint)
    (max-slippage uint)
    (dim-engine <dimensional-trait>)
    (oracle <oracle-aggregator-v2-trait>)
    (asset-trait <ft-trait>)
  )
  (liquidate-position-internal position-owner position-id max-slippage tx-sender
    dim-engine oracle asset-trait
  )
)

;; ===== Batch Liquidations =====
(define-public (liquidate-positions
    (positions (list 20 {
      owner: principal,
      id: uint,
    }))
    (max-slippage uint)
    (dim-engine <dimensional-trait>)
    (oracle <oracle-aggregator-v2-trait>)
  )
  (let ((results (list)))
    (ok results)
  )
)

;; ===== Health Checks =====
(define-public (check-position-health
    (position-id uint)
    (pos-mgr <position-manager-trait>)
    (oracle <oracle-aggregator-v2-trait>)
  )
  (let (
      (position (try! (contract-call? pos-mgr get-position position-id)))
      (asset (get asset position))
      (price (try! (contract-call? oracle get-real-time-price asset)))
      (margin-ratio (calculate-margin-ratio position price))
      (liquidation-price u0)
    )
    (ok {
      margin-ratio: margin-ratio,
      liquidation-price: liquidation-price,
      current-price: price,
      health-factor: (/ margin-ratio u500),
      is-liquidatable: (< margin-ratio u500),
    })
  )
)

;; ===== Admin Functions =====
(define-public (set-oracle-contract (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set oracle-contract oracle)
    (ok true)
  )
)

(define-public (set-risk-manager-contract (risk-manager principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set risk-manager-contract risk-manager)
    (ok true)
  )
)

(define-public (set-dimensional-engine-contract (dimensional-engine principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set dimensional-engine-contract dimensional-engine)
    (ok true)
  )
)

(define-public (set-liquidation-rewards
    (min-reward uint)
    (max-reward uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (asserts! (and (<= min-reward max-reward) (<= max-reward u5000))
      ERR_INVALID_REWARD_RANGE
    )
    (var-set min-liquidation-reward min-reward)
    (var-set max-liquidation-reward max-reward)
    (ok true)
  )
)

(define-public (set-insurance-fund (fund principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set insurance-fund fund)
    (ok true)
  )
)

;; ===== Private Functions =====
(define-private (calculate-margin-ratio
    (position {
      asset: principal,
      collateral: uint,
      entry-price: uint,
      funding-rate: int,
      is-active: bool,
      is-long: bool,
      last-updated: uint,
      leverage: uint,
      owner: principal,
      size: uint,
      stop-loss: (optional uint),
      take-profit: (optional uint),
    })
    (current-price uint)
  )
  (let (
      (position-value (/ (* (get size position) current-price) u100000000))
      (pnl (calculate-pnl position current-price))
      (collateral (get collateral position))
    )
    (if (> position-value u0)
      (let ((equity (+ (to-int collateral) pnl)))
        (if (> equity 0)
          (/ (* (to-uint equity) u10000) position-value)
          u0
        )
      )
      u0
    )
  )
)

(define-private (calculate-pnl
    (position {
      asset: principal,
      collateral: uint,
      entry-price: uint,
      funding-rate: int,
      is-active: bool,
      is-long: bool,
      last-updated: uint,
      leverage: uint,
      owner: principal,
      size: uint,
      stop-loss: (optional uint),
      take-profit: (optional uint),
    })
    (current-price uint)
  )
  (let (
      (price-diff (if (>= current-price (get entry-price position))
        (to-int (- current-price (get entry-price position)))
        (- 0 (to-int (- (get entry-price position) current-price)))
      ))
      (position-size (to-int (get size position)))
    )
    (if (get is-long position)
      ;; Long position
      (/ (* position-size price-diff) (to-int (get entry-price position)))
      ;; Short position
      (/ (* position-size (- 0 price-diff)) (to-int (get entry-price position)))
    )
  )
)

;; ===== Utility Functions =====
;; Absolute value for signed integers
(define-private (abs (x int))
  (if (< x 0)
    (- 0 x)
    x
  )
)

;; Max/Min helpers for uint
(define-private (max
    (a uint)
    (b uint)
  )
  (if (> a b)
    a
    b
  )
)

(define-private (min
    (a uint)
    (b uint)
  )
  (if (< a b)
    a
    b
  )
)
