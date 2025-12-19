;; @contract Pyth Oracle Adapter
;; @version 1.0.0
;; @author Conxian Protocol
;; @desc Adapter to fetch prices from the Pyth Network oracle on Stacks.
;; Implements the Conxian `oracle-trait` to integrate with the Oracle Aggregator.

(use-trait oracle-trait .oracle-pricing.oracle-trait)
(use-trait pyth-storage-trait .pyth-traits.pyth-storage-trait)

(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_ASSET_NOT_MAPPED (err u4004))
(define-constant ERR_STALE_PRICE (err u4005))
(define-constant ERR_NOT_SUPPORTED (err u9000))

;; Pyth Price Feed Data Structure
(define-constant POWERS_OF_10 (list
  u1
  u10
  u100
  u1000
  u10000
  u100000
  u1000000
  u10000000
  u100000000
  u1000000000
  u10000000000
  u100000000000
  u1000000000000
  u10000000000000
  u100000000000000
  u1000000000000000
  u10000000000000000
  u100000000000000000
  u1000000000000000000
))

(define-data-var contract-owner principal tx-sender)
(define-constant pyth-contract-principal .pyth-oracle-v2-mock)
(define-constant pyth-storage-contract .pyth-store-mock)

(define-map asset-feed-ids
  principal
  (buff 32)
)

;; --- Internal Helpers ---

(define-private (pow-10 (exp uint))
  (default-to u1 (element-at POWERS_OF_10 exp))
)

(define-private (int-to-uint (i int))
  (if (< i 0)
    u0
    (to-uint i)
  )
)

(define-private (normalize-price
    (price int)
    (expo int)
  )
  (let (
      (abs-price (if (< price 0)
        (* price -1)
        price
      ))
      ;; Pyth price = price * 10^expo
      ;; We want 18 decimals.
      ;; result = price * 10^(18 + expo)
      (exponent (+ 18 expo))
    )
    (if (>= exponent 0)
      (let ((scale-factor (pow-10 (int-to-uint exponent))))
        (* (int-to-uint abs-price) scale-factor)
      )
      ;; If exponent is negative (e.g. expo < -18), we divide
      (let ((scale-factor (pow-10 (int-to-uint (* -1 exponent)))))
        (/ (int-to-uint abs-price) scale-factor)
      )
    )
  )
)

;; --- Admin Functions ---

(define-public (set-asset-feed-id
    (asset principal)
    (feed-id (buff 32))
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set asset-feed-ids asset feed-id)
    (ok true)
  )
)

;; --- Oracle Trait Implementation ---

(define-public (get-price (asset principal))
  (let (
      (feed-id (unwrap! (map-get? asset-feed-ids asset) ERR_ASSET_NOT_MAPPED))
      ;; Call Pyth contract with the hardcoded storage contract
      (price-data (try! (contract-call? .pyth-oracle-v2-mock read-price-feed feed-id
        .pyth-store-mock
      )))
    )
    (ok (normalize-price (get price price-data) (get expo price-data)))
  )
)

(define-public (get-price-with-timestamp (asset principal))
  (let (
      (feed-id (unwrap! (map-get? asset-feed-ids asset) ERR_ASSET_NOT_MAPPED))
      (price-data (try! (contract-call? .pyth-oracle-v2-mock read-price-feed feed-id
        .pyth-store-mock
      )))
    )
    (ok {
      price: (normalize-price (get price price-data) (get expo price-data)),
      timestamp: (get publish-time price-data),
    })
  )
)

(define-public (update-price
    (asset principal)
    (price uint)
  )
  ;; Pyth does not support direct price updates via this adapter.
  ;; Prices are updated via Wormhole VAAs submitted to the Pyth contract directly.
  ERR_NOT_SUPPORTED
)
