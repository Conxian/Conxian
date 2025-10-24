(use-trait oracle-aggregator-trait .all-traits.oracle-aggregator-trait)

;; oracle-aggregator.clar
;; Aggregates price feeds from multiple oracles and provides TWAP calculations

(use-trait oracle_aggregator_trait .all-traits.oracle-aggregator-trait)
.all-traits.oracle-aggregator-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_ORACLE (err u101))
(define-constant ERR_NO_PRICE_DATA (err u102))
(define-constant ERR_PRICE_MANIPULATION_DETECTED (err u103))
(define-constant ERR_OBSERVATION_PERIOD_TOO_SHORT (err u104))

(define-constant MAX_OBSERVATIONS_PER_ASSET u100)
(define-constant MANIPULATION_THRESHOLD_PERCENTAGE u500) ;; 5% deviation

;; Data Variables
(define-data-var admin principal tx-sender)
(define-data-var observation-period-blocks uint u10)

;; Data Maps
(define-map registered-oracles 
  { oracle-id: principal } 
  { weight: uint }
)

(define-map asset-prices 
  { asset: principal, block-height: uint } 
  { price: uint }
)

(define-map last-observation-block 
  { asset: principal } 
  { block-height: uint }
)

(define-map price-observations 
  { asset: principal, block: uint } 
  { price: uint }
)

(define-map feed-counts 
  { token: principal } 
  { count: uint }
)

(define-map manipulation-thresholds
  { asset-id: (string-ascii 32) }
  {
    price-deviation-threshold: uint,
    volume-deviation-threshold: uint,
    time-window: uint
  }
)

;; Public Functions
(define-public (register-oracle (oracle-id principal) (weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set registered-oracles { oracle-id: oracle-id } { weight: weight })
    (ok true)
  )
)

(define-public (add-oracle-feed (token principal) (feed principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (let ((entry (map-get? feed-counts { token: token })))
      (match entry
        e (map-set feed-counts { token: token } { count: (+ (get count e) u1) })
        (map-set feed-counts { token: token } { count: u1 })
      )
    )
    (ok true)
  )
)

(define-public (remove-oracle-feed (token principal) (feed principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (let ((entry (map-get? feed-counts { token: token })))
      (match entry
        e (map-set feed-counts { token: token } { count: (if (> (get count e) u0) (- (get count e) u1) u0) })
        (ok true)
      )
    )
    (ok true)
  )
)

;; Read-Only Functions
(define-read-only (get-feed-count (token principal))
  (match (map-get? feed-counts { token: token })
    e (ok (get count e))
    (ok u0)
  )
)

(define-read-only (get-aggregated-price (token principal))
  ;; Minimal stub: returns zero; replace with TWAP aggregation in Phase 2
  (ok u0)
)