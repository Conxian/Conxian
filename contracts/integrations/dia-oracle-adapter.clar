;; @contract DIA Oracle Adapter
;; @version 1.0.0
;; @author Conxian Protocol
;; @desc Adapter to fetch prices from the DIA oracle on Stacks.
;; Implements the Conxian `oracle-trait`.

(use-trait oracle-trait .oracle-pricing.oracle-trait)

(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_ASSET_NOT_MAPPED (err u4004))
(define-constant ERR_NOT_SUPPORTED (err u9000))

(define-data-var contract-owner principal tx-sender)
;; (define-data-var dia-contract-principal principal 'SP2KAF9RF86JSE6NE015235E519Z74H0278KCE24.dia-oracle) ;; Example Principal
(define-constant dia-contract-principal .dia-oracle-mock)

(define-map asset-keys
  principal
  (string-ascii 32)
)

;; --- Admin Functions ---

(define-public (set-asset-key
    (asset principal)
    (key (string-ascii 32))
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set asset-keys asset key)
    (ok true)
  )
)

;; --- Oracle Trait Implementation ---

(define-public (get-price (asset principal))
  (let (
      (key (unwrap! (map-get? asset-keys asset) ERR_ASSET_NOT_MAPPED))
      ;; DIA usually returns (value uint) (timestamp uint)
      (price-data (try! (contract-call? .dia-oracle-mock get-value key)))
    )
    ;; Assuming DIA returns 8 decimals (standard for many oracles), need to normalize to 18
    (ok (normalize-price (get value price-data)))
  )
)

(define-public (get-price-with-timestamp (asset principal))
  (let (
      (key (unwrap! (map-get? asset-keys asset) ERR_ASSET_NOT_MAPPED))
      (price-data (try! (contract-call? .dia-oracle-mock get-value key)))
    )
    (ok {
      price: (normalize-price (get value price-data)),
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

;; --- Internal Helpers ---

(define-private (normalize-price (price uint))
  ;; Assuming DIA returns 8 decimals
  ;; We want 18 decimals
  (* price u10000000000)
)
