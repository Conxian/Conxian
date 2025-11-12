;; ===========================================
;; FINANCE METRICS TRAIT
;; ===========================================
;; Interface for financial metrics and reporting
;;
;; This trait provides functions to record and retrieve various financial metrics
;; such as TVL, volume, fees, and other key performance indicators.
;;
;; Example usage:
;;   (use-trait finance-metrics .finance-metrics-trait.finance-metrics-trait)
(define-trait finance-metrics-trait
  (
    ;; Record total value locked (TVL)
    ;; @param token: principal of the token
    ;; @param amount: amount of TVL
    ;; @return (response bool uint): success flag and error code
    (record-tvl (principal uint) (response bool uint))

    ;; Record trading volume
    ;; @param token-a: principal of the first token
    ;; @param token-b: principal of the second token
    ;; @param volume: trading volume
    ;; @return (response bool uint): success flag and error code
    (record-volume (principal principal uint) (response bool uint))

    ;; Record fees collected
    ;; @param token: principal of the fee token
    ;; @param amount: amount of fees
    ;; @return (response bool uint): success flag and error code
    (record-fees (principal uint) (response bool uint))

    ;; Get current TVL for a token
    ;; @param token: principal of the token
    ;; @return (response uint uint): current TVL and error code
    (get-tvl (principal) (response uint uint))

    ;; Get total trading volume for a token pair
    ;; @param token-a: principal of the first token
    ;; @param token-b: principal of the second token
    ;; @return (response uint uint): total volume and error code
    (get-volume (principal principal) (response uint uint))

    ;; Log a compounding event
    ;; @param user: principal of the user
    ;; @param token: principal of the token being compounded
    ;; @param amount: amount compounded
    ;; @return (response bool uint): success flag and error code
    (log-compounding-event (principal principal uint) (response bool uint))
  )
)
