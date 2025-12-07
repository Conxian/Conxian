;; interest-rate-model.clar

;; Dynamic interest rate calculation system for lending protocols
;; Refactored for correctness, proper access control, and revenue tracking.

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u4001))
(define-constant ERR_INVALID_PARAMETER (err u4002))
(define-constant ERR_LENDING_SYSTEM_NOT_SET (err u4004))
(define-constant PRECISION u1000000000000000000) ;; 1e18
(define-constant BLOCKS_PER_YEAR u525600) ;; Approximate blocks per year (assu
(define-constant RESERVE_FACTOR u100000000000000000) ;; 10% reserve factor

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var lending-system-contract (optional principal) none)

;; ===== Data Maps =====
;; Interest rate model parameters per asset
(define-map interest-rate-models 
  { asset: principal } 
  { 
    base-rate-per-year: uint, 
    multiplier-per-year: uint, 
    jump-multiplier-per-year: uint, 
    kink: uint 
  }
)

;; Market state per asset
(define-map market-state 
  { asset: principal } 
  { 
    total-cash: uint, 
    total-borrows: uint, 
    total-supplies: uint, 
    total-reserves: uint, ;; Added: Track accumulated reserves
    borrow-index: uint, 
    supply-index: uint, 
    last-update-block: uint 
  }
)

;; ===== Private Functions =====
;; Ownership and caller checks return a standard response type so they can be
;; composed with try! from public entrypoints.
(define-private (check-is-owner)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok true)
  )
)

(define-private (check-is-lending-system)
  (begin
    (asserts! (is-eq tx-sender (unwrap! (var-get lending-system-contract) ERR_LENDING_SYSTEM_NOT_SET)) ERR_UNAUTHORIZED)
    (ok true)
  )
)

;; ===== Admin Functions =====
(define-public (transfer-ownership (new-owner principal))
  (begin
    (try! (check-is-owner))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-lending-system-contract (lending-system principal))
  (begin
    (try! (check-is-owner))
    (var-set lending-system-contract (some lending-system))
    (ok true)
  )
)

(define-public (set-interest-rate-model (asset principal) (base-rate uint) (multiplier uint) (jump-multiplier uint) (kink uint))
  (begin
    (try! (check-is-owner))
    (asserts! (<= kink PRECISION) ERR_INVALID_PARAMETER)
    (map-set interest-rate-models 
      { asset: asset } 
      { 
        base-rate-per-year: base-rate, 
        multiplier-per-year: multiplier, 
        jump-multiplier-per-year: jump-multiplier, 
        kink: kink 
      }
    )
    (ok true)
  )
)

;; ===== Interest Rate Calculations =====
(define-read-only (get-utilization-rate (asset principal))
  (match (map-get? market-state { asset: asset })
    market
      (let (
        (total-borrows (get total-borrows market))
        (total-cash (get total-cash market))
      )
        (if (is-eq (+ total-borrows total-cash) u0)
          u0
          (/ (* total-borrows PRECISION) (+ total-borrows total-cash))
        )
      )
    u0
  )
)

(define-read-only (get-borrow-rate-per-year (asset principal))
  (let ((utilization (get-utilization-rate asset)))
    (match (map-get? interest-rate-models { asset: asset })
      model
        (let (
          (base-rate (get base-rate-per-year model))
          (multiplier (get multiplier-per-year model))
          (jump-multiplier (get jump-multiplier-per-year model))
          (kink (get kink model))
        )
          (if (<= utilization kink)
            (+ base-rate (/ (* utilization multiplier) PRECISION))
            (+ base-rate 
               (/ (* kink multiplier) PRECISION) 
               (/ (* (- utilization kink) jump-multiplier) PRECISION))
          )
        )
      u0
    )
  )
)

(define-read-only (get-supply-rate-per-year (asset principal))
  (let (
    (utilization (get-utilization-rate asset))
    (borrow-rate (get-borrow-rate-per-year asset))
  )
    (/ (* borrow-rate utilization (- PRECISION RESERVE_FACTOR)) (* PRECISION PRECISION))
  )
)

