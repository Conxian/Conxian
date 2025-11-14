;; @desc A trait for managing risk in the dimensional engine.

(define-trait risk-manager-trait
  (
    ;; @desc Set the risk parameters.
    ;; @param new-max-leverage: The new maximum leverage.
    ;; @param new-maintenance-margin: The new maintenance margin.
    ;; @param new-liquidation-threshold: The new liquidation threshold.
    ;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
    (set-risk-parameters (uint uint uint) (response bool uint))

    ;; @desc Set the liquidation rewards.
    ;; @param min-reward: The minimum liquidation reward.
    ;; @param max-reward: The maximum liquidation reward.
    ;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
    (set-liquidation-rewards (uint uint) (response bool uint))

    ;; @desc Set the insurance fund.
    ;; @param fund: The principal of the insurance fund.
    ;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
    (set-insurance-fund (principal) (response bool uint))

    ;; @desc Calculate the liquidation price of a position.
    ;; @param position: The position to calculate the liquidation price for.
    ;; @returns (uint): The liquidation price.
    (calculate-liquidation-price ({entry-price: uint, leverage: uint, is-long: bool}) (response uint uint))
  )
)
