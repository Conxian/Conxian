;; DEX Oracle - Minimal implementation of oracle-trait

(use-trait oracle-trait .05-oracle-pricing.oracle-aggregator-v2-trait)

;; --- Constants ---
;; @constant ERR_ASSET_NOT_FOUND (err u404) - Returned when the requested asset price is not found.
(define-constant ERR_ASSET_NOT_FOUND (err u404))
;; @constant ERR_UNAUTHORIZED (err u401) - Returned when the caller is not authorized to perform the action.
(define-constant ERR_UNAUTHORIZED (err u401))
;; @constant ERR_INVALID_ASSET (err u1002) - Returned when an invalid asset is provided.
(define-constant ERR_INVALID_ASSET (err u1002))
;; @constant ERR_STALE_PRICE (err u1003) - Returned when the price data is stale.
(define-constant ERR_STALE_PRICE (err u1003))
;; @constant ERR_INVALID_PRICE (err u1004) - Returned when an invalid price value is provided.
(define-constant ERR_INVALID_PRICE (err u1004))

;; @constant PRICE_STALE_THRESHOLD (* u60 u60 u24) - The threshold in blocks after which a price is considered stale (24 hours).
(define-constant PRICE_STALE_THRESHOLD (* u60 u60 u24))  ;; 24 hours in blocks (assuming 1 block/2s)
;; @constant MIN_PRICE u100 - The minimum allowed price (1e-16).
(define-constant MIN_PRICE u100)  ;; $0.0000000000000001 (1e-16)
;; @constant MAX_PRICE (* u1000000000000000000 u1000000) - The maximum allowed price ($1M with 18 decimals).
(define-constant MAX_PRICE (* u1000000000000000000 u1000000))  ;; $1M with 18 decimals

;; --- Data Variables ---
;; @var admin principal - The principal of the contract administrator.
(define-data-var admin principal tx-sender)

;; --- Data Maps ---
;; @map asset-prices { asset: principal } { price: uint }
;; Stores the current price for each asset.
(define-map asset-prices { asset: principal } { price: uint })

;; --- Public Functions ---

;; @desc Sets the administrator of the oracle contract. Only the current admin can call this function.
;; @param new-admin principal - The principal of the new administrator.
;; @returns (response bool uint) - (ok true) on success, (err ERR_UNAUTHORIZED) if the caller is not the current admin.
;; @events (print (ok true))
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Sets the price for a given asset. Only the contract admin can call this function.
;; @param asset principal - The principal of the asset for which to set the price.
;; @param price uint - The new price of the asset.
;; @returns (response bool uint) - (ok true) on success, (err ERR_UNAUTHORIZED) if the caller is not the admin.
;; @events (print (ok true))
(define-public (set-price (asset principal) (price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set asset-prices { asset: asset } { price: price })
    (ok true)
  )
)

;; --- Read-Only Functions ---

;; @desc Retrieves the current price of a given asset.
;; @param asset principal - The principal of the asset to query.
;; @returns (response uint uint) - (ok price) if the price is found, (err ERR_ASSET_NOT_FOUND) otherwise.
(define-read-only (get-price (asset principal))
  (match (map-get? asset-prices { asset: asset })
    entry (ok (get price entry))
    (err ERR_ASSET_NOT_FOUND)
  )
)
