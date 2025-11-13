;; ===========================================
;; LIQUIDATION TRAIT
;; ===========================================
;; Interface for position liquidation functionality
;;
;; This trait provides functions for liquidating underwater positions,
;; batch liquidations, and position health monitoring.
;;
;; Example usage:
;;   (use-trait liquidation .liquidation-trait.liquidation-trait)
;;   (define-public (liquidate-user-position (liquidation-contract principal) (position-id uint))
;;     (contract-call? liquidation-contract liquidate-position tx-sender position-id max-slippage))
(define-trait liquidation-trait
  (
    ;; Liquidate a single position
    ;; @param position-owner: owner of the position to liquidate
    ;; @param position-id: position identifier
    ;; @param max-slippage: maximum allowed slippage
    ;; @return (response bool uint): success flag and error code
    (liquidate-position (principal uint uint) (response bool uint))

    ;; Liquidate multiple positions in batch
    ;; @param positions: list of positions to liquidate
    ;; @param max-slippage: maximum allowed slippage
    ;; @return (response (list 20 (tuple (owner principal) (id uint))) uint): liquidation results and error code
    (liquidate-positions ((list 20 (tuple (owner principal) (id uint))) uint) (response (list 20 (response bool uint)) uint))

    ;; Check position health status
    ;; @param position-owner: owner of the position
    ;; @param position-id: position identifier
    ;; @return (response (tuple ...) uint): health metrics and error code
    (check-position-health (principal uint) (response (tuple (margin-ratio uint) (liquidation-price uint) (current-price uint) (health-factor uint) (is-liquidatable bool)) uint))

    ;; Set liquidation reward parameters (admin only)
    ;; @param min-reward: minimum liquidation reward
    ;; @param max-reward: maximum liquidation reward
    ;; @return (response bool uint): success flag and error code
    (set-liquidation-rewards (uint uint) (response bool uint))

    ;; Set insurance fund address (admin only)
    ;; @param fund: new insurance fund address
    ;; @return (response bool uint): success flag and error code
    (set-insurance-fund (principal) (response bool uint))
  )
)
