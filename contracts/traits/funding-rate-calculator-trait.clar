;; @desc A trait for calculating and updating funding rates.

(define-trait funding-rate-calculator-trait
  (
    ;; @desc Update the funding rate for an asset.
    ;; @param asset: The asset to update the funding rate for.
    ;; @returns (response { ... } uint): A tuple containing the new funding rate data, or an error code.
    (update-funding-rate (principal) (response {funding-rate: int, index-price: uint, timestamp: uint, cumulative-funding: int} uint))

    ;; @desc Apply funding to a position.
    ;; @param position-owner: The owner of the position.
    ;; @param position-id: The ID of the position.
    ;; @returns (response { ... } uint): A tuple containing the funding payment data, or an error code.
    (apply-funding-to-position (principal uint) (response {funding-rate: int, funding-payment: int, new-collateral: uint, timestamp: uint} uint))
  )
)
