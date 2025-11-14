;; ===========================================
;; PRICE INITIALIZER TRAIT
;; ===========================================
;; @desc Interface for initializing asset prices.
;; This trait provides functions to set initial prices for assets
;; within the protocol, typically used during deployment or for new asset listings.
;;
;; @example
;; (use-trait price-initializer .price-initializer-trait.price-initializer-trait)
(define-trait price-initializer-trait
  (
    ;; @desc Set the initial price for an asset.
    ;; @param token: The principal of the asset.
    ;; @param price: The initial price of the asset.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (set-initial-price (principal uint) (response bool uint))

    ;; @desc Get the initial price of an asset.
    ;; @param token: The principal of the asset.
    ;; @returns (response (optional uint) uint): The initial price of the asset, or none if it hasn't been set.
    (get-initial-price (principal) (response (optional uint) uint))
  )
)
