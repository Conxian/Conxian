;; @desc A trait for managing positions in the dimensional engine.

(define-trait position-manager-trait
  (
    ;; @desc Open a new position.
    ;; @param asset: The asset to open a position for.
    ;; @param collateral: The amount of collateral to use.
    ;; @param leverage: The leverage to use.
    ;; @param is-long: A boolean indicating if the position is long or short.
    ;; @param stop-loss: An optional stop-loss price.
    ;; @param take-profit: An optional take-profit price.
    ;; @returns (response uint uint): The ID of the new position, or an error code.
    (open-position (principal uint uint bool (optional uint) (optional uint)) (response uint uint))

    ;; @desc Close a position.
    ;; @param position-id: The ID of the position to close.
    ;; @param slippage: An optional slippage value.
    ;; @returns (response { ... } uint): A tuple containing the collateral returned and the P&L, or an error code.
    (close-position (uint (optional uint)) (response {collateral-returned: uint, pnl: int} uint))

    ;; @desc Get a position.
    ;; @param position-id: The ID of the position to get.
    ;; @returns (response { ... } uint): A tuple containing the position data, or an error code.
    (get-position (uint) (response {owner: principal, asset: principal, collateral: uint, size: uint, entry-price: uint, leverage: uint, is-long: bool, funding-rate: int, last-updated: uint, stop-loss: (optional uint), take-profit: (optional uint), is-active: bool} uint))

    ;; @desc Update a position.
    ;; @param position-id: The ID of the position to update.
    ;; @param collateral: An optional new collateral amount.
    ;; @param leverage: An optional new leverage amount.
    ;; @param stop-loss: An optional new stop-loss price.
    ;; @param take-profit: An optional new take-profit price.
    ;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
    (update-position (uint (optional uint) (optional uint) (optional uint) (optional uint)) (response bool uint))
  )
)
