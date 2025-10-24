;; ===== Traits =====
(use-trait sbtc-integration-trait .all-traits.sbtc-integration-trait)

;; sbtc-integration.clar
;; sBTC Integration Module for Conxian Protocol
;; Provides sBTC asset management, risk parameters, and oracle integration
;; =============================================================================
;; CONSTANTS AND ERROR CODES
;; =============================================================================

(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-PARAMS (err u1001))
(define-constant ERR-ASSET-NOT-FOUND (err u1002))
(define-constant ERR-ASSET-INACTIVE (err u1003))
(define-constant ERR-ORACLE-STALE (err u1004))
(define-constant ERR-PRICE-DEVIATION (err u1005))
(define-constant ERR-INSUFFICIENT-LIQUIDITY (err u1006))
(define-constant ERR-BORROW-CAP-EXCEEDED (err u1007))
(define-constant ERR-CIRCUIT-BREAKER-ACTIVE (err u1008))
(define-constant ERR-ALREADY-INITIALIZED (err u1009))
(define-constant ERR-NOT-INITIALIZED (err u1010))

;; Risk management constants
;; Basis points and rates are scaled by 1e6 (u1000000)
(define-constant ONE (u1))
(define-constant WAD (u1000000))

(define-constant DEFAULT-LTV u700000)             ;; 70% in 1e6 scale
(define-constant DEFAULT-LIQ-THRESHOLD u750000)   ;; 75%
(define-constant DEFAULT-LIQ-PENALTY u100000)     ;; 10%
(define-constant DEFAULT-RESERVE-FACTOR u200000)  ;; 20%
(define-constant FLASH-LOAN-FEE u120)             ;; 12 bps (0.12% of 1e6 = 1200, but using 1e4 scale); keep raw bps consumer-defined

;; Oracle parameters
(define-constant MAX-PRICE-DEVIATION u200000)     ;; 20% max price deviation (1e6 scale)
(define-constant ORACLE-STALE-THRESHOLD u17280)   ;; ~24 hours (Nakamoto blocks)
(define-constant MIN-CONFIRMATION-BLOCKS u6)      ;; Min confirmations for peg-in

;; =============================================================================
;; STORAGE
;; =============================================================================

(define-data-var contract-owner (optional principal) none)
(define-data-var sbtc-asset (optional principal) none)

(define-map asset-config
  { token: principal }
  {
    ltv: uint,                     ;; Loan-to-value ratio (1e6)
    liquidation-threshold: uint,   ;; Liquidation threshold (1e6)
    liquidation-penalty: uint,     ;; Liquidation penalty (1e6)
    reserve-factor: uint,          ;; Reserve factor (1e6)
    borrow-cap: (optional uint),   ;; Maximum borrow amount (token units)
    supply-cap: (optional uint),   ;; Maximum supply amount (token units)
    active: bool,
    supply-enabled: bool,
    borrow-enabled: bool,
    flash-loan-enabled: bool,
    bond-enabled: bool
  }
)

(define-map oracle-config
  { asset: principal }
  {
    primary-oracle: principal,
    secondary-oracle: (optional principal),
    last-price: uint,               ;; Price with 8 decimals
    last-update-block: uint,
    price-deviation-threshold: uint,
    circuit-breaker-active: bool
  }
)

(define-map interest-rate-config
  { asset: principal }
  {
    base-rate: uint,          ;; per block (1e6 scale)
    slope1: uint,             ;; per block (1e6 scale)
    slope2: uint,             ;; per block (1e6 scale)
    jump-multiplier: uint,    ;; per block (1e6 scale)
    kink1: uint,              ;; utilization (1e6)
    kink2: uint               ;; utilization (1e6)
  }
)

(define-map asset-metrics
  { asset: principal }
  {
    total-supply: uint,
    total-borrows: uint,
    supply-rate: uint,         ;; per block (1e6)
    borrow-rate: uint,         ;; per block (1e6)
    utilization-rate: uint,    ;; 1e6 scale
    last-accrual-block: uint,
    reserve-balance: uint
  }
)