;; ===== Interest Accrual =====
(define-public (accrue-interest (asset principal))
  (match (map-get? market-state { asset: asset })
    market
      (let ((blocks-elapsed (- block-height (get last-update-block market))))
        (if (is-eq blocks-elapsed u0)
          (ok market)
          (let (
            (borrow-rate-per-block (/ (get-borrow-rate-per-year asset) BLOCKS_PER_YEAR))
            ;; Simple Interest = TotalBorrows * Rate * Time
            (simple-interest-factor (* borrow-rate-per-block blocks-elapsed))
            (interest-accumulated (/ (* (get total-borrows market) simple-interest-factor) PRECISION))
            ;; Reserve Share = Interest * ReserveFactor
            (reserve-accrued (/ (* interest-accumulated RESERVE_FACTOR) PRECISION))
            ;; Supply Share = Interest - Reserve
            (supply-distributed (- interest-accumulated reserve-accrued))
          )
            (let (
              (new-borrow-index (+ (get borrow-index market) (/ (* (get borrow-index market) simple-interest-factor) PRECISION)))
              ;; Supply Index grows based on Distributed Interest relative to Total Supplies
              ;; Roughly: new_index = old_index + (supply_distributed * old_index / total_supplies)
              ;; But simplifying: supply_rate is calculated from borrow_rate * utilization * (1-reserve_factor)
              ;; So we can just use the rate.
              (supply-rate-per-block (/ (get-supply-rate-per-year asset) BLOCKS_PER_YEAR))
              (supply-interest-factor (* supply-rate-per-block blocks-elapsed))
              (new-supply-index (+ (get supply-index market) (/ (* (get supply-index market) supply-interest-factor) PRECISION)))
              
              (new-total-borrows (+ (get total-borrows market) interest-accumulated))
              (new-total-reserves (+ (get total-reserves market) reserve-accrued))
              ;; Total supplies (liability) grows by distributed interest
              (new-total-supplies (+ (get total-supplies market) supply-distributed))
            )
              (let (
                (updated-market
                  (merge market {
                    total-borrows: new-total-borrows,
                    total-reserves: new-total-reserves,
                    total-supplies: new-total-supplies,
                    borrow-index: new-borrow-index,
                    supply-index: new-supply-index,
                    last-update-block: block-height
                  })
                )
              )
                (map-set market-state { asset: asset } updated-market)
                (ok updated-market)
              )
            )
          )
        )
      )
    ERR_INVALID_PARAMETER
  )
)

;; ===== Market State Management =====
(define-public (initialize-market (asset principal))
  (begin
    (try! (check-is-lending-system))
    (asserts! (is-none (map-get? market-state { asset: asset })) ERR_INVALID_PARAMETER)
    (map-set market-state 
      { asset: asset } 
      { 
        total-cash: u0, 
        total-borrows: u0, 
        total-supplies: u0, 
        total-reserves: u0,
        borrow-index: PRECISION, 
        supply-index: PRECISION, 
        last-update-block: block-height 
      }
    )
    (ok true)
  )
)

(define-public (update-market-state (asset principal) (cash-change int) (borrows-change int))
  (begin
    (try! (check-is-lending-system))
    (match (map-get? market-state { asset: asset })
      market
        (let (
          (delta-cash (if (>= cash-change 0)
            (to-uint cash-change)
            (to-uint (- 0 cash-change))))
          (delta-borrows (if (>= borrows-change 0)
            (to-uint borrows-change)
            (to-uint (- 0 borrows-change))))
          (new-total-cash (if (>= cash-change 0)
            (+ (get total-cash market) delta-cash)
            (- (get total-cash market) delta-cash)))
          (new-total-borrows (if (>= borrows-change 0)
            (+ (get total-borrows market) delta-borrows)
            (- (get total-borrows market) delta-borrows)))
        )
          (let ((new-total-supplies (+ new-total-cash new-total-borrows)))
            ;; Note: total-supplies here is just balancing the equation Asset = Liability + Equity?
;; In our simplified model, total-supplies = total-cash + total-borrows (Assets)
;; But strictly, Liability = Assets - Reserves.
;; The 'accrue-interest' logic updates total-supplies based on interest.
;; Here we are adding/removing principal.
;; If a user supplies cash, total-cash goes up, total-supplies goes up.
;; If a user borrows, total-cash goes down, total-borrows goes up. total-supplies stays same?
;; Let's check the logic:
;; Supply: cash +100, borrows 0. new-cash +100. new-supplies +100. Correct.
;; Borrow: cash -50, borrows +50. new-cash -50, new-borrows +50.
            
            (map-set market-state 
              { asset: asset }
              (merge market {
                total-cash: new-total-cash,
                total-borrows: new-total-borrows,
                total-supplies: (- (+ new-total-cash new-total-borrows) (get total-reserves market))
              })
            )
            (ok true)
          )
        )
      ERR_INVALID_PARAMETER
    )
  )
)

(define-public (reduce-reserves (asset principal) (amount uint))
  (begin
    (try! (check-is-lending-system))
    (match (map-get? market-state { asset: asset })
      market
        (let (
            (current-reserves (get total-reserves market))
            (new-reserves (- current-reserves amount))
        )
            (asserts! (<= amount current-reserves) ERR_INVALID_PARAMETER)
            (map-set market-state 
                { asset: asset }
                (merge market {
                    total-reserves: new-reserves,
                    total-cash: (- (get total-cash market) amount) ;; Reserves are taken from cash
                })
            )
            (ok true)
        )
      ERR_INVALID_PARAMETER
    )
  )
)

;; ===== View Functions =====
(define-read-only (get-market-info (asset principal))
  (map-get? market-state { asset: asset })
)
