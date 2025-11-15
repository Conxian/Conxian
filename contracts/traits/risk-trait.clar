;; ===========================================
;; RISK TRAIT
;; ===========================================
;; @desc Interface for risk management functionalities.
;; This trait provides functions to assess and manage various risks
;; within the DeFi protocol, such as liquidation risks, collateral ratios,
;; and system-wide risk parameters.
;;
;; @example
;; (use-trait risk .risk-trait.risk-trait)
(define-trait risk-trait
  (
    ;; @desc Assess the liquidation risk for a given position.
    ;; @param position-id: The ID of the position to assess.
    ;; @returns (response (tuple ...) uint): A tuple containing the risk assessment details, or an error code.
    (assess-liquidation-risk (uint) (response (tuple (is-liquidatable bool) (collateral-ratio uint) (liquidation-price uint)) uint))

    ;; @desc Update the system-wide risk parameters (governance only).
    ;; @param new-collateral-factor: The new collateral factor.
    ;; @param new-liquidation-threshold: The new liquidation threshold.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (update-risk-parameters (uint uint) (response bool uint))

    ;; @desc Get the current system-wide risk parameters.
    ;; @returns (response (tuple ...) uint): A tuple containing the current risk parameters, or an error code.
    (get-risk-parameters () (response (tuple (collateral-factor uint) (liquidation-threshold uint)) uint))

    ;; @desc Check if a position is healthy.
    ;; @param position-id: The ID of the position.
    ;; @returns (response bool uint): True if the position is healthy, false otherwise, or an error code.
    (is-position-healthy (uint) (response bool uint))
  )
)
