;; liquidation-engine.clar
;; Handles position liquidations in the dimensional engine

(use-trait liquidation-trait .all-traits.liquidation-trait)
(use-trait risk-trait .all-traits.risk-trait)
(use-trait oracle-trait .all-traits.oracle-trait)
(use-trait dimensional-trait .all-traits.dimensional-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u4000))
(define-constant ERR_POSITION_SAFE (err u4001))
(define-constant ERR_LIQUIDATION_FAILED (err u4002))
(define-constant ERR_INSUFFICIENT_REWARD (err u4003))
(define-constant ACTIVE "active")  ;; Active position status

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var oracle-contract principal tx-sender)  ;; Oracle contract for price feeds
(define-data-var risk-manager-contract principal tx-sender)  ;; Risk manager contract
(define-data-var position-manager-contract principal tx-sender)  ;; Position manager contract
(define-data-var min-liquidation-reward uint u100)  ;; 0.1%
(define-data-var max-liquidation-reward uint u1000) ;; 1%
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

;; ===== Core Functions =====
(define-public (liquidate-position
    (position-owner principal)
    (position-id uint)
    (max-slippage uint)
  )
  (let (
    (caller tx-sender)
    (current-block block-height)
    (position (unwrap! (contract-call? (var-get position-manager-contract) get-position-by-owner position-owner position-id) (err u4004)))
    (asset (get asset position))
    (price (unwrap! (contract-call? (var-get oracle-contract) get-price asset) (err u4005)))
    (liquidation-price (unwrap! (contract-call? (var-get risk-manager-contract) get-liquidation-price position price) (err u4006)))
  )
    ;; Verify position can be liquidated
    (asserts! (is-eq (get status position) ACTIVE) (err u4007))

    ;; Check if position is underwater
    (let (
      (margin-ratio (calculate-margin-ratio position price))
      (maintenance-margin (get maintenance-margin position))
    )
      (asserts! (< margin-ratio maintenance-margin) ERR_POSITION_SAFE)

      ;; Calculate liquidation reward (capped between min and max)
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
        (try! (as-contract (contract-call? asset transfer reward-amount (as-contract tx-sender) caller none)))

        ;; Transfer remaining collateral to insurance fund
        (try! (as-contract (contract-call? asset transfer remaining-collateral (as-contract tx-sender) (var-get insurance-fund) none)))

        ;; Close the position
        (try! (contract-call? (var-get position-manager-contract) force-close-position position-owner position-id price))

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

;; ===== Batch Liquidations =====
(define-public (liquidate-positions
    (positions (list 20 {owner: principal, id: uint}))
    (max-slippage uint)
  )
  (let (
    (results (map
      (lambda (position)
        (match (contract-call? .liquidation-engine liquidate-position
          (get position owner)
          (get position id)
          max-slippage
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
    (position (unwrap! (contract-call? (var-get position-manager-contract) get-position-by-owner position-owner position-id) (err u4004)))
    (price (unwrap! (contract-call? (var-get oracle-contract) get-price (get asset position)) (err u4005)))
    (margin-ratio (calculate-margin-ratio position price))
    (liquidation-price (unwrap! (contract-call? (var-get risk-manager-contract) get-liquidation-price position price) (err u4006)))
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

(define-public (set-position-manager-contract (position-manager principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set position-manager-contract position-manager)
    (ok true)
  )
)

(define-public (set-liquidation-rewards
    (min-reward uint)
    (max-reward uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (asserts! (and (<= min-reward max-reward) (<= max-reward u5000)) (err u4008))  ;; Max 5%
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
