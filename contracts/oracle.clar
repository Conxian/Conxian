;; oracle.clar
;; Simple price oracle contract

(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INVALID_ASSET (err u1002))

;; Admin
(define-data-var admin principal tx-sender)

;; Asset prices
(define-map asset-prices
  { asset: principal }
  { price: uint, last-update: uint }
)

;; Set the price of an asset
(define-public (set-price (asset principal) (price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set asset-prices { asset: asset }
      { price: price, last-update: block-height }
    )
    (ok true)
  )
)

;; Get the price of an asset
(define-read-only (get-price (asset principal))
  (match (map-get? asset-prices { asset: asset })
    price (ok (get price price))
    (err ERR_INVALID_ASSET)
  )
)

;; Update admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
