(use-trait oracle-trait .all-traits.oracle-trait)
(impl-trait oracle-trait)

;; Mock Oracle - Minimal implementation for testing

(define-constant ERR_ASSET_NOT_FOUND (err u404))
(define-constant ERR_UNAUTHORIZED (err u401))

(define-data-var admin principal tx-sender)
(define-map mock-prices { token: principal } { price: uint })

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
    (map-set mock-prices { token: token } { price: price })
    (ok true)
  )
)

(define-read-only (get-price (token principal))
  (match (map-get? mock-prices { token: token })
    entry (ok (get price entry))
    (err ERR_ASSET_NOT_FOUND)
  )
)