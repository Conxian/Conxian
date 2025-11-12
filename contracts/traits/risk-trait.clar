;; ===========================================
;; RISK TRAIT
;; ===========================================
;; Interface for risk management functionalities
;;
;; This trait provides functions to assess and manage various risks
;; within the DeFi protocol, such as liquidation risks, collateral ratios,
;; and system-wide risk parameters.
;;
;; Example usage:
;;   (use-trait risk .risk-trait.risk-trait)
(define-trait risk-trait
  (
    ;; Assess liquidation risk for a given position
    ;; @param position-id: ID of the position to assess
    ;; @return (response (tuple ...) uint): risk assessment details and error code
    (assess-liquidation-risk (uint) (response (tuple (is-liquidatable bool) (collateral-ratio uint) (liquidation-price uint)) uint))

    ;; Update system-wide risk parameters (governance only)
    ;; @param new-collateral-factor: new collateral factor
    ;; @param new-liquidation-threshold: new liquidation threshold
    ;; @return (response bool uint): success flag and error code
    (update-risk-parameters (uint uint) (response bool uint))

    ;; Get current system-wide risk parameters
    ;; @return (response (tuple ...) uint): current risk parameters and error code
    (get-risk-parameters () (response (tuple (collateral-factor uint) (liquidation-threshold uint)) uint))

    ;; Check if a position is healthy
    ;; @param position-id: ID of the position
    ;; @return (response bool uint): true if healthy, false otherwise, and error code
    (is-position-healthy (uint) (response bool uint))
  )
)
