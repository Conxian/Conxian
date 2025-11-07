(use-trait dimensional-oracle-trait .all-traits.dimensional-oracle-trait)

;; ===== Constants =====
(define-constant ERR_ASSET_NOT_FOUND (err u404))
(define-constant ERR_UNAUTHORIZED (err u401))

;; ===== Data Variables =====
(define-data-var admin principal tx-sender)

;; ===== Data Maps =====
(define-map mock-prices principal uint)

;; ===== Admin Functions =====
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-mock-price (token principal) (price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set mock-prices token price)
    (ok true)
  )
)

;; ===== Read-Only Functions =====
(define-read-only (get-price (token principal))
  (match (map-get? mock-prices token)
    price (ok price)
    ERR_ASSET_NOT_FOUND
  )
)