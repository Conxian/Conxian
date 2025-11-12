;; ===========================================
;; RISK ORACLE TRAIT
;; ===========================================
;; Interface for a risk oracle.
;;
;; This trait provides functions for calculating margin requirements,
;; liquidation prices, and checking position health.
;;
;; Example usage:
;;   (use-trait risk-oracle .risk-oracle-trait)
(define-trait risk-oracle-trait
  (
    ;; Calculate margin requirements for a position.
    ;; @param token-a: principal of the first token
    ;; @param token-b: principal of the second token
    ;; @param collateral-amount: amount of collateral
    ;; @return (response (tuple (initial-margin uint) (maintenance-margin uint) (max-leverage uint)) uint): margin requirements and error code
    (calculate-margin-requirements (principal uint uint) (response (tuple (initial-margin uint) (maintenance-margin uint) (max-leverage uint)) uint))

    ;; Get the liquidation price for a position.
    ;; @param position-details: tuple containing position size, entry price, and collateral
    ;; @param collateral-token: principal of the collateral token
    ;; @return (response (tuple (price uint) (threshold uint) (is-liquidatable bool)) uint): liquidation price and error code
    (get-liquidation-price ((tuple (size int) (entry-price uint) (collateral uint)) principal) (response (tuple (price uint) (threshold uint) (is-liquidatable bool)) uint))

    ;; Check the health of a position.
    ;; @param position-details: tuple containing position size, entry price, collateral, and last updated block
    ;; @param collateral-token: principal of the collateral token
    ;; @return (response (tuple (margin-ratio uint) (liquidation-price uint) (is-liquidatable bool) (health-factor uint) (pnl (tuple (unrealized uint) (roi uint))) (position (tuple (size int) (value uint) (collateral uint) (entry-price uint) (current-price uint)))) uint): position health metrics and error code
    (check-position-health ((tuple (size int) (entry-price uint) (collateral uint) (last-updated uint)) principal) (response (tuple (margin-ratio uint) (liquidation-price uint) (is-liquidatable bool) (health-factor uint) (pnl (tuple (unrealized uint) (roi uint))) (position (tuple (size int) (value uint) (collateral uint) (entry-price uint) (current-price uint)))) uint))
  )
)
