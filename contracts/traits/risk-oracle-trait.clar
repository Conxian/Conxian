;; ===========================================
;; RISK ORACLE TRAIT
;; ===========================================
;; @desc Interface for a risk oracle.
;; This trait provides functions for calculating margin requirements,
;; liquidation prices, and checking position health.
;;
;; @example
;; (use-trait risk-oracle .risk-oracle-trait)
(define-trait risk-oracle-trait
  (
    ;; @desc Calculate the margin requirements for a position.
    ;; @param token-a: The principal of the first token.
    ;; @param token-b: The principal of the second token.
    ;; @param collateral-amount: The amount of collateral.
    ;; @returns (response (tuple (initial-margin uint) (maintenance-margin uint) (max-leverage uint)) uint): A tuple containing the margin requirements, or an error code.
    (calculate-margin-requirements (principal uint uint) (response (tuple (initial-margin uint) (maintenance-margin uint) (max-leverage uint)) uint))

    ;; @desc Get the liquidation price for a position.
    ;; @param position-details: A tuple containing the position size, entry price, and collateral.
    ;; @param collateral-token: The principal of the collateral token.
    ;; @returns (response (tuple (price uint) (threshold uint) (is-liquidatable bool)) uint): A tuple containing the liquidation price, or an error code.
    (get-liquidation-price ((tuple (size int) (entry-price uint) (collateral uint)) principal) (response (tuple (price uint) (threshold uint) (is-liquidatable bool)) uint))

    ;; @desc Check the health of a position.
    ;; @param position-details: A tuple containing the position size, entry price, collateral, and last updated block.
    ;; @param collateral-token: The principal of the collateral token.
    ;; @returns (response (tuple ...) uint): A tuple containing the position health metrics, or an error code.
    (check-position-health ((tuple (size int) (entry-price uint) (collateral uint) (last-updated uint)) principal) (response (tuple (margin-ratio uint) (liquidation-price uint) (is-liquidatable bool) (health-factor uint) (pnl (tuple (unrealized uint) (roi uint))) (position (tuple (size int) (value uint) (collateral uint) (entry-price uint) (current-price uint)))) uint))
  )
)
