;; oracle.clar
;; Provides price feeds for various assets

;; Traits
(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(use-trait oracle-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.oracle-trait)
(use-trait access-control-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.access-control-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_PRICE (err u101))

;; Data Maps
(define-map asset-prices {
  asset: principal
} {
  price: uint,
  last-updated: uint
})

;; Data Variables
(define-data-var contract-owner principal tx-sender)

;; Public Functions
(define-public (set-price (asset principal) (price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set asset-prices { asset: asset } { price: price, last-updated: block-height })
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-price (asset principal))
  (ok (map-get? asset-prices { asset: asset }))
)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)