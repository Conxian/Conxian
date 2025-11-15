;; ===========================================
;; FINANCE METRICS TRAIT
;; ===========================================
;; @desc Interface for financial metrics and reporting.
;; This trait provides functions to record and retrieve various financial metrics
;; such as TVL, volume, fees, and other key performance indicators.
;;
;; @example
;; (use-trait finance-metrics .finance-metrics-trait.finance-metrics-trait)
(define-trait finance-metrics-trait
  (
    ;; @desc Record the total value locked (TVL).
    ;; @param token: The principal of the token.
    ;; @param amount: The amount of the TVL.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (record-tvl (principal uint) (response bool uint))

    ;; @desc Record the trading volume.
    ;; @param token-a: The principal of the first token.
    ;; @param token-b: The principal of the second token.
    ;; @param volume: The trading volume.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (record-volume (principal principal uint) (response bool uint))

    ;; @desc Record the fees collected.
    ;; @param token: The principal of the fee token.
    ;; @param amount: The amount of fees.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (record-fees (principal uint) (response bool uint))

    ;; @desc Get the current TVL for a token.
    ;; @param token: The principal of the token.
    ;; @returns (response uint uint): The current TVL, or an error code.
    (get-tvl (principal) (response uint uint))

    ;; @desc Get the total trading volume for a token pair.
    ;; @param token-a: The principal of the first token.
    ;; @param token-b: The principal of the second token.
    ;; @returns (response uint uint): The total volume, or an error code.
    (get-volume (principal principal) (response uint uint))

    ;; @desc Log a compounding event.
    ;; @param user: The principal of the user.
    ;; @param token: The principal of the token being compounded.
    ;; @param amount: The amount compounded.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (log-compounding-event (principal principal uint) (response bool uint))
  )
)
