;; liquidation-engine.clar
;; Handles position liquidations in the dimensional engine

(use-trait liquidation-trait .risk-management.liquidation-trait)
(use-trait risk-trait .risk-management.risk-manager-trait)
(use-trait oracle-aggregator-v2-trait .oracle-pricing.oracle-aggregator-v2-trait)
(use-trait dimensional-trait .dimensional-traits.dimensional-trait)
(use-trait ft-trait .sip-standards.sip-010-ft-trait)

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
(define-map liquidations {
  position-id: uint,
  timestamp: uint
} {
  liquidator: principal,
  collateral-reclaimed: uint,
  reward: uint,
  price: uint,
  pnl: int
})

;; ===== Initialization =====
(define-public (initialize 
    (owner principal) 
    (oracle principal)
    (risk-manager principal)
    (dimensional-engine principal)
    (insurance-fund principal)
  )
  (begin
    (asserts! (is-eq tx-sender (as-contract tx-sender)) ERR_UNAUTHORIZED)
    (var-set owner owner)
    (var-set oracle-contract oracle)
    (var-set risk-manager-contract risk-manager)
    (var-set dimensional-engine-contract dimensional-engine)
    (var-set insurance-fund insurance-fund)
    (ok true)
  )
)

;; ===== Core Functions =====
(define-private (liquidate-position-internal
    (position-owner principal)
    (position-id uint)
    (max-slippage uint)
    (caller principal)
  )
  (let (
    (current-block block-height)
    (position (unwrap! (contract-call? .dimensional-engine get-position position-owner position-id) ERR_INVALID_POSITION))
    (asset (get asset position))
    (price (unwrap!
      (contract-call? .oracle-aggregator-v2 get-price (get asset position))
      ERR_ORACLE_FAILURE
    ))
  )
    ;; Verify position can be liquidated
    (asserts! (is-eq (get status position) ACTIVE) ERR_POSITION_NOT_ACTIVE)

    ;; Check if position is underwater
    (let (
      (margin-ratio (calculate-margin-ratio position price))
      (maintenance-margin (get maintenance-margin position))
    )
      (asserts! (< margin-ratio maintenance-margin) ERR_POSITION_SAFE)

      ;; Calculate liquidation reward
      (let* (
        (collateral-value (get collateral position))
        (reward-amount (min
          (max
            (/ (* collateral-value (var-get min-liquidation-reward)) u10000)
            (var-get min-liquidation-reward)
          )
          (var-get max-liquidation-reward)
        ))
        (remaining-collateral (- collateral-value reward-amount))
      )
        ;; Transfer reward to liquidator
        (try! (contract-call? asset transfer reward-amount tx-sender caller none))

        ;; Transfer remaining to insurance fund
        (try! (contract-call? asset transfer remaining-collateral tx-sender (var-get insurance-fund) none))

        ;; Close the position
        (try! (contract-call? (var-get dimensional-engine-contract) close-position position-owner position-id u0))

        ;; Record liquidation
        (map-set liquidations {
          position-id: position-id,
          timestamp: current-block
        } {
          liquidator: caller,
          collateral-reclaimed: collateral-value,
          reward: reward-amount,
          price: price,
          pnl: (calculate-pnl position price)
        })

        (ok true)
      )
    )
  )
)

(define-public (liquidate-position
    (position-owner principal)
    (position-id uint)
    (max-slippage uint)
  )
  (liquidate-position-internal position-owner position-id max-slippage tx-sender)
)

;; ===== Batch Liquidations =====
(define-public (liquidate-positions
    (positions (list 20 {owner: principal, id: uint}))
    (max-slippage uint)
  )
  (let (
    (results (map
      (lambda (position)
        (match (liquidate-position-internal
          (get owner position)
          (get id position)
          max-slippage
          tx-sender
        )
          success (ok true)
          error error
        )
      )
      positions
    ))
  )
    (ok results)
  )
)

;; ===== Health Checks =====
(define-read-only (check-position-health
    (position-owner principal)
    (position-id uint)
  )
  (let (
    (position (unwrap! (contract-call? (var-get dimensional-engine-contract) get-position position-owner position-id) ERR_INVALID_POSITION))
    (asset (get asset position))
    (price (unwrap! (contract-call? .oracle_aggregator_v2 get-twap asset)
      ERR_ORACLE_FAILURE
    ))
    (margin-ratio (calculate-margin-ratio position price))
    (liquidation-price u0)
  )
    (ok {
      margin-ratio: margin-ratio,
      liquidation-price: liquidation-price,
      current-price: price,
      health-factor: (/ margin-ratio (get maintenance-margin position)),
      is-liquidatable: (< margin-ratio (get maintenance-margin position))
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
    (asserts! (and (<= min-reward max-reward) (<= max-reward u5000)) ERR_INVALID_REWARD_RANGE)
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
    (position {collateral: uint, size: int, entry-price: uint})
    (current-price uint)
  )
  (let (
    (position-value (/ (* (abs (get size position)) current-price) u100000000))
    (pnl (calculate-pnl position current-price))
    (collateral (get collateral position))
  )
    (if (> position-value u0)
      (/ (* (+ collateral pnl) u10000) position-value)
      u0
    )
  )
)

(define-private (calculate-pnl
    (position {size: int, entry-price: uint})
    (current-price uint)
  )
  (let (
    (price-diff (- current-price (get entry-price position)))
    (position-size (abs (get size position)))
  )
    (if (> (get size position) 0)
      ;; Long position
      (/ (* position-size price-diff) (get entry-price position))
      ;; Short position
      (/ (* position-size (- (get entry-price position) current-price)) (get entry-price position))
    )
  )
)

;; ===== Utility Functions =====
;; Absolute value for signed integers
(define-private (abs (x int))
  (if (< x 0) (- 0 x) x)
)

;; Max/Min helpers for uint
(define-private (max (a uint) (b uint))
  (if (> a b) a b)
)

(define-private (min (a uint) (b uint))
  (if (< a b) a b)
)
