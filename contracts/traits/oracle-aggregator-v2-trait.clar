;; ===========================================
;; ORACLE AGGREGATOR V2 TRAIT
;; ===========================================
;; Interface for an enhanced oracle system with TWAP and manipulation detection.
;;
;; This trait provides functions for time-weighted average pricing,
;; statistical manipulation detection, circuit breaker integration,
;; multi-source aggregation, and real-time monitoring.
;;
;; Example usage:
;;   (use-trait oracle-v2 .oracle-aggregator-v2-trait)
(define-trait oracle-aggregator-v2-trait
  (
    ;; Get the time-weighted average price for a given asset pair.
    ;; @param token-a: principal of the first token
    ;; @param token-b: principal of the second token
    ;; @param period: observation period in blocks
    ;; @return (response uint uint): TWAP price and error code
    (get-twap-price (principal principal uint) (response uint uint))

    ;; Check for price manipulation using statistical deviation analysis.
    ;; @param token-a: principal of the first token
    ;; @param token-b: principal of the second token
    ;; @return (response bool uint): true if manipulation detected, false otherwise, and error code
    (detect-manipulation (principal principal) (response bool uint))

    ;; Get the aggregated price from multiple sources with weighted confidence.
    ;; @param token-a: principal of the first token
    ;; @param token-b: principal of the second token
    ;; @return (response uint uint): aggregated price and error code
    (get-aggregated-price (principal principal) (response uint uint))

    ;; Set the circuit breaker status for a given asset pair.
    ;; @param token-a: principal of the first token
    ;; @param token-b: principal of the second token
    ;; @param status: true to activate, false to deactivate
    ;; @return (response bool uint): success flag and error code
    (set-circuit-breaker-status (principal principal bool) (response bool uint))

    ;; Get the real-time price for a given asset pair.
    ;; @param token-a: principal of the first token
    ;; @param token-b: principal of the second token
    ;; @return (response uint uint): real-time price and error code
    (get-real-time-price (principal principal) (response uint uint))
  )
)
