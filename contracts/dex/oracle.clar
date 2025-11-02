;; DEX Oracle - Minimal implementation of oracle-trait

(use-trait oracle-trait .all-traits.oracle-trait)


(define-constant ERR_ASSET_NOT_FOUND (err u404))
(define-constant ERR_UNAUTHORIZED (err u401))

;; Error codes
(define-constant ERR_INVALID_ASSET (err u1002))
(define-constant ERR_STALE_PRICE (err u1003))
(define-constant ERR_INVALID_PRICE (err u1004))

;; Constants
(define-constant PRICE_STALE_THRESHOLD (* u60 u60 u24))  ;; 24 hours in blocks (assuming 1 block/2s)
(define-constant MIN_PRICE u100)  ;; $0.0000000000000001 (1e-16)
(define-constant MAX_PRICE (* u1000000000000000000 u1000000))  ;; $1M with 18 decimals

;; Contract state

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
)