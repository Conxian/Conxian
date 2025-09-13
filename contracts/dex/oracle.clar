;; oracle.clar
;; Standard price oracle implementation for the Conxian protocol

;; Define Oracle Trait
(define-trait oracle-trait
  (
    (get-price (principal) (response (optional uint) uint))
    (get-price-in-usd (principal) (response (optional uint) uint))
    (update-price (principal uint) (response bool uint))
    (add-or-update-feed (principal principal) (response bool uint))
    (remove-feed (principal) (response bool uint))
  )
)

;; Implement the oracle trait with proper syntax
(impl-trait oracle-trait)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INVALID_ASSET (err u1002))
(define-constant ERR_STALE_PRICE (err u1003))
(define-constant ERR_INVALID_PRICE (err u1004))

;; Constants
(define-constant PRICE_STALE_THRESHOLD (* u60 u60 u24))  ;; 24 hours in blocks (assuming 1 block/2s)
(define-constant MIN_PRICE u100)  ;; $0.0000000000000001 (1e-16)
(define-constant MAX_PRICE (* u1000000000000000000 u1000000))  ;; $1M with 18 decimals

;; Contract state
(define-data-var admin principal tx-sender)
(define-data-var oracle-contract (optional principal) none)

;; Asset prices with metadata
(define-map asset-prices
  { asset: principal }
  { 
    price: uint,            ;; Price with 18 decimals
    last-update: uint,      ;; Block height of last update
    decimals: uint,         ;; Decimals of the price
    is-frozen: bool         ;; If true, price cannot be updated
  }
)

;; ===== Public Functions =====

;; Set the price of an asset
(define-public (set-price (asset principal) (price uint))
  (let ((caller tx-sender))
    (asserts! (or 
                (is-eq caller (var-get admin))
                (is-eq (some? caller) (var-get oracle-contract))
              ) 
      ERR_UNAUTHORIZED)
      
    (asserts! (and 
                (>= price MIN_PRICE)
                (<= price MAX_PRICE)
              ) 
      ERR_INVALID_PRICE)
      
    (match (map-get? asset-prices { asset: asset })
      existing (asserts! (not (get is-frozen existing)) (err u1005))  ;; ERR_PRICE_FROZEN
      (ok true)
    )
    
    (map-set asset-prices { asset: asset }
      { 
        price: price, 
        last-update: block-height,
        decimals: u18,
        is-frozen: false
      }
    )
    (ok true)
  )
)

;; ===== Standard Interface Implementation =====

(define-read-only (get-price (asset principal))
  (match (map-get? asset-prices { asset: asset })
    price-data (ok (get price price-data))
    (err ERR_INVALID_ASSET)
  )
)

(define-read-only (get-last-update (asset principal))
  (match (map-get? asset-prices { asset: asset })
    price-data (ok (get last-update price-data))
    (err ERR_INVALID_ASSET)
  )
)

(define-read-only (is-price-fresh (asset principal))
  (match (map-get? asset-prices { asset: asset })
    price-data 
      (ok (<= 
            (- block-height (get last-update price-data)) 
            PRICE_STALE_THRESHOLD
          ))
    (err ERR_INVALID_ASSET)
  )
)

(define-read-only (get-price-fresh (asset principal))
  (let (
      (price (unwrap! (get-price asset) (err ERR_INVALID_ASSET)))
      (is-fresh (unwrap! (is-price-fresh asset) (err ERR_INVALID_ASSET)))
    )
    (asserts! is-fresh (err ERR_STALE_PRICE))
    (ok price)
  )
)

;; ===== Admin Functions =====

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-oracle-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set oracle-contract (some contract))
    (ok true)
  )
)

(define-read-only (get-oracle-contract)
  (ok (var-get oracle-contract))
)

;; Freeze an assets price to prevent further updates
(define-public (freeze-price (asset principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (match (map-get? asset-prices { asset: asset })
      price-data 
        (map-set asset-prices { asset: asset }
          (merge price-data { is-frozen: true })
        )
      (err ERR_INVALID_ASSET)
    )
    (ok true)
  )
)

;; Unfreeze an assets price to allow updates
(define-public (unfreeze-price (asset principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (match (map-get? asset-prices { asset: asset })
      price-data 
        (map-set asset-prices { asset: asset }
          (merge price-data { is-frozen: false })
        )
      (err ERR_INVALID_ASSET)
    )
    (ok true)
  )
)





