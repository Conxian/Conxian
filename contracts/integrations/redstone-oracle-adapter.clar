;; @contract RedStone Oracle Adapter
;; @version 1.0.0
;; @author Conxian Protocol
;; @desc Adapter to fetch prices from the RedStone oracle (mock/stub) on Stacks.
;; Implements the Conxian `oracle-trait`.

(use-trait oracle-trait .oracle-pricing.oracle-trait)

(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_ASSET_NOT_MAPPED (err u4004))
(define-constant ERR_NOT_SUPPORTED (err u9000))

(define-data-var contract-owner principal tx-sender)
(define-constant redstone-contract-principal .redstone-oracle-mock)

(define-map asset-ids
  principal
  (buff 32)
)

;; --- Admin Functions ---

(define-public (set-asset-id
    (asset principal)
    (id (buff 32))
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set asset-ids asset id)
    (ok true)
  )
)

;; --- Oracle Trait Implementation ---

(define-public (get-price (asset principal))
  (let (
      (id (unwrap! (map-get? asset-ids asset) ERR_ASSET_NOT_MAPPED))
      (price-data (try! (contract-call? .redstone-oracle-mock get-price-data id)))
    )
    (ok (get price price-data))
  )
)

(define-public (get-price-with-timestamp (asset principal))
  (let (
      (id (unwrap! (map-get? asset-ids asset) ERR_ASSET_NOT_MAPPED))
      (price-data (try! (contract-call? .redstone-oracle-mock get-price-data id)))
    )
    (ok {
      price: (get price price-data),
      timestamp: (get timestamp price-data),
    })
  )
)

(define-public (update-price
    (asset principal)
    (price uint)
  )
  ERR_NOT_SUPPORTED
)
