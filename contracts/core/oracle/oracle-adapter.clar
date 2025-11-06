;; oracle-adapter.clar
;; Oracle adapter for the dimensional engine

;; Consolidated trait imports - one canonical oracle-trait is enough
(use-trait oracle-trait .all-traits.oracle-trait)
(use-trait dimensional-trait .all-traits.dimensional-trait)

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
    (asserts! (get is-active oracle) ERR_INVALID_ORACLE)

    ;; Verify price freshness
    (asserts! (>= timestamp (- current-block (var-get max-price-age))) ERR_STALE_DATA)

    ;; Get current price data
    (let (
      (price-data (default-to
        {price: u0, last-updated: u0, twap: u0, twap-interval: u0, price-history: (list )}
        (map-get? asset-prices {asset: asset})))
      (curr (get price price-data))
      (price-diff (if (>= price curr) (- price curr) (- curr price)))
      (price-diff-percent (if (> curr u0)
        (/ (* price-diff u10000) curr)
        u0
      ))
    )
      ;; Check price deviation
      (if (> price-diff-percent (var-get max-price-deviation))
        (begin
          (asserts! (is-some signature) ERR_DEVIATION_TOO_HIGH)
          ;; TODO: Verify signature from trusted signer
        )
        true
      )

      ;; Update price history (keep last 100 entries)
      (let (
        (history-appended (append (get price-history price-data)
          {price: price, timestamp: current-block}
        ))
        (new-history (match (as-max-len? history-appended u100) nh nh (get price-history price-data)))
        ;; Calculate TWAP over last entries
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
          weight: (get weight oracle),
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
    (oracle principal)
    (weight uint)
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
    price-data (ok (get price price-data))
    (err u4001)
  )
)

(define-read-only (get-twap (asset principal) (interval uint))
  (match (map-get? asset-prices {asset: asset})
    price-data
    (if (>= (get last-updated price-data) (- block-height interval))
      (ok (get twap price-data))
      (err u4002)  ;; Stale TWAP data
    )
    (err u4001)  ;; No price data
  )
)

;; ===== Private Functions =====
(define-private (calculate-twap
    (history (list 100 {price: uint, timestamp: uint}))
    (current-time uint)
  )
  (match (element-at history u0)
    entry (get price entry)
    u0
  )
)
