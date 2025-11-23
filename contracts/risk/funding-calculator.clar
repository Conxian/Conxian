;; funding-calculator.clar
;; Handles funding rate calculations for perpetual contracts

;; Optional: dimensional position trait (not strictly required for current logic)
(use-trait dimensional-trait .dimensional-traits.dimensional-trait)


;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u5000))
(define-constant ERR_INVALID_INTERVAL (err u5001))
(define-constant ERR_NO_ACTIVE_POSITIONS (err u5002))
(define-constant PERPETUAL "perpetual")  ;; Position type for perpetual contracts

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var oracle-contract principal tx-sender)  ;; Oracle contract for price feeds
(define-data-var dimensional-engine-contract principal tx-sender)  ;; Dimensional engine contract
(define-data-var funding-interval uint u144)  ;; Default to daily funding
(define-data-var max-funding-rate uint u100)  ;; 1% max funding rate
(define-data-var funding-rate-sensitivity uint u500)  ;; 5% sensitivity

;; Funding rate history
(define-map funding-rate-history {
  asset: principal,
  timestamp: uint
} {
  rate: int,  ;; Funding rate in basis points (1 = 0.01%)
  index-price: uint,
  open-interest-long: uint,
  open-interest-short: uint
})

;; Last funding update
(define-map last-funding-update {
  asset: principal
} {
  timestamp: uint,
  cumulative-funding: int
})

;; ===== Core Functions =====
(define-public (update-funding-rate
    (asset principal)
  )
  (let (
    (current-time block-height)
    (last-update (default-to
      {timestamp: u0, cumulative-funding: 0}
      (map-get? last-funding-update {asset: asset})
    ))
  )
    ;; Check if enough time has passed since last update
    (asserts!
      (>= (- current-time (get last-update timestamp)) (var-get funding-interval))
      ERR_INVALID_INTERVAL
    )

    ;; Get current index price and TWAP
    (let (
      (index-price (unwrap! (contract-call? .oracle.oracle-aggregator-v2 get-price asset)
        (err u5003)
      ))(twap (unwrap!
        (contract-call? .oracle.oracle-aggregator-v2 get-twap asset
          (var-get funding-interval)
        )
        (err u5004)
      ))

      ;; Get open interest (simplified - in a real implementation, this would query position data)
      (open-interest (get-open-interest asset))
      (oi-long (get open-interest long))
      (oi-short (get open-interest short))

      ;; Calculate funding rate based on premium to index
      (premium (calculate-premium index-price twap))
      (funding-rate (calculate-funding-rate premium oi-long oi-short))

      ;; Cap funding rate
      (capped-rate (max
        (min funding-rate (var-get max-funding-rate))
        (* (var-get max-funding-rate) -1)
      ))

      ;; Calculate cumulative funding
      (new-cumulative (+ (get last-update cumulative-funding) capped-rate))
    )
      ;; Update funding rate history
      (map-set funding-rate-history {asset: asset, timestamp: current-time} {
        rate: capped-rate,
        index-price: index-price,
        open-interest-long: oi-long,
        open-interest-short: oi-short
      })

      ;; Update last funding update
      (map-set last-funding-update {asset: asset} {
        timestamp: current-time,
        cumulative-funding: new-cumulative
      })

      (ok {
        funding-rate: capped-rate,
        index-price: index-price,
        timestamp: current-time,
        cumulative-funding: new-cumulative
      })
    )
  )
)

;; ===== Position Funding =====
(define-public (apply-funding-to-position
    (position-owner principal)
    (position-id uint)
  )
  (let (
    (position (unwrap! (contract-call? (var-get dimensional-engine-contract) get-position position-owner position-id) (err u5005)))
    (current-time block-height)
    (asset (get asset position))
    (last-update (unwrap! (map-get? last-funding-update {asset: asset}) (err u5006)))
    (position-type (get status position))
  )
    ;; Only perpetuals have funding
    (asserts! (is-eq position-type PERPETUAL) (err u5007))

    ;; Calculate funding payment
    (let* (
      (size (abs (get position size)))
      (funding-rate (get last-update cumulative-funding))
      (funding-payment (/ (* size funding-rate) u10000))  ;; Funding rate is in basis points

      ;; Adjust position collateral
      (new-collateral (- (get position collateral) funding-payment))
    )
      ;; Update position collateral
      (try! (contract-call? (var-get dimensional-engine-contract) update-position
        position-owner
        position-id
        {collateral: (some new-collateral)}
      ))

      (ok {
        funding-rate: funding-rate,
        funding-payment: funding-payment,
        new-collateral: new-collateral,
        timestamp: current-time
      })
    )
  )
)

;; ===== Read-Only Functions =====
(define-read-only (get-current-funding-rate (asset principal))
  (match (map-get? last-funding-update {asset: asset})
    update (ok {
      rate: (get update cumulative-funding),
      last-updated: (get update timestamp),
      next-update: (+ (get update timestamp) (var-get funding-interval))
    })
    err (err u5008)
  )
)

(define-read-only (get-funding-rate-history
    (asset principal)
    (from-block uint)
    (to-block uint)
    (limit uint)
  )
  (let (
    (history (map-get-range funding-rate-history
      {asset: asset, timestamp: from-block}
      {asset: asset, timestamp: to-block}
      limit
    ))
  )
    (ok history)
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

(define-public (set-dimensional-engine-contract (dimensional-engine principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set dimensional-engine-contract dimensional-engine)
    (ok true)
  )
)

(define-public (set-funding-parameters
    (interval uint)
    (max-rate uint)
    (sensitivity uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (asserts! (and (> interval u0) (<= interval u1008)) (err u5009))  ;; Max 1 week at 10s/block
    (asserts! (<= max-rate u1000) (err u5010))  ;; Max 10%
    (asserts! (and (>= sensitivity u100) (<= sensitivity u1000)) (err u5011))  ;; 1-10%

    (var-set funding-interval interval)
    (var-set max-funding-rate max-rate)
    (var-set funding-rate-sensitivity sensitivity)
    (ok true)
  )
)

;; ===== Private Functions =====
(define-private (calculate-premium
    (index-price uint)
    (twap uint)
  )
  (if (> twap u0)
    (/ (* (- index-price twap) u10000) twap)  ;; Premium in basis points
    0
  )
)

;; @desc Returns the absolute value of an integer.
;; @param x (int) The integer.
;; @returns (uint) The absolute value.
(define-private (abs-int (x int))
  (if (< x i0)
    (- u0 x) ;; Negate the integer to get its absolute value
    (to-uint x)
  )
)

(define-private (calculate-funding-rate
    (premium int)
    (oi-long uint)
    (oi-short uint)
  )
  (let (
    (oi-diff (abs-int (- (to-int oi-long) (to-int oi-short)))) ;; Use abs-int and convert to int for subtraction
    (oi-total (+ oi-long oi-short))
    (sensitivity (var-get funding-rate-sensitivity))
  )
    (if (> oi-total u0)
      (let (
        (imbalance (/ (* (to-int oi-diff) u10000) (to-int oi-total)))
        (funding-rate (/ (* premium (+ u10000 (/ (* imbalance sensitivity) u100))) u10000))
      )
        funding-rate
      )
      i0 ;; Return i0 for consistency with int type
    )
  )
)

(define-private (get-open-interest (asset principal))
  ;; In a real implementation, this would query position data
  {
    long: u1000000,
    short: u800000
  }
)
