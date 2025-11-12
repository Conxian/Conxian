;; ===========================================
;; PRICE INITIALIZER TRAIT
;; ===========================================
;; Interface for initializing asset prices
;;
;; This trait provides functions to set initial prices for assets
;; within the protocol, typically used during deployment or for new asset listings.
;;
;; Example usage:
;;   (use-trait price-initializer .price-initializer-trait.price-initializer-trait)
(define-trait price-initializer-trait
  (
    ;; Set the initial price for an asset
    ;; @param token: principal of the asset
    ;; @param price: initial price of the asset
    ;; @return (response bool uint): success flag and error code
    (set-initial-price (principal uint) (response bool uint))

    ;; Get the initial price of an asset
    ;; @param token: principal of the asset
    ;; @return (response (optional uint) uint): initial price or none, and error code
    (get-initial-price (principal) (response (optional uint) uint))
  )
)
