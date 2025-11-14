;; ===========================================
;; ORACLE AGGREGATOR V2 TRAIT
;; ===========================================
;; @desc Interface for an enhanced oracle system with TWAP and manipulation detection.
;; This trait provides functions for time-weighted average pricing,
;; statistical manipulation detection, circuit breaker integration,
;; multi-source aggregation, and real-time monitoring.
;;
;; @example
;; (use-trait oracle-v2 .oracle-aggregator-v2-trait)
(define-trait oracle-aggregator-v2-trait
  (
    ;; @desc Get the time-weighted average price for a given asset pair.
    ;; @param token-a: The principal of the first token.
    ;; @param token-b: The principal of the second token.
    ;; @param period: The observation period in blocks.
    ;; @returns (response uint uint): The TWAP price, or an error code.
    (get-twap-price (principal principal uint) (response uint uint))

    ;; @desc Check for price manipulation using statistical deviation analysis.
    ;; @param token-a: The principal of the first token.
    ;; @param token-b: The principal of the second token.
    ;; @returns (response bool uint): True if manipulation is detected, false otherwise, or an error code.
    (detect-manipulation (principal principal) (response bool uint))

    ;; @desc Get the aggregated price from multiple sources with weighted confidence.
    ;; @param token-a: The principal of the first token.
    ;; @param token-b: The principal of the second token.
    ;; @returns (response uint uint): The aggregated price, or an error code.
    (get-aggregated-price (principal principal) (response uint uint))

    ;; @desc Set the circuit breaker status for a given asset pair.
    ;; @param token-a: The principal of the first token.
    ;; @param token-b: The principal of the second token.
    ;; @param status: True to activate, false to deactivate.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (set-circuit-breaker-status (principal principal bool) (response bool uint))

    ;; @desc Get the real-time price for a given asset pair.
    ;; @param token-a: The principal of the first token.
    ;; @param token-b: The principal of the second token.
    ;; @returns (response uint uint): The real-time price, or an error code.
    (get-real-time-price (principal principal) (response uint uint))
  )
)
