;; risk-oracle.clar
;; Centralized risk parameter management and calculation

(use-trait risk-oracle .all-traits.risk-oracle-trait)
(use-trait oracle .all-traits.oracle-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u8000))
(define-constant ERR_INVALID_PARAM (err u8001))
(define-constant ERR_ORACLE_UNAVAILABLE (err u8002))

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var oracle-contract (optional principal) none)

;; Asset-specific risk parameters
(define-map asset-params {asset: principal} {
  volatility: uint,       ;; 30-day annualized volatility (in bps)
  correlation: uint,      ;; Correlation with base asset (in bps)
  max-leverage: uint,     ;; Maximum allowed leverage (in bps, e.g., 2000 for 20x)
  liquidation-threshold: uint  ;; Liquidation threshold (in bps, e.g., 8000 for 80%)
})

;; Global risk parameters
(define-data-var global-params {
  base-maintenance-margin: uint,  ;; Base maintenance margin (in bps)
  min-margin: uint,              ;; Minimum margin requirement (in bps)
  max-leverage: uint,            ;; System-wide max leverage (in bps)
  liquidation-penalty: uint,     ;; Penalty for liquidation (in bps)
  insurance-fund-fee: uint,      ;; Insurance fund contribution (in bps)
  oracle-freshness: uint         ;; Maximum allowed oracle staleness (in blocks)
}) {
  base-maintenance-margin: u500,   ;; 5%
  min-margin: u1000,              ;; 10%
  max-leverage: u2000,            ;; 20x
  liquidation-penalty: u500,      ;; 5%
  insurance-fund-fee: u10,        ;; 0.1%
  oracle-freshness: u25           ;; ~5 minutes
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
      (> (get base-maintenance-margin params) u0)
      (> (get min-margin params) (get base-maintenance-margin params))
      (> (get max-leverage params) u1000)  ;; At least 10x
      (< (get liquidation-penalty params) u1000)  ;; Max 10%
      (< (get insurance-fund-fee params) u50)     ;; Max 0.5%
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
      (<= (get volatility params) u10000)  ;; Max 100%
      (<= (get correlation params) u10000) ;; Max 100%
      (<= (get max-leverage params) (get max-leverage (var-get global-params)))
      (> (get liquidation-threshold params) u5000)  ;; At least 50%
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
    (volatility-factor (/ (get volatility params) u100))  ;; Convert bps to %
    (correlation-factor (/ (get correlation params) u10000))  ;; 0-1.0
    
    (risk-adjusted-margin 
      (/ 
        (* base-margin 
           (+ u10000 volatility-factor)  ;; Increase margin for volatile assets
           (+ u10000 (* u5000 (- u10000 correlation-factor)))) ;; Increase margin for low correlation
        u10000
      )
    )
    
    ;; Apply minimum margin requirement
    (final-margin (max 
      risk-adjusted-margin 
      (get min-margin global)
    ))
  )
    (ok {
      initial-margin: final-margin,
      maintenance-margin: (get base-maintenance-margin global),
      max-leverage: (min 
        (get max-leverage params) 
        (get max-leverage global)
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
    (is-long (> (get size position) 0))
    (size-abs (abs (get size position)))
    
    (liquidation-threshold (get liquidation-threshold params))
    (entry-price (get entry-price position))
    (collateral (get collateral position))
    
    (liquidation-price
      (if is-long
        ;; Long position: price decreases
        (let (
          (numerator (- collateral (/ (* size-abs entry-price liquidation-threshold) u10000)))
          (denominator size-abs)
        )
          (if (<= numerator 0) 
            u0  ;; Already liquidatable at any price
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
      (if (> (get size position) 0)  ;; Long position
        (/ (* (abs (get size position)) (- current-price (get entry-price position))) 
           (get entry-price position))
        (/ (* (abs (get size position)) (- (get entry-price position) current-price))
           (get entry-price position))
      )
    )
    
    (total-value (+ (get collateral position) unrealized-pnl))
    (notional-value (/ (* (abs (get size position)) current-price) (pow u10 u8)))
    
    (margin-ratio 
      (if (> notional-value 0) 
        (/ (* total-value u10000) notional-value)
        u0
      )
    )
  )
    (ok {
      margin-ratio: margin-ratio,
      liquidation-price: (get price liquidation),
      is-liquidatable: (or 
        (get is-liquidatable liquidation)
        (>= (- current-block (get last-updated position)) (get oracle-freshness (var-get global-params)))
      ),
      health-factor: (if (> margin-ratio 0) 
        (/ margin-ratio (get threshold liquidation))
        u0
      ),
      pnl: {
        unrealized: unrealized-pnl,
        roi: (if (> (get collateral position) 0)
          (/ (* unrealized-pnl u10000) (get collateral position))
          u0
        )
      },
      position: {
        size: (get size position),
        value: notional-value,
        collateral: (get collateral position),
        entry-price: (get entry-price position),
        current-price: current-price
      }
    })
  )
)
