;; ===========================================
;; LIQUIDATION TRAIT
;; ===========================================
;; @desc Interface for position liquidation functionality.
;; This trait provides functions for liquidating underwater positions,
;; batch liquidations, and position health monitoring.
;;
;; @example
;; (use-trait liquidation .liquidation-trait.liquidation-trait)
;; (define-public (liquidate-user-position (liquidation-contract principal) (position-id uint))
;;   (contract-call? liquidation-contract liquidate-position tx-sender position-id max-slippage))
(define-trait liquidation-trait
  (
    ;; @desc Liquidate a single position.
    ;; @param position-owner: The owner of the position to liquidate.
    ;; @param position-id: The identifier of the position.
    ;; @param max-slippage: The maximum allowed slippage.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (liquidate-position (principal uint uint) (response bool uint))

    ;; @desc Liquidate multiple positions in a batch.
    ;; @param positions: A list of positions to liquidate.
    ;; @param max-slippage: The maximum allowed slippage.
    ;; @returns (response (list 20 (response bool uint)) uint): A list of the liquidation results, or an error code.
    (liquidate-positions ((list 20 (tuple (owner principal) (id uint))) uint) (response (list 20 (response bool uint)) uint))

    ;; @desc Check the health status of a position.
    ;; @param position-owner: The owner of the position.
    ;; @param position-id: The identifier of the position.
    ;; @returns (response (tuple ...) uint): A tuple containing the health metrics, or an error code.
    (check-position-health (principal uint) (response (tuple (margin-ratio uint) (liquidation-price uint) (current-price uint) (health-factor uint) (is-liquidatable bool)) uint))

    ;; @desc Set the liquidation reward parameters (admin only).
    ;; @param min-reward: The minimum liquidation reward.
    ;; @param max-reward: The maximum liquidation reward.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (set-liquidation-rewards (uint uint) (response bool uint))

    ;; @desc Set the insurance fund address (admin only).
    ;; @param fund: The new insurance fund address.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (set-insurance-fund (principal) (response bool uint))
  )
)
