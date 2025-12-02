;; funding-calculator.clar
;; Handles funding rate calculations for perpetual contracts

;; Option
(use-trait dimensional-trait .dimensional-traits.dimensional-trait)
(use-trait position-manager-trait .dimensional-traits.position-manager-trait)
(use-trait dimensional-engine-trait .dimensional-traits.dimensional-engine-trait)
(use-trait oracle-trait .oracle-pricing.oracle-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u5000))
(define-constant ERR_INVALID_INTERVAL (err u5001))
(define-constant ERR_NO_ACTIVE_POSITIONS (err u5002))
(define-constant PERPETUAL "perpetual") ;; Position type for perpetual contracts

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var oracle-contract principal tx-sender) ;; Oracle contract for price feeds
(define-data-var dimensional-engine-contract principal tx-sender) ;; Dimensional engine contract
(define-data-var funding-interval uint u144) ;; Default to daily funding
(define-data-var max-funding-rate uint u100) ;; 1% max funding rate
(define-data-var funding-rate-sensitivity uint u500) ;; 5% sensitivity

;; Funding rate history
(define-map funding-rate-history
  {
    asset: principal,
    timestamp: uint,
  }
  {
    rate: int, ;; Funding rate in basis points (1 = 0.01%)
    index-price: uint,
    open-interest-long: uint,
    open-interest-short: uint,
  }
)

;; Last funding update
(define-map last-funding-update
  { asset: principal }
  {
    timestamp: uint,
    cumulative-funding: int,
  }
)

;; ===== Core Functions =====
(define-public (update-funding-rate
    (asset principal)
    (oracle <oracle-trait>)
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
    ;; Check if enough time has passed since last update
    (asserts!
      (>= (- current-time (get timestamp last-update)) (var-get funding-interval))
      ERR_INVALID_INTERVAL
    )

    ;; Get current index price and TWAP via the oracle trait parameter
    (let (
        (index-price (unwrap! (contract-call? oracle get-price asset) (err u5003)))
        (twap (unwrap! (contract-call? oracle get-price asset) (err u5004)))
        ;; Get open interest (simplified - in a real implementation, this would query position data)
        (open-interest (unwrap! (get-open-interest asset) (err u5009)))
        (oi-long (get long open-interest))
        (oi-short (get short open-interest))
        ;; Calculate funding rate based on premium to index
        (premium (calculate-premium index-price twap))
        (funding-rate (calculate-funding-rate premium oi-long oi-short))
        ;; Cap funding rate
        (maxr (to-int (var-get max-funding-rate)))
        (neg-max (* maxr -1))
        (upper (if (> funding-rate maxr)
          maxr
          funding-rate
        ))
        (capped-rate (if (< upper neg-max)
          neg-max
          upper
        ))
        ;; Calculate cumulative funding
        (new-cumulative (+ (get cumulative-funding last-update) capped-rate))
      )
      ;; Update funding rate history
      (map-set funding-rate-history {
        asset: asset,
        timestamp: current-time,
      } {
        rate: capped-rate,
        index-price: index-price,
        open-interest-long: oi-long,
        open-interest-short: oi-short,
      })

      ;; Update last funding update
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

;; ===== Position Funding =====
(define-public (apply-funding-to-position
    (position-owner principal)
    (position-id uint)
    (dim-engine <dimensional-engine-trait>)
    (pos-mgr <position-manager-trait>)
  )
  (let (
      (position (unwrap! (contract-call? pos-mgr get-position position-id) (err u5005)))
      (asset (get asset position))
      (last-update (unwrap! (map-get? last-funding-update { asset: asset }) (err u5006)))
    )
    (let (
        (size (abs-int (to-int (get size position))))
        (funding-rate (get cumulative-funding last-update))
        (funding-payment (/ (* (to-int size) funding-rate) (to-int u10000)))
        (new-collateral (- (get collateral position) (abs-int funding-payment)))
      )
      (try! (contract-call? pos-mgr update-position position-id (some new-collateral)
        none none none
      ))
      (ok {
        funding-rate: funding-rate,
        funding-payment: funding-payment,
        new-collateral: new-collateral,
        timestamp: block-height,
      })
    )
  )
)

;; ===== Read-Only Functions =====
(define-read-only (get-current-funding-rate (asset principal))
  (match (map-get? last-funding-update { asset: asset })
    update (ok {
      rate: (get cumulative-funding update),
      last-updated: (get timestamp update),
      next-update: (+ (get timestamp update) (var-get funding-interval)),
    })
    (err u5008)
  )
)

(define-read-only (get-funding-rate-history
    (asset principal)
    (from-block uint)
    (to-block uint)
    (limit uint)
  )
  (ok (list))
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
    (asserts! (and (> interval u0) (<= interval u1008)) (err u5009)) ;; Max 1 week at 10s/block
    (asserts! (<= max-rate u1000) (err u5010)) ;; Max 10%
    (asserts! (and (>= sensitivity u100) (<= sensitivity u1000)) (err u5011)) ;; 1-10%

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
    (to-int (/ (* (- index-price twap) u10000) twap))
    (to-int u0)
  )
)

;; @desc Returns the absolute value of an integer.
;; @param x (int) The integer.
;; @returns (uint) The absolute value.
(define-private (abs-int (x int))
  (if (< x 0)
    (to-uint (- 0 x)) ;; Negate the integer to get its absolute value
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
          (sensitivity-int (to-int sensitivity))
          (imbalance (/ (* (to-int oi-diff) (to-int u10000)) (to-int oi-total)))
          (funding-rate (/
            (* premium
              (+ (to-int u10000) (/ (* imbalance sensitivity-int) (to-int u100)))
            )
            (to-int u10000)
          ))
        )
        funding-rate
      )
      0
    )
  )
)

(define-read-only (get-open-interest (asset principal))
  ;; In a real implementation, this would query position data
  (ok {
    long: u1000000,
    short: u800000,
  })
)
