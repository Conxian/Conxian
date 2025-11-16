;; @desc This contract is responsible for calculating and updating funding rates.

(use-trait funding-rate-calculator-trait .funding-rate-calculator-trait.funding-rate-calculator-trait)
(use-trait oracle-trait .oracle-aggregator-v2-trait.oracle-aggregator-v2-trait)
(use-trait position-manager-trait .position-manager-trait.position-manager-trait)
(use-trait rbac-trait .base-traits.rbac-trait)

(impl-trait .funding-rate-calculator-trait.funding-rate-calculator-trait)

;; @constants
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INVALID_TASK (err u9004))
(define-constant ERR_TASK_NOT_READY (err u9003))
(define-constant ERR_POSITION_NOT_PERPETUAL (err u4003))

;; @data-vars
(define-data-var funding-interval uint u144) ;; Default to daily funding
(define-data-var max-funding-rate uint u100) ;; 1% max funding rate
(define-data-var funding-rate-sensitivity uint u500) ;; 5% sensitivity
(define-map funding-rate-history {asset: principal, timestamp: uint} {rate: int, index-price: uint, open-interest-long: uint, open-interest-short: uint})
(define-map last-funding-update {asset: principal} {timestamp: uint, cumulative-funding: int})

;; --- Public Functions ---
(define-public (update-funding-rate (asset principal))
  (begin
    (try! (check-role ROLE_OPERATOR))

    (let (
      (current-time block-height)
      (last-update (default-to {timestamp: u0, cumulative-funding: 0} (map-get? last-funding-update {asset: asset})))
    )
      (asserts! (>= (- current-time (get timestamp last-update)) (var-get funding-interval)) ERR_TASK_NOT_READY)

      (let (
        (index-price (try! (contract-call? .oracle-aggregator-v2-trait get-real-time-price asset)))
        (twap (try! (contract-call? .oracle-aggregator-v2-trait get-twap-price asset (var-get funding-interval))))
        (open-interest (try! (get-open-interest asset)))
        (oi-long (get long open-interest))
        (oi-short (get short open-interest))
        (premium (calculate-premium index-price twap))
        (funding-rate (calculate-funding-rate premium oi-long oi-short))
        (capped-rate (max (min funding-rate (to-int (var-get max-funding-rate))) (- 0 (to-int (var-get max-funding-rate)))))
        (new-cumulative (+ (get cumulative-funding last-update) capped-rate))
      )
        (map-set funding-rate-history {asset: asset, timestamp: current-time} {rate: capped-rate, index-price: index-price, open-interest-long: oi-long, open-interest-short: oi-short})
        (map-set last-funding-update {asset: asset} {timestamp: current-time, cumulative-funding: new-cumulative})

        (ok {funding-rate: capped-rate, index-price: index-price, timestamp: current-time, cumulative-funding: new-cumulative})
      )
    )
  )
)

(define-public (apply-funding-to-position (position-owner principal) (position-id uint))
  (let (
    (position (try! (contract-call? .position-manager-trait get-position position-id)))
    (current-time block-height)
    (asset (get asset position))
    (last-update (unwrap! (map-get? last-funding-update {asset: asset}) (err ERR_TASK_NOT_READY)))
  )
    (asserts! (is-eq (get is-long position) true) ERR_POSITION_NOT_PERPETUAL)

    (let* (
      (size (get size position))
      (funding-rate (get cumulative-funding last-update))
      (funding-payment (/ (* (to-int size) funding-rate) u10000))
      (new-collateral (- (get collateral position) (to-uint funding-payment)))
    )
      (try! (contract-call? .position-manager-trait update-position position-id (some new-collateral) none none none))
      (ok {funding-rate: funding-rate, funding-payment: funding-payment, new-collateral: new-collateral, timestamp: current-time})
    )
  )
)

;; --- Private Functions ---
(define-private (check-role (role (string-ascii 32)))
  (contract-call? .rbac-trait has-role tx-sender role)
)

(define-private (get-open-interest (asset principal))
  (contract-call? .position-manager-trait get-open-interest asset)
)

(define-private (calculate-premium (index-price uint) (twap uint))
  (if (> twap u0)
    (/ (* (- (to-int index-price) (to-int twap)) u10000) (to-int twap))
    0
  )
)

(define-private (calculate-funding-rate (premium int) (oi-long uint) (oi-short uint))
  (let (
    (oi-diff (abs (- (to-int oi-long) (to-int oi-short))))
    (oi-total (+ oi-long oi-short))
    (sensitivity (var-get funding-rate-sensitivity))
  )
    (if (> oi-total u0)
      (let (
        (imbalance (/ (* oi-diff u10000) (to-int oi-total)))
        (funding-rate (/ (* premium (+ u10000 (/ (* imbalance (to-int sensitivity)) u100))) u10000))
      )
        funding-rate
      )
      0
    )
  )
)

(define-private (abs (n int))
  (if (< n 0) (- 0 n) n)
)
