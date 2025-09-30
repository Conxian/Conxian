;; oracle-aggregator.clar
;; Aggregates price feeds from multiple oracles and provides TWAP calculations

;; Traits
(
use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait oracle-trait .all-traits.oracle-trait)
(use-trait access-control-trait .all-traits.access-control-trait)
(use-trait circuit-breaker-trait .all-traits.circuit-breaker-trait)
(use-trait oracle-aggregator-trait .all-traits.oracle-aggregator-trait)

(impl-trait .oracle-aggregator-trait)

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

    ;; Placeholder for manipulation detection logic
    ;; For now, just store the price
    (map-set asset-prices {asset: asset, block-height: block-height} {price: price})
    (map-set last-observation-block {asset: asset} {block-height: block-height})
    (ok true)
  )
)

;; Placeholder for TWAP calculation and aggregation logic
(define-read-only (get-aggregated-price (asset principal))
  (let
    ((total-price-sum u0)
     (total-weight-sum u0)
     (start-block (- block-height (var-get observation-period-blocks)))
     (end-block block-height)
     (prices (list )))

    (if (<= start-block u0)
        (begin
            (var-set start-block u1)
        )
    )

    (map registered-oracles
      (lambda (oracle-id-entry oracle-data)
        (let
          ((oracle-id (get oracle-id oracle-id-entry))
           (weight (get weight oracle-data)))

          (if (is-some (map-get? last-observation-block {asset: asset}))
            (let
              ((last-obs-block (get block-height (unwrap-panic (map-get? last-observation-block {asset: asset})))))

              (if (and (>= last-obs-block start-block) (<= last-obs-block end-block))
                (if (is-some (map-get? asset-prices {asset: asset, block-height: last-obs-block}))
                  (let
                    ((price (get price (unwrap-panic (map-get? asset-prices {asset: asset, block-height: last-obs-block})))))
                    (var-set total-price-sum (+ total-price-sum (* price weight)))
                    (var-set total-weight-sum (+ total-weight-sum weight))
                    (var-set prices (append prices price))
                  )
                )
              )
            )
          )
        )
      )
    )

    (asserts! (> total-weight-sum u0) ERR_NO_PRICE_DATA)

    (let
      ((twap (/ total-price-sum total-weight-sum)))

      ;; Basic manipulation detection: check if any price deviates significantly from TWAP
      (map prices
        (lambda (price)
          (let
            ((deviation (* (abs (- price twap)) u10000) (/ u1 twap)))
            (asserts! (<= deviation MANIPULATION_THRESHOLD_PERCENTAGE) ERR_PRICE_MANIPULATION_DETECTED)
          )
        )
      )
      (ok twap)
    )
  )
)

;; Read-only Functions
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