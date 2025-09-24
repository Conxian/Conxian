;; Mock Oracle
;; A simple mock implementation of the oracle trait for testing

(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.oracle-trait)

(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PRICE (err u101))
(define-constant ERR_TOKEN_NOT_FOUND (err u102))

;; Admin address
(define-data-var admin principal tx-sender)

;; Mock price data
(define-map mock-prices
  { token: principal }  ;; Token principal
  {
    price: uint,        ;; Price with 8 decimals
    last-updated: uint,  ;; Block height
    deviation: uint      ;; Deviation threshold in basis points (e.g., 500 = 5%)
  }
)

;; ========== Admin Functions ==========

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-mock-price (token principal) (price uint) (deviation uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (asserts! (> price u0) ERR_INVALID_PRICE)
    (asserts! (<= deviation u10000) ERR_INVALID_PRICE)  ;; Max 100% deviation

    (map-set mock-prices
      {token: token}
      {
        price: price,
        last-updated: block-height,
        deviation: deviation
      }
    )
    (ok true)
  )
)

;; ========== Oracle Trait Implementation ==========

(define-read-only (get-price (token principal))
  (match (map-get? mock-prices {token: token})
    price-data (ok (get price price-data))
    (err ERR_TOKEN_NOT_FOUND)
  )
)

(define-public (update-price (token principal) (price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (asserts! (> price u0) ERR_INVALID_PRICE)

    (match (map-get? mock-prices {token: token})
      price-data
      (begin
        (map-set mock-prices
          {token: token}
          (merge price-data {
            price: price,
            last-updated: block-height
          })
        )
        (ok true)
      )
      (err ERR_TOKEN_NOT_FOUND)
    )
  )
)

(define-read-only (get-last-updated (token principal))
  (match (map-get? mock-prices {token: token})
    price-data (ok (get last-updated price-data))
    (err ERR_TOKEN_NOT_FOUND)
  )
)

(define-read-only (get-deviation-threshold (token principal))
  (match (map-get? mock-prices {token: token})
    price-data (ok (get deviation price-data))
    (err ERR_TOKEN_NOT_FOUND)
  )
)

(define-read-only (is-price-stale (token principal))
  (match (map-get? mock-prices {token: token})
    price-data (ok false)  ;; Mock prices are never stale
    (ok true)  ;; If no price data, consider it stale
  )
)

(define-read-only (get-feed-count (token principal))
  (match (map-get? mock-prices {token: token})
    price-data (ok u1)  ;; Mock always has 1 feed
    (ok u0)
  )
)

;; Mock Oracle
;; A simple mock implementation of the oracle trait for testing

(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.oracle-trait)

(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PRICE (err u101))
(define-constant ERR_TOKEN_NOT_FOUND (err u102))

;; Admin address
(define-data-var admin principal tx-sender)

;; Mock price data
(define-map mock-prices
  { token: principal }  ;; Token principal
  {
    price: uint,        ;; Price with 8 decimals
    last-updated: uint,  ;; Block height
    deviation: uint      ;; Deviation threshold in basis points (e.g., 500 = 5%)
  }
)

;; ========== Admin Functions ==========

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-mock-price (token principal) (price uint) (deviation uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (asserts! (> price u0) ERR_INVALID_PRICE)
    (asserts! (<= deviation u10000) ERR_INVALID_PRICE)  ;; Max 100% deviation

    (map-set mock-prices
      {token: token}
      {
        price: price,
        last-updated: block-height,
        deviation: deviation
      }
    )
    (ok true)
  )
)

;; ========== Oracle Trait Implementation ==========

(define-read-only (get-price (token principal))
  (match (map-get? mock-prices {token: token})
    price-data (ok (get price price-data))
    (err ERR_TOKEN_NOT_FOUND)
  )
)

(define-public (update-price (token principal) (price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (asserts! (> price u0) ERR_INVALID_PRICE)

    (match (map-get? mock-prices {token: token})
      price-data
      (begin
        (map-set mock-prices
          {token: token}
          (merge price-data {
            price: price,
            last-updated: block-height
          })
        )
        (ok true)
      )
      (err ERR_TOKEN_NOT_FOUND)
    )
  )
)

(define-read-only (get-last-updated (token principal))
  (match (map-get? mock-prices {token: token})
    price-data (ok (get last-updated price-data))
    (err ERR_TOKEN_NOT_FOUND)
  )
)

(define-read-only (get-deviation-threshold (token principal))
  (match (map-get? mock-prices {token: token})
    price-data (ok (get deviation price-data))
    (err ERR_TOKEN_NOT_FOUND)
  )
)

(define-read-only (is-price-stale (token principal))
  (match (map-get? mock-prices {token: token})
    price-data (ok false)  ;; Mock prices are never stale
    (ok true)  ;; If no price data, consider it stale
  )
)

(define-read-only (get-feed-count (token principal))
  (match (map-get? mock-prices {token: token})
    price-data (ok u1)  ;; Mock always has 1 feed
    (ok u0)
  )
)

(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-public (set-admin-trait (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; ========== Unimplemented Functions (for interface compliance) ==========

(define-public (add-price-feed (token principal) (feed principal))
  (ok true)  ;; No-op in mock
)

(define-public (remove-price-feed (token principal))
  (ok true)  ;; No-op in mock
)

(define-public (set-heartbeat (token principal) (interval uint))
  (ok true)  ;; No-op in mock
)

(define-public (set-max-deviation (token principal) (deviation uint))
  (ok true)  ;; No-op in mock
)

(define-public (emergency-price-override (token principal) (price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (set-mock-price token price u1000)  ;; 10% deviation
  )
)
