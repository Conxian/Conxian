;; interest-rate-model.clar
;; Dynamic interest rate calculation system for lending protocols
;; Implements slope-based interest rate models with utilization-based adjustments

(use-trait sip10 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSR.sip-010-trait.sip-010-trait)

(define-constant ERR_UNAUTHORIZED (err u4001))
(define-constant ERR_INVALID_PARAMETER (err u4002))
(define-constant ERR_UTILIZATION_TOO_HIGH (err u4003))

(define-constant PRECISION u1000000000000000000) ;; 18 decimals
(define-constant SECONDS_PER_YEAR u31536000) ;; 365.25 * 24 * 3600
(define-constant BLOCKS_PER_YEAR u525600) ;; Approximate blocks per year (assuming 1 minute blocks)
(define-constant MAX_UTILIZATION u900000000000000000) ;; 90% maximum utilization

;; Admin
(define-data-var admin principal tx-sender)

;; Interest rate model parameters per asset
(define-map interest-rate-models
  { asset: principal }
  {
    base-rate-per-year: uint,       ;; Base interest rate (annual)
    multiplier-per-year: uint,      ;; Rate multiplier below kink
    jump-multiplier-per-year: uint, ;; Rate multiplier above kink  
    kink: uint                      ;; Utilization point where rate jumps
  })

;; Market state per asset
(define-map market-state
  { asset: principal }
  {
    total-cash: uint,           ;; Available cash for borrowing
    total-borrows: uint,        ;; Total borrowed amount
    total-supplies: uint,       ;; Total supplied amount
    borrow-index: uint,         ;; Accumulated borrow interest index
    supply-index: uint,         ;; Accumulated supply interest index
    last-update-block: uint     ;; Last block when indexes were updated
  })

;; Utilization rates (cached for efficiency)
(define-map utilization-rates
  { asset: principal }
  { utilization-rate: uint, last-calculated-block: uint })

;; === ADMIN FUNCTIONS ===
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)))

(define-public (set-interest-rate-model 
  (asset principal) 
  (base-rate uint) 
  (multiplier uint) 
  (jump-multiplier uint) 
  (kink uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (<= kink PRECISION) ERR_INVALID_PARAMETER)
    (asserts! (<= base-rate PRECISION) ERR_INVALID_PARAMETER)
    (asserts! (<= multiplier (* u10 PRECISION)) ERR_INVALID_PARAMETER)
    (asserts! (<= jump-multiplier (* u100 PRECISION)) ERR_INVALID_PARAMETER)
    
    (map-set interest-rate-models
      { asset: asset }
      {
        base-rate-per-year: base-rate,
        multiplier-per-year: multiplier,
        jump-multiplier-per-year: jump-multiplier,
        kink: kink
      })
    (ok true)))

;; === UTILIZATION CALCULATION ===
(define-read-only (get-utilization-rate (asset principal))
  (match (map-get? market-state { asset: asset })
    market
      (let ((total-borrows (get total-borrows market))
            (total-cash (get total-cash market)))
        (if (is-eq total-borrows u0)
          u0
          (let ((total-assets (+ total-borrows total-cash)))
            (if (is-eq total-assets u0)
              u0
              (/ (* total-borrows PRECISION) total-assets)))))
    u0))

;; === INTEREST RATE CALCULATIONS ===
;; Calculate borrow rate based on utilization
(define-read-only (get-borrow-rate (asset principal))
  (let ((utilization (get-utilization-rate asset)))
    (match (map-get? interest-rate-models { asset: asset })
      model
        (let ((base-rate (get base-rate-per-year model))
              (multiplier (get multiplier-per-year model))
              (jump-multiplier (get jump-multiplier-per-year model))
              (kink (get kink model)))
          (if (<= utilization kink)
            ;; Below kink: base + utilization * multiplier
            (+ base-rate (/ (* utilization multiplier) PRECISION))
            ;; Above kink: base + kink * multiplier + (utilization - kink) * jump_multiplier
            (+ base-rate
               (+ (/ (* kink multiplier) PRECISION)
                  (/ (* (- utilization kink) jump-multiplier) PRECISION)))))
      u0)))

;; Calculate supply rate (borrow rate * utilization * (1 - reserve factor))
(define-read-only (get-supply-rate (asset principal))
  (let ((utilization (get-utilization-rate asset))
        (borrow-rate (get-borrow-rate asset))
        (reserve-factor u100000000000000000)) ;; 10% reserve factor
    (/ (* (* borrow-rate utilization) (- PRECISION reserve-factor)) 
       (* PRECISION PRECISION))))

;; === INTEREST ACCRUAL ===
;; Calculate interest accrued since last update
(define-read-only (calculate-interest-accrued (asset principal) (blocks-elapsed uint))
  (let ((borrow-rate-per-block (/ (get-borrow-rate asset) BLOCKS_PER_YEAR)))
    (/ (* borrow-rate-per-block blocks-elapsed) PRECISION)))

