;; oracle-adapter.clar
;; Oracle adapter for the dimensional engine

(use-trait oracle-trait .all-traits.oracle-trait)
(use-trait dimensional-trait .all-traits.dimensional-trait)

(use-trait oracle_trait .all-traits.oracle-trait)
 .all-traits.oracle-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u3000))
(define-constant ERR_INVALID_ORACLE (err u3001))
(define-constant ERR_STALE_DATA (err u3002))
(define-constant ERR_DEVIATION_TOO_HIGH (err u3003))

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var max-price-age uint u100)  ;; ~16.7 minutes (assuming ~10s/block)
(define-data-var max-price-deviation uint u500)  ;; 5%

;; Oracle registry
(define-map oracles {
  address: principal
} {
  weight: uint,
  is-active: bool,
  last-updated: uint,
  last-price: uint
})

;; Asset prices with TWAP support
(define-map asset-prices {
  asset: principal
} {
  price: uint,
  last-updated: uint,
  twap: uint,
  twap-interval: uint,
  price-history: (list 100 {price: uint, timestamp: uint})
})

;; ===== Core Functions =====
(define-public (update-price
    (asset principal)
    (price uint)
    (timestamp uint)
    (signature (optional (buff 65)))
  )
  (let (
    (caller tx-sender)
    (current-block block-height)
    (oracle (unwrap! (map-get? oracles {address: caller}) ERR_INVALID_ORACLE))
  )
    (asserts! (get oracle is-active) ERR_INVALID_ORACLE)

    ;; Verify price freshness
    (asserts! (>= timestamp (- current-block (var-get max-price-age))) ERR_STALE_DATA)

    ;; Get current price data
    (let (
      (price-data (default-to
        {price: u0, last-updated: u0, twap: u0, twap-interval: u0, price-history: (list )}
        (map-get? asset-prices {asset: asset})
      (price-diff (abs (- price (get price-data price))))
      (price-diff-percent (if (> (get price-data price) u0)
        (/ (* price-diff u10000) (get price-data price))
        u0
      ))
    )
      ;; Check price deviation
      (when (> price-diff-percent (var-get max-price-deviation))
        (asserts! (is-some signature) ERR_DEVIATION_TOO_HIGH)
        ;; TODO: Verify signature from trusted signer
      )

      ;; Update price history (keep last 100 entries)
      (let (
        (new-history (take (append (get price-data price-history)
          (list {price: price, timestamp: current-block})
        ) u100))

        ;; Calculate TWAP over last 100 blocks
        (twap (calculate-twap new-history current-block))
      )
        ;; Update price data
        (map-set asset-prices {asset: asset} {
          price: price,
          last-updated: current-block,
          twap: twap,
          twap-interval: u100,  ;; 100 blocks
          price-history: new-history
        })

        ;; Update oracle info
        (map-set oracles {address: caller} {
          weight: (get oracle weight),
          is-active: true,
          last-updated: current-block,
          last-price: price
        })

        (ok true)
      )
    )
  )
)

;; ===== Oracle Management =====
(define-public (add-oracle
    (oracle: principal)
    (weight: uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (map-set oracles {address: oracle} {
      weight: weight,
      is-active: true,
      last-updated: block-height,
      last-price: u0
    })
    (ok true)
  )
)

(define-public (remove-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (map-delete oracles {address: oracle})
    (ok true)
  )
)

;; ===== Price Queries =====
(define-read-only (get-price (asset principal))
  (match (map-get? asset-prices {asset: asset})
    price-data (ok (get price-data price))
    err (err u4001)
  )
)

(define-read-only (get-twap (asset principal) (interval uint))
  (match (map-get? asset-prices {asset: asset})
    price-data
    (if (>= (get price-data last-updated) (- block-height interval))
      (ok (get price-data twap))
      (err u4002)  ;; Stale TWAP data
    )
    err (err u4001)  ;; No price data
  )
)

;; ===== Private Functions =====
(define-private (calculate-twap
    (price-history (list 100 {price: uint, timestamp: uint}))
    (current-time uint)
  )
  (let (
    (total-weight u0)
    (weighted-sum u0)
    (prev-timestamp (default-to u0 (get (element-at price-history u0) timestamp)))
  )
    (fold price-history (tuple (weighted-sum u0) (total-weight u0))
      (lambda (acc entry)
        (let (
          (time-diff (- (get entry timestamp) prev-timestamp))
          (weight (if (> time-diff u0) time-diff u1))
        )
          (tuple
            (+ (get acc weighted-sum) (* (get entry price) weight))
            (+ (get acc total-weight) weight)
          )
        )
      )
    )
    (if (> total-weight u0)
      (/ weighted-sum total-weight)
      u0
    )
  )
)
