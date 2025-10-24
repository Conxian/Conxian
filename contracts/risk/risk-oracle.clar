;; risk-oracle.clar
;; Centralized risk parameter management and calculation

(use-trait risk-oracle .all-traits.risk-oracle-trait)
(use-trait oracle .all-traits.oracle-trait)
(impl-trait risk-oracle)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u8000))
(define-constant ERR_INVALID_PARAM (err u8001))
(define-constant ERR_ORACLE_UNAVAILABLE (err u8002))

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var oracle-contract (optional principal) none)

;; Asset-specific risk parameters
(define-map asset-params {asset: principal} {
  volatility: uint,       \; 30-day annualized volatility (in bps)
  correlation: uint,      \; Correlation with base asset (in bps)
  max-leverage: uint,     \; Maximum allowed leverage (in bps, e.g., 2000 for 20x)
  liquidation-threshold: uint  \; Liquidation threshold (in bps, e.g., 8000 for 80%)
})

;; Global risk parameters
(define-data-var global-params {
  base-maintenance-margin: uint,  \; Base maintenance margin (in bps)
  min-margin: uint,              \; Minimum margin requirement (in bps)
  max-leverage: uint,            \; System-wide max leverage (in bps)
  liquidation-penalty: uint,     \; Penalty for liquidation (in bps)
  insurance-fund-fee: uint,      \; Insurance fund contribution (in bps)
  oracle-freshness: uint         \; Maximum allowed oracle staleness (in blocks)
}) {
  base-maintenance-margin: u500,   \; 5%
  min-margin: u1000,              \; 10%
  max-leverage: u2000,            \; 20x
  liquidation-penalty: u500,      \; 5%
  insurance-fund-fee: u10,        \; 0.1%
  oracle-freshness: u25           \; ~5 minutes
}

;; ===== Core Functions =====
(define-public (set-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set oracle-contract (some oracle))
    (ok true)
  )
)