;; Update interest indexes for an asset
(define-public (accrue-interest (asset principal))
  (match (map-get? market-state { asset: asset })
    market
      (let ((current-block block-height)
            (last-update-block (get last-update-block market))
            (blocks-elapsed (- current-block last-update-block)))
        (if (is-eq blocks-elapsed u0)
          (ok market) ;; No blocks elapsed, no update needed
          (let ((borrow-index (get borrow-index market))
                (total-borrows (get total-borrows market))
                (interest-accumulated (/ (* total-borrows (calculate-interest-accrued asset blocks-elapsed)) PRECISION))
                (new-total-borrows (+ total-borrows interest-accumulated))
                (new-borrow-index (+ borrow-index (/ (* borrow-index (calculate-interest-accrued asset blocks-elapsed)) PRECISION)))
                (supply-rate-per-block (/ (get-supply-rate asset) BLOCKS_PER_YEAR))
                (supply-interest (/ (* supply-rate-per-block blocks-elapsed) PRECISION))
                (new-supply-index (+ (get supply-index market) (/ (* (get supply-index market) supply-interest) PRECISION))))
            
            (map-set market-state
              { asset: asset }
              (merge market {
                total-borrows: new-total-borrows,
                borrow-index: new-borrow-index,
                supply-index: new-supply-index,
                last-update-block: current-block
              }))
            (ok (merge market {
              total-borrows: new-total-borrows,
              borrow-index: new-borrow-index,
              supply-index: new-supply-index,
              last-update-block: current-block
            })))))
    (err ERR_INVALID_PARAMETER)))

;; === MARKET STATE MANAGEMENT ===
;; Initialize market for a new asset
(define-public (initialize-market (asset principal) (initial-cash uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? market-state { asset: asset })) ERR_INVALID_PARAMETER)
    
    (map-set market-state
      { asset: asset }
      {
        total-cash: initial-cash,
        total-borrows: u0,
        total-supplies: initial-cash,
        borrow-index: PRECISION, ;; Start at 1.0
        supply-index: PRECISION, ;; Start at 1.0
        last-update-block: block-height
      })
    (ok true)))

;; Update market state after supply/borrow/repay/withdraw
(define-public (update-market-state 
  (asset principal) 
  (cash-change int) 
  (borrows-change int) 
  (supplies-change int))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED) ;; Should be called by lending system
    (match (map-get? market-state { asset: asset })
      market
        (let ((new-total-cash (if (>= cash-change 0)
                                (+ (get total-cash market) (to-uint cash-change))
                                (- (get total-cash market) (to-uint (- cash-change)))))
              (new-total-borrows (if (>= borrows-change 0)
                                   (+ (get total-borrows market) (to-uint borrows-change))
                                   (- (get total-borrows market) (to-uint (- borrows-change)))))
              (new-total-supplies (if (>= supplies-change 0)
                                    (+ (get total-supplies market) (to-uint supplies-change))
                                    (- (get total-supplies market) (to-uint (- supplies-change))))))
          (map-set market-state
            { asset: asset }
            (merge market {
              total-cash: new-total-cash,
              total-borrows: new-total-borrows,
              total-supplies: new-total-supplies
            }))
          (ok true))
      ERR_INVALID_PARAMETER)))

;; === VIEW FUNCTIONS ===
(define-read-only (get-market-info (asset principal))
  (match (map-get? market-state { asset: asset })
    market
      (ok (merge market {
        utilization-rate: (get-utilization-rate asset),
        borrow-rate: (get-borrow-rate asset),
        supply-rate: (get-supply-rate asset)
      }))
    ERR_INVALID_PARAMETER))

(define-read-only (get-interest-rate-model-params (asset principal))
  (map-get? interest-rate-models { asset: asset }))

;; Calculate borrowers current debt including accrued interest
(define-read-only (calculate-current-borrow-balance (asset principal) (principal-balance uint) (user-borrow-index uint))
  (match (map-get? market-state { asset: asset })
    market
      (let ((current-borrow-index (get borrow-index market)))
        (if (is-eq user-borrow-index u0)
          principal-balance
          (/ (* principal-balance current-borrow-index) user-borrow-index)))
    principal-balance))

;; Calculate suppliers current supply balance including accrued interest
(define-read-only (calculate-current-supply-balance (asset principal) (principal-balance uint) (user-supply-index uint))
  (match (map-get? market-state { asset: asset })
    market
      (let ((current-supply-index (get supply-index market)))
        (if (is-eq user-supply-index u0)
          principal-balance
          (/ (* principal-balance current-supply-index) user-supply-index)))
    principal-balance))

;; === APY CALCULATIONS ===
;; Convert annual rate to APY (compounded)
(define-read-only (get-supply-apy (asset principal))
  (let ((supply-rate (get-supply-rate asset)))
    ;; Simple approximation: APY ~ rate (for low rates)
    ;; More precise would use (1 + rate/n)^n - 1
    supply-rate))

(define-read-only (get-borrow-apy (asset principal))
  (let ((borrow-rate (get-borrow-rate asset)))
    ;; Simple approximation: APY ~ rate (for low rates)
    borrow-rate))

;; === LIQUIDATION SUPPORT ===
;; Check if position is liquidatable based on utilization
(define-read-only (is-liquidatable (asset principal) (collateral-value uint) (borrowed-value uint) (liquidation-threshold uint))
  (if (is-eq collateral-value u0)
    (> borrowed-value u0) ;; If no collateral but has debt, liquidatable
    (let ((collateral-ratio (/ (* borrowed-value PRECISION) collateral-value)))
      (> collateral-ratio liquidation-threshold))))





