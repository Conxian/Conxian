;; ===========================================
;; DIMENSIONAL ORACLE TRAIT
;; ===========================================
;; Interface for price oracle functionality.
;;
;; This trait provides functions to get and update asset prices.
;;
;; Example usage:
;;   (use-trait oracle-trait .dimensional-oracle-trait.dimensional-oracle-trait)
(define-trait dimensional-oracle-trait
  (
    ;; @desc Gets the current price of an asset.
    ;; @param asset The token address to get the price for.
    ;; @returns (response uint uint) The price and an error code.
    (get-price (asset principal)) (response uint uint))

    ;; @desc Updates the price of an asset (admin only).
    ;; @param asset The token address to update the price for.
    ;; @param price The new price value.
    ;; @returns (response bool uint) True if successful, or an error.
    (update-price (asset principal) (price uint)) (response bool uint))

    ;; @desc Gets the price with timestamp information.
    ;; @param asset The token address to get the price for.
    ;; @returns (response { price: uint, timestamp: uint } uint) The price, timestamp, and an error code.
    (get-price-with-timestamp (asset principal)) (response { price: uint, timestamp: uint } uint))
  )
