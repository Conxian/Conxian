;; SPDX-License-Identifier: TBD

;; Trait for a Dimensional Vault
;; This trait defines the standard interface for a dimensional vault contract, which manages assets in a multi-dimensional risk framework.
(define-trait dimensional-vault-trait
  (
    ;; @desc Supplies an asset to the vault, increasing the user's collateral.
    ;; @param amount uint The amount of the asset to supply, denominated in its smallest unit.
    ;; @param supplier principal The principal of the user supplying the asset.
    ;; @returns (response bool uint) A response indicating `(ok true)` on success, or an error.
    (supply (uint, principal) (response bool uint))

    ;; @desc Borrows an asset from the vault, increasing the user's debt.
    ;; @param amount uint The amount of the asset to borrow.
    ;; @param borrower principal The principal of the user borrowing the asset.
    ;; @returns (response bool uint) A response indicating `(ok true)` on success, or an error.
    (borrow (uint, principal) (response bool uint))

    ;; @desc Retrieves the amount of a specific asset that is currently available for borrowing.
    ;; @param asset principal The principal of the asset's contract.
    ;; @returns (response uint uint) A response containing the amount of available liquidity, or an error.
    (get-available-liquidity (principal) (response uint uint))
  )
)
