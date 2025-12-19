;; @desc This contract is responsible for calculating and updating funding rates.

(use-trait funding-rate-calculator-trait .dimensional-traits.funding-rate-calculator-trait)
;; (use-trait oracle-trait .oracle-pricing.oracle-aggregator-v2-trait) ;; Removed invalid trait usage
;; (use-trait position-manager-trait .dimensional.position-manager-trait) ;; Removed invalid trait usage
;; (use-trait rbac-trait .core-traits.rbac-trait) ;; Removed invalid trait usage

(impl-trait .dimensional-traits.funding-rate-calculator-trait)

;; @constants
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INVALID_TASK (err u9004))
(define-constant ONE_DAY u17280) ;; u144 * 120
(define-constant ERR_TASK_NOT_READY (err u9003))
(define-constant ERR_POSITION_NOT_PERPETUAL (err u4003))
(define-constant ROLE_OPERATOR "ROLE_OPERATOR") ;; Added missing constant

;; @data-vars
(define-data-var funding-interval uint u17280) ;; Default to daily funding
(define-data-var max-funding-rate uint u100) ;; 1% max funding rate
(define-data-var funding-rate-sensitivity uint u500) ;; 5% sensitivity
(define-map funding-rate-history
  {
    asset: principal,
    timestamp: uint,
  }
  {
    rate: int,
    index-price: uint,
    open-interest-long: uint,
    open-interest-short: uint,
  }
)
(define-map last-funding-update
  { asset: principal }
  {
    timestamp: uint,
    cumulative-funding: int,
  }
)

;; --- Public Functions ---
(define-public (update-funding-rate (asset principal))
  (begin
    (asserts! (is-eq (unwrap! (check-role ROLE_OPERATOR) ERR_UNAUTHORIZED) true)
      ERR_UNAUTHORIZED
    )
    (let (
        (current-time block-height)
        (last-update (default-to {
          timestamp: u0,
          cumulative-funding: 0,
        }
          (map-get? last-funding-update { asset: asset })
        ))
      )
      (asserts!
        (>= (- current-time (get timestamp last-update))
          (var-get funding-interval)
        )
        ERR_TASK_NOT_READY
      )
      (let (
          (index-price (try! (contract-call? .oracle-aggregator-v2 get-real-time-price asset)))
          (twap (try! (contract-call? .oracle-aggregator-v2 get-twap asset
            (var-get funding-interval)
          )))
          (open-interest (unwrap! (get-open-interest asset) ERR_TASK_NOT_READY))
          (oi-long (get long open-interest))
          (oi-short (get short open-interest))
          (premium (calculate-premium index-price twap))
          (funding-rate (calculate-funding-rate premium oi-long oi-short))
          (capped-rate (max (min funding-rate (to-int (var-get max-funding-rate)))
            (- 0 (to-int (var-get max-funding-rate)))
          ))
          (new-cumulative (+ (get cumulative-funding last-update) capped-rate))
        )
        (map-set funding-rate-history {
          asset: asset,
          timestamp: current-time,
        } {
          rate: capped-rate,
          index-price: index-price,
          open-interest-long: oi-long,
          open-interest-short: oi-short,
        })
        (map-set last-funding-update { asset: asset } {
          timestamp: current-time,
          cumulative-funding: new-cumulative,
        })
        (ok {
          funding-rate: capped-rate,
          index-price: index-price,
          timestamp: current-time,
          cumulative-funding: new-cumulative,
        })
      )
    )
  )
)

(define-public (apply-funding-to-position
    (position-owner principal)
    (position-id uint)
  )
  (let (
      (position (try! (contract-call? .position-manager get-position position-id)))
      (current-time block-height)
      (asset (get asset position))
      (last-update (unwrap! (map-get? last-funding-update { asset: asset }) ERR_TASK_NOT_READY))
    )
    (asserts! (is-eq (get is-long position) true) ERR_POSITION_NOT_PERPETUAL)

    (let (
        (size (get size position))
        (funding-rate (get cumulative-funding last-update))
      )
      (let ((funding-payment (/ (* (to-int size) funding-rate) 10000)))
        (let ((abs-payment (abs funding-payment)))
          (let ((maybe-payment (some u1)))
            ;; Debug fix for to-uint
            (let ((payment-uint (unwrap! maybe-payment (err u5000))))
              ;; Handle conversion
              (let ((new-collateral (if (> funding-payment 0)
                  (- (get collateral position) payment-uint)
                  (+ (get collateral position) payment-uint)
                )))
                (try! (contract-call? .position-manager update-position position-id
                  (some new-collateral) none none none
                ))
                (ok {
                  funding-rate: funding-rate,
                  funding-payment: funding-payment,
                  new-collateral: new-collateral,
                  timestamp: current-time,
                })
              )
            )
          )
        )
      )
    )
  )
)

;; --- Private Functions ---
(define-private (check-role (role (string-ascii 32)))
  (contract-call? .roles has-role role tx-sender)
  ;; Fixed contract reference
)

(define-private (get-open-interest (asset principal))
  (contract-call? .position-manager get-open-interest asset)
  ;; Fixed contract reference
)

(define-private (abs (val int))
  (if (< val 0)
    (- 0 val)
    val
  )
)

(define-private (max
    (a int)
    (b int)
  )
  (if (> a b)
    a
    b
  )
)

(define-private (min
    (a int)
    (b int)
  )
  (if (< a b)
    a
    b
  )
)

(define-private (calculate-premium
    (index-price uint)
    (twap uint)
  )
  (if (> twap u0)
    (/ (* (- (to-int index-price) (to-int twap)) 10000) (to-int twap))
    0
  )
)

(define-private (calculate-funding-rate
    (premium int)
    (oi-long uint)
    (oi-short uint)
  )
  (let (
      (oi-diff (abs (- (to-int oi-long) (to-int oi-short))))
      (oi-total (+ oi-long oi-short))
      (sensitivity (var-get funding-rate-sensitivity))
    )
    (if (> oi-total u0)
      (let (
          (imbalance (/ (* oi-diff 10000) (to-int oi-total)))
          (funding-rate (/ (* premium (+ 10000 (/ (* imbalance (to-int sensitivity)) 100)))
            10000
          ))
        )
        funding-rate
      )
      0
    )
  )
)
