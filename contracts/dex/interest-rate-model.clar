;; interest-rate-model.clar
;; Dynamic interest rate calculation system for lending protocols
;; Refactored for correctness and proper access control.

(use-trait ft-trait .traits.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u4001))
(define-constant ERR_INVALID_PARAMETER (err u4002))
(define-constant ERR_LENDING_SYSTEM_NOT_SET (err u4004))

(define-constant PRECISION u1000000000000000000) ;; 1e18
(define-constant BLOCKS_PER_YEAR u525600) ;; Approximate blocks per year (assuming 1 minute blocks)

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var lending-system-contract (optional principal) none)

;; Interest rate model parameters per asset
(define-map interest-rate-models { asset: principal } { base-rate-per-year: uint, multiplier-per-year: uint, jump-multiplier-per-year: uint, kink: uint })

;; Market state per asset
(define-map market-state { asset: principal } { total-cash: uint, total-borrows: uint, total-supplies: uint, borrow-index: uint, supply-index: uint, last-update-block: uint })

;; --- Private Functions ---
(define-private (check-is-owner) (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)))
(define-private (check-is-lending-system) (ok (asserts! (is-eq tx-sender (unwrap! (var-get lending-system-contract) ERR_LENDING_SYSTEM_NOT_SET)) ERR_UNAUTHORIZED)))

;; --- Admin Functions ---
(define-public (transfer-ownership (new-owner principal))
  (try! (check-is-owner))
  (var-set contract-owner new-owner)
  (ok true))

(define-public (set-lending-system-contract (lending-system principal))
  (try! (check-is-owner))
  (var-set lending-system-contract (some lending-system))
  (ok true))

(define-public (set-interest-rate-model (asset principal) (base-rate uint) (multiplier uint) (jump-multiplier uint) (kink uint))
  (try! (check-is-owner))
  (asserts! (<= kink PRECISION) ERR_INVALID_PARAMETER)
  (map-set interest-rate-models { asset: asset } { base-rate-per-year: base-rate, multiplier-per-year: multiplier, jump-multiplier-per-year: jump-multiplier, kink: kink })
  (ok true))

;; --- Interest Rate Calculations ---
(define-read-only (get-utilization-rate (asset principal))
  (match (map-get? market-state { asset: asset })
    market
      (let ((total-borrows (get total-borrows market))
            (total-cash (get total-cash market)))
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
      (let ((base-rate (get base-rate-per-year model))
            (multiplier (get multiplier-per-year model))
            (jump-multiplier (get jump-multiplier-per-year model))
            (kink (get kink model)))
        (if (<= utilization kink)
          (+ base-rate (/ (* utilization multiplier) PRECISION))
          (+ base-rate (/ (* kink multiplier) PRECISION) (/ (* (- utilization kink) jump-multiplier) PRECISION))
        )
      )
      u0
    )
  )
)

(define-read-only (get-supply-rate-per-year (asset principal))
  (let ((utilization (get-utilization-rate asset))
        (borrow-rate (get-borrow-rate-per-year asset))
        (reserve-factor u100000000000000000)) ;; 10% reserve factor
    (/ (* borrow-rate utilization (- PRECISION reserve-factor)) (* PRECISION PRECISION))
  )
)

;; --- Interest Accrual ---
(define-public (accrue-interest (asset principal))
  (match (map-get? market-state { asset: asset })
    market
    (let ((blocks-elapsed (- block-height (get last-update-block market))))
      (if (is-eq blocks-elapsed u0)
        (ok market)
        (let ((borrow-rate-per-block (/ (get-borrow-rate-per-year asset) BLOCKS_PER_YEAR))
              (supply-rate-per-block (/ (get-supply-rate-per-year asset) BLOCKS_PER_YEAR)))
          (let ((borrow-interest-factor (* borrow-rate-per-block blocks-elapsed))
                (supply-interest-factor (* supply-rate-per-block blocks-elapsed)))
            (let ((new-borrow-index (+ (get borrow-index market) (/ (* (get borrow-index market) borrow-interest-factor) PRECISION)))
                  (new-supply-index (+ (get supply-index market) (/ (* (get supply-index market) supply-interest-factor) PRECISION)))
                  (new-total-borrows (/ (* (get total-borrows market) new-borrow-index) (get borrow-index market))))
              (let ((updated-market
                    (merge market {
                      total-borrows: new-total-borrows,
                      borrow-index: new-borrow-index,
                      supply-index: new-supply-index,
                      last-update-block: block-height
                    })))
                (map-set market-state { asset: asset } updated-market)
                (ok updated-market)
              )
            )
          )
        )
      )
    )
    (err ERR_INVALID_PARAMETER)
  )
)

;; --- Market State Management ---
(define-public (initialize-market (asset principal))
  (try! (check-is-lending-system))
  (asserts! (is-none (map-get? market-state { asset: asset })) ERR_INVALID_PARAMETER)
  (map-set market-state { asset: asset } { total-cash: u0, total-borrows: u0, total-supplies: u0, borrow-index: PRECISION, supply-index: PRECISION, last-update-block: block-height })
  (ok true))

(define-public (update-market-state (asset principal) (cash-change int) (borrows-change int))
  (try! (check-is-lending-system))
  (match (map-get? market-state { asset: asset })
    market
    (let ((new-total-cash (if (>= cash-change 0) (+ (get total-cash market) (to-uint cash-change)) (- (get total-cash market) (to-uint (- cash-change)))))
          (new-total-borrows (if (>= borrows-change 0) (+ (get total-borrows market) (to-uint borrows-change)) (- (get total-borrows market) (to-uint (- borrows-change))))))
      (let ((new-total-supplies (+ new-total-cash new-total-borrows)))
        (map-set market-state { asset: asset } (merge market { total-cash: new-total-cash, total-borrows: new-total-borrows, total-supplies: new-total-supplies }))
        (ok true)
      )
    )
    (err ERR_INVALID_PARAMETER)
  )
)

;; --- View Functions ---
(define-read-only (get-market-info (asset principal))
  (map-get? market-state { asset: asset }))
