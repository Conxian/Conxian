(use-trait oracle-aggregator .all-traits.oracle-aggregator-trait)
(use-trait oracle-aggregator-trait .all-traits.oracle-aggregator-trait)
;; oracle-aggregator.clar
;; Aggregates price feeds from multiple oracles and provides TWAP calculations

;; Traits



(use-trait oracle_aggregator_trait .all-traits.oracle-aggregator-trait)
 .all-traits.oracle-aggregator-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_ORACLE (err u101))
(define-constant ERR_NO_PRICE_DATA (err u102))
(define-constant ERR_PRICE_MANIPULATION_DETECTED (err u103))
(define-constant ERR_OBSERVATION_PERIOD_TOO_SHORT (err u104))

(define-constant MAX_OBSERVATIONS_PER_ASSET u100)
(define-constant MANIPULATION_THRESHOLD_PERCENTAGE u500) ;; 5% deviation

;; Data Maps
(define-map registered-oracles {
  oracle-id: principal
} {
  weight: uint
})

;; asset-prices: {asset: principal, block-height: uint} {price: uint}
(define-map asset-prices {
  asset: principal,
  block-height: uint
} {
  price: uint
})

;; last-observation-block: {asset: principal} {block-height: uint}
(define-map last-observation-block {
  asset: principal
} {
  block-height: uint
})

(define-map price-observations {
  asset: principal,
  block: uint
} {
  price: uint
})

;; last-observation-block: {asset: principal} {block-height: uint}
(define-map last-observation-block {
  asset: principal
} {
  block-height: uint
})

(define-map manipulation-thresholds
  {asset-id (string-ascii 32)}
  {
    price-deviation-threshold (uint 1000) ;; Basis points (e.g., 1000 = 10%)
    volume-deviation-threshold (uint 1000) ;; Basis points (e.g., 1000 = 10%)
    time-window (uint 10) ;; Number of blocks to consider for deviation
  }
)

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var observation-period-blocks uint u10)

;; Public Functions
(define-public (register-oracle (oracle-id principal) (weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set registered-oracles { oracle-id: oracle-id } { weight: weight })
    (ok true)
  )
)

(define-public (deregister-oracle (oracle-id principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-delete registered-oracles { oracle-id: oracle-id })
    (ok true)
  )
)

(define-public (submit-price (asset principal) (price uint))
  (begin
    (asserts! (is-some (map-get? registered-oracles {oracle-id: tx-sender})) ERR_INVALID_ORACLE)

    ;; Check for price manipulation before storing
    (let ((manipulation-detected (detect-price-manipulation asset price)))
      (asserts! (is-ok manipulation-detected) (unwrap-err manipulation-detected)) ;; Propagate error if TWAP fails
      (if (unwrap-panic manipulation-detected)
          (begin
            ;; Price manipulation detected, open the circuit breaker for this asset
            (try! (contract-call? .circuit-breaker set-circuit-breaker-status asset true))
            (err ERR_PRICE_MANIPULATION_DETECTED))
        true)
    )

    ;; Store price observation for TWAP
    (map-set price-observations {asset: asset, block: block-height} {price: price})

    ;; Update last observation block
    (map-set last-observation-block {asset: asset} {block-height: block-height})

    ;; Clean up old observations if MAX_OBSERVATIONS_PER_ASSET is exceeded
    (let ((current-block block-height)
          (oldest-block (- block-height MAX_OBSERVATIONS_PER_ASSET)))
      (map-delete price-observations {asset: asset, block: oldest-block})
    )

    (ok true)
  )
)

;; Simplified aggregated price: return last submitted price
(define-read-only (get-aggregated-price (asset principal))
  (match (map-get? last-observation-block {asset: asset})
    obs (match (map-get? asset-prices {asset: asset, block-height: (get block-height obs)})
          price-entry (ok (get price price-entry))
          (err ERR_NO_PRICE_DATA))
    (err ERR_NO_PRICE_DATA)
  )
)

(define-read-only (get-twap-price (asset principal))
  (let ((current-block block-height)
        (period (var-get observation-period-blocks))
        (start-block (- current-block period)))
    (if (<= start-block u0)
        (err ERR_OBSERVATION_PERIOD_TOO_SHORT)
      (let ((total-price u0)
            (observations-count u0))
        (map-fold
          price-observations
          (f (key {asset: A, block: B}) (value {price: P}) (acc {total: T, count: C}))
          (if (and (is-eq A asset) (>= B start-block))
            {total: (+ T P), count: (+ C u1)}
            acc
          )
          {total: u0, count: u0}
        )
        (ok (/ total-price observations-count))
      )
    )
  )
)

(define-read-only (detect-price-manipulation (asset principal) (current-price uint))
  (let ((twap-result (get-twap-price asset))
        (asset-id-str (unwrap-panic (contract-of asset)))) ;; Assuming asset principal can be converted to string-ascii 32
    (if (is-err twap-result)
        (err ERR_NO_PRICE_DATA) ;; Or a more specific error for TWAP failure
      (let ((twap-price (unwrap-panic twap-result))
            (thresholds (map-get? manipulation-thresholds {asset-id: asset-id-str})))
        (if (is-none thresholds)
            (ok false) ;; No manipulation thresholds set, so no manipulation detected
          (let ((price-deviation-threshold (get price-deviation-threshold (unwrap-panic thresholds))))
            (if (is-eq twap-price u0)
                (ok false) ;; Avoid division by zero, consider as no manipulation
              (let ((deviation (abs (- current-price twap-price)))
                    (deviation-percentage (/ (* deviation u10000) twap-price)))
                (if (> deviation-percentage price-deviation-threshold)
                    (ok true) ;; Price manipulation detected
                  (ok false)
                )
              )
            )
          )
        )
      )
    )
  )
)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-read-only (get-observation-period-blocks)
  (ok (var-get observation-period-blocks))
)

(define-public (set-observation-period-blocks (new-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> new-period u0) ERR_OBSERVATION_PERIOD_TOO_SHORT)
    (var-set observation-period-blocks new-period)
    (ok true)
  )
)

(define-public (set-manipulation-thresholds
  (asset-id (string-ascii 32))
  (price-deviation-threshold uint)
  (volume-deviation-threshold uint)
  (time-window uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set manipulation-thresholds
      {asset-id: asset-id}
      {
        price-deviation-threshold: price-deviation-threshold,
        volume-deviation-threshold: volume-deviation-threshold,
        time-window: time-window
      }
    )
    (ok true)
  )
)

(define-read-only (get-manipulation-thresholds (asset-id (string-ascii 32)))
  (ok (map-get? manipulation-thresholds {asset-id: asset-id}))
)