(define-public (set-global-params (params {
  base-maintenance-margin: uint,
  min-margin: uint,
  max-leverage: uint,
  liquidation-penalty: uint,
  insurance-fund-fee: uint,
  oracle-freshness: uint
}))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (asserts! (and 
      (> (get params 'base-maintenance-margin) u0)
      (> (get params 'min-margin) (get params 'base-maintenance-margin))
      (> (get params 'max-leverage) u1000)  \; At least 10x
      (< (get params 'liquidation-penalty) u1000)  \; Max 10%
      (< (get params 'insurance-fund-fee) u50)     \; Max 0.5%
    ) ERR_INVALID_PARAM)
    
    (var-set global-params params)
    (ok true)
  )
)

(define-public (set-asset-params 
    (asset principal)
    (params {
      volatility: uint,
      correlation: uint,
      max-leverage: uint,
      liquidation-threshold: uint
    })
  )
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (asserts! (and 
      (<= (get params 'volatility) u10000)  \; Max 100%
      (<= (get params 'correlation) u10000) \; Max 100%
      (<= (get params 'max-leverage) (get (var-get global-params) 'max-leverage))
      (> (get params 'liquidation-threshold) u5000)  \; At least 50%
    ) ERR_INVALID_PARAM)
    
    (map-set asset-params {asset: asset} params)
    (ok true)
  )
)

;; ===== Risk Calculations =====
(define-read-only (calculate-margin-requirements 
    (asset principal)
    (notional-value uint)
    (leverage uint)
  )
  (let (
    (params (unwrap! (map-get? asset-params {asset: asset}) (err ERR_INVALID_PARAM)))
    (global (var-get global-params))
    (base-margin (/ u10000 leverage))
    
    ;; Adjust margin based on volatility and correlation
    (volatility-factor (/ (get params 'volatility) u100))  \; Convert bps to %
    (correlation-factor (/ (get params 'correlation) u10000))  \; 0-1.0
    
    (risk-adjusted-margin 
      (/ 
        (* base-margin 
           (+ u10000 volatility-factor)  \; Increase margin for volatile assets
           (+ u10000 (* u5000 (- u10000 correlation-factor)))) \; Increase margin for low correlation
        u10000
      )
    )
    
    ;; Apply minimum margin requirement
    (final-margin (max 
      risk-adjusted-margin 
      (get global 'min-margin)
    ))
  )
    (ok {
      initial-margin: final-margin,
      maintenance-margin: (get global 'base-maintenance-margin),
      max-leverage: (min 
        (get params 'max-leverage) 
        (get global 'max-leverage)
      )
    })
  )
)

(define-read-only (get-liquidation-price
    (position {
      size: int,
      entry-price: uint,
      collateral: uint
    })
    (asset principal)
  )
  (let (
    (params (unwrap! (map-get? asset-params {asset: asset}) (err ERR_INVALID_PARAM)))
    (global (var-get global-params))
    (is-long (> (get position 'size) 0))
    (size-abs (abs (get position 'size)))
    
    (liquidation-threshold (get params 'liquidation-threshold))
    (entry-price (get position 'entry-price))
    (collateral (get position 'collateral))
    
    (liquidation-price
      (if is-long
        ;; Long position: price decreases
        (let (
          (numerator (- collateral (/ (* size-abs entry-price liquidation-threshold) u10000)))
          (denominator size-abs)
        )
          (if (<= numerator 0) 
            u0  \; Already liquidatable at any price
            (/ numerator denominator)
          )
        )
        ;; Short position: price increases
        (let (
          (numerator (+ collateral (/ (* size-abs entry-price liquidation-threshold) u10000)))
          (denominator size-abs)
        )
          (/ numerator denominator)
        )
      )
    )
  )
    (ok {
      price: liquidation-price,
      threshold: liquidation-threshold,
      is-liquidatable: (or 
        (and is-long (<= liquidation-price entry-price))
        (and (not is-long) (>= liquidation-price entry-price))
      )
    })
  )
)

(define-read-only (check-position-health
    (position {
      size: int,
      entry-price: uint,
      collateral: uint,
      last-updated: uint
    })
    (asset principal)
  )
  (let (
    (oracle (unwrap! (var-get oracle-contract) ERR_ORACLE_UNAVAILABLE))
    (current-price (unwrap! (contract-call? oracle get-price asset) (err u0)))
    (liquidation (unwrap! (get-liquidation-price position asset) (err u0)))
    (current-block (block-height))
    
    ;; Calculate PnL
    (unrealized-pnl 
      (if (> (get position 'size) 0)  \; Long position
        (/ (* (abs (get position 'size)) (- current-price (get position 'entry-price))) 
           (get position 'entry-price))
        (/ (* (abs (get position 'size)) (- (get position 'entry-price) current-price))
           (get position 'entry-price))
      )
    )
    
    (total-value (+ (get position 'collateral) unrealized-pnl))
    (notional-value (/ (* (abs (get position 'size)) current-price) (pow u10 u8)))
    
    (margin-ratio 
      (if (> notional-value 0) 
        (/ (* total-value u10000) notional-value)
        u0
      )
    )
  )
    (ok {
      margin-ratio: margin-ratio,
      liquidation-price: (get liquidation 'price),
      is-liquidatable: (or 
        (get liquidation 'is-liquidatable)
        (>= (- current-block (get position 'last-updated)) (get (var-get global-params) 'oracle-freshness))
      ),
      health-factor: (if (> margin-ratio 0) 
        (/ margin-ratio (get liquidation 'threshold))
        u0
      ),
      pnl: {
        unrealized: unrealized-pnl,
        roi: (if (> (get position 'collateral) 0)
          (/ (* unrealized-pnl u10000) (get position 'collateral))
          u0
        )
      },
      position: {
        size: (get position 'size),
        value: notional-value,
        collateral: (get position 'collateral),
        entry-price: (get position 'entry-price),
        current-price: current-price
      }
    })
  )
)
