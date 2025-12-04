;; @contract Federated Oracle Adapter
;; @version 1.0.0
;; @author Conxian Protocol
;; @desc Adapter for a trusted federated price feed (e.g. institutional backup).
;; Implements the Conxian `oracle-trait`.

(use-trait oracle-trait .oracle-pricing.oracle-trait)

(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_ASSET_NOT_MAPPED (err u4004))
(define-constant ERR_STALE_PRICE (err u4005))

(define-data-var contract-owner principal tx-sender)
(define-map prices principal { price: uint, last-updated: uint })
(define-map asset-symbols principal (string-ascii 32))

;; --- Admin Functions ---

(define-public (set-price (asset principal) (price uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map-set prices asset { price: price, last-updated: block-height })
        (ok true)
    )
)

(define-public (batch-set-prices (assets (list 50 principal)) (new-prices (list 50 uint)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map (lambda (asset price) (map-set prices asset { price: price, last-updated: block-height })) assets new-prices)
        (ok true)
    )
)

;; --- Oracle Trait Implementation ---

(define-public (get-price (asset principal))
    (let (
        (price-data (unwrap! (map-get? prices asset) ERR_ASSET_NOT_MAPPED))
    )
        (ok (get price price-data))
    )
)

(define-public (get-price-with-timestamp (asset principal))
    (let (
        (price-data (unwrap! (map-get? prices asset) ERR_ASSET_NOT_MAPPED))
    )
        (ok {
            price: (get price price-data),
            timestamp: (get last-updated price-data)
        })
    )
)

(define-public (update-price (asset principal) (price uint))
    (set-price asset price)
)
