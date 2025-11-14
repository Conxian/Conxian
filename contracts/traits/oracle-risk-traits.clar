;; ===========================================
;; ORACLE & RISK TRAITS MODULE
;; ===========================================
;; @desc Price feeds and risk management traits.
;; Critical for financial stability and accuracy.

;; ===========================================
;; ORACLE AGGREGATOR TRAIT
;; ===========================================
;; @desc Interface for an oracle aggregator.
(define-trait oracle-aggregator-v2-trait
  (
    ;; @desc Get the price of an asset.
    ;; @param asset: The asset to get the price of.
    ;; @returns (response uint uint): The price of the asset, or an error code.
    (get-price ((string-ascii 32)) (response uint uint))

    ;; @desc Get the volatility of the protocol.
    ;; @returns (response uint uint): The volatility of the protocol, or an error code.
    (get-volatility () (response uint uint))

    ;; @desc Update the price of an asset.
    ;; @param asset: The asset to update the price of.
    ;; @param price: The new price of the asset.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (update-price ((string-ascii 32) uint) (response bool uint))

    ;; @desc Get all prices.
    ;; @returns (response (list 20 { ... }) uint): A list of all asset prices, or an error code.
    (get-all-prices () (response (list 20 {asset: (string-ascii 32), price: uint}) uint))
  )
)

;; ===========================================
;; RISK TRAIT
;; ===========================================
;; @desc Interface for risk management.
(define-trait risk-trait
  (
    ;; @desc Set the maximum loan-to-value (LTV) ratio.
    ;; @param ltv: The new maximum LTV ratio.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (set-max-ltv (uint) (response bool uint))

    ;; @desc Set the liquidation threshold.
    ;; @param threshold: The new liquidation threshold.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (set-liquidation-threshold (uint) (response bool uint))

    ;; @desc Get the maximum loan-to-value (LTV) ratio.
    ;; @returns (response uint uint): The maximum LTV ratio, or an error code.
    (get-max-ltv () (response uint uint))

    ;; @desc Get the liquidation threshold.
    ;; @returns (response uint uint): The liquidation threshold, or an error code.
    (get-liquidation-threshold () (response uint uint))

    ;; @desc Calculate the liquidation price of a position.
    ;; @param collateral: The amount of collateral in the position.
    ;; @param debt: The amount of debt in the position.
    ;; @param is-long: A boolean indicating if the position is long or short.
    ;; @returns (response uint uint): The liquidation price of the position, or an error code.
    (calculate-liquidation-price (uint uint bool) (response uint uint))
  )
)

;; ===========================================
;; LIQUIDATION TRAIT
;; ===========================================
;; @desc Interface for liquidation.
(define-trait liquidation-trait
  (
    ;; @desc Liquidate a position.
    ;; @param owner: The owner of the position to liquidate.
    ;; @param collateral: The amount of collateral in the position.
    ;; @param debt: The amount of debt in the position.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (liquidate-position (principal uint uint) (response bool uint))

    ;; @desc Calculate the liquidation price of a position.
    ;; @param collateral: The amount of collateral in the position.
    ;; @param debt: The amount of debt in the position.
    ;; @param is-long: A boolean indicating if the position is long or short.
    ;; @returns (response uint uint): The liquidation price of the position, or an error code.
    (calculate-liquidation-price (uint uint bool) (response uint uint))

    ;; @desc Get the liquidation reward for a position.
    ;; @param position-value: The value of the position.
    ;; @returns (response uint uint): The liquidation reward, or an error code.
    (get-liquidation-reward (uint) (response uint uint))
  )
)
