;; Oracle - Minimal implementation of oracle-trait
;; Provides price feed functionality for assets

(use-trait dimensional-oracle-trait .all-traits.dimensional-oracle-trait)

;; Error codes
(define-constant ERR_ASSET_NOT_FOUND (err u404))
(define-constant ERR_UNAUTHORIZED (err u401))

(define-data-var admin principal tx-sender)
(define-map asset-prices { asset: principal } { price: uint })

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-price (asset principal) (price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set asset-prices { asset: asset } { price: price })
    (ok true)
  )
)

(define-read-only (get-price (asset principal))
  (match (map-get? asset-prices { asset: asset })
    entry (ok (get price entry))
    (err ERR_ASSET_NOT_FOUND)
  )
);; Update
 price function (alias for set-price to match trait)
(define-public (update-price (asset principal) (price uint))
  (set-price asset price)
)

;; Get TWAP (Time Weighted Average Price)
(define-read-only (get-twap (asset principal) (interval uint))
  (match (map-get? asset-prices { asset: asset })
    entry (ok (get price entry))  ;; Simplified - return current price as TWAP
    (err ERR_ASSET_NOT_FOUND)
  )
)