(define-map risk-status
  { asset: principal }
  {
    risk-level: uint,          ;; 1-5
    volatility-index: uint,
    liquidity-score: uint,
    peg-stability: uint,
    last-risk-update: uint
  }
)

;; =============================================================================
;; INTERNAL HELPERS
;; =============================================================================

(define-read-only (require-owner)
  (match (var-get contract-owner)
    owner-principal (if (is-eq tx-sender owner-principal)
      (ok true)
      ERR-NOT-AUTHORIZED)
    ERR-NOT-INITIALIZED
  )
)

(define-read-only (get-interest-rate-config (asset principal))
  (map-get? interest-rate-config { asset: asset })
)

(define-read-only (checked-mul (a uint) (b uint))
  (ok (* a b))
)

(define-read-only (checked-div (a uint) (b uint))
  (if (is-eq b u0) (ok u0) (ok (/ a b)))
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-asset-config (token principal))
  (map-get? asset-config { token: token })
)

(define-read-only (get-oracle-config (asset principal))
  (map-get? oracle-config { asset: asset })
)

(define-read-only (get-asset-metrics (asset principal))
  (map-get? asset-metrics { asset: asset })
)

(define-read-only (get-risk-status (asset principal))
  (map-get? risk-status { asset: asset })
)

(define-read-only (get-asset-price (asset principal))
  (match (get-oracle-config asset)
    cfg (if (< (- block-height (get last-update-block cfg)) ORACLE-STALE-THRESHOLD)
          (ok (get last-price cfg))
          ERR-ORACLE-STALE)
    ERR-ASSET-NOT-FOUND
  )
)

(define-read-only (get-sbtc-price)
  (match (var-get sbtc-asset)
    some-asset (get-asset-price some-asset)
    ERR-NOT-INITIALIZED
  )
)

(define-read-only (calculate-collateral-value (token principal) (amount uint))
  (match (get-asset-config token)
    config (match (get-asset-price token)
      price (ok (/ (* (* amount price) (get ltv config)) WAD))
      error error
    )
    ERR-ASSET-NOT-FOUND
  )
)

(define-read-only (calculate-liquidation-threshold (token principal) (amount uint))
  (match (get-asset-config token)
    config (match (get-asset-price token)
      price (ok (/ (* (* amount price) (get liquidation-threshold config)) WAD))
      error error
    )
    ERR-ASSET-NOT-FOUND
  )
)

(define-read-only (get-utilization-rate (asset principal))
  (match (get-asset-metrics asset)
    metrics (let (
      (ts (get total-supply metrics))
      (tb (get total-borrows metrics))
    )
      (if (is-eq ts u0)
        (ok u0)
        (ok (/ (* tb WAD) ts))
      )
    )
    ERR-ASSET-NOT-FOUND
  )
)

(define-read-only (calculate-interest-rates (asset principal))
  (match (get-interest-rate-config asset)
    rate-cfg
      (match (get-utilization-rate asset)
        utilization
          (let (
            (base (get base-rate rate-cfg))
            (s1 (get slope1 rate-cfg))
            (s2 (get slope2 rate-cfg))
            (jump (get jump-multiplier rate-cfg))
            (k1 (get kink1 rate-cfg))
            (k2 (get kink2 rate-cfg))
          )
            (let (
              (borrow-rate
                (cond
                  ((<= utilization k1) (+ base (/ (* utilization s1) WAD)))
                  ((<= utilization k2) (+ base (+ (/ (* k1 s1) WAD) (/ (* (- utilization k1) s2) WAD))))
                  (else
                    (+ base
                       (+ (/ (* k1 s1) WAD)
                          (+ (/ (* (- k2 k1) s2) WAD)
                             (/ (* (- utilization k2) jump) WAD)
                          )
                       )
                    )
                  )
                )
              )
              (reserve-factor (default (get reserve-factor (get-asset-config asset)) u0))
            )
              (ok (tuple (borrow-rate borrow-rate) (reserve-factor reserve-factor)))
            )
          )
        )
        ERR-ASSET-NOT-FOUND
      )
    )
  )
)