;; ===========================================
;; LENDING SYSTEM TRAIT
;; ===========================================
;; @desc Interface for a decentralized lending system.
;; This trait provides functions for depositing collateral, borrowing assets,
;; repaying loans, and managing liquidation processes.
;;
;; @example
;; (use-trait lending-system .lending-system-trait.lending-system-trait)
(define-trait lending-system-trait
  (
    ;; @desc Deposit collateral into the lending system.
    ;; @param token: The principal of the collateral token.
    ;; @param amount: The amount of collateral to deposit.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (deposit-collateral (principal uint) (response bool uint))

    ;; @desc Borrow assets from the lending system.
    ;; @param token: The principal of the asset to borrow.
    ;; @param amount: The amount of the asset to borrow.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (borrow (principal uint) (response bool uint))

    ;; @desc Repay a loan.
    ;; @param token: The principal of the asset to repay.
    ;; @param amount: The amount to repay.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (repay (principal uint) (response bool uint))

    ;; @desc Liquidate an unhealthy loan.
    ;; @param borrower: The principal of the borrower with the unhealthy loan.
    //; @param collateral-token: The principal of the collateral token.
    ;; @param debt-token: The principal of the debt token.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (liquidate (principal principal principal) (response bool uint))

    ;; @desc Get the current loan details for a borrower.
    ;; @param borrower: The principal of the borrower.
    ;; @returns (response (tuple ...) uint): A tuple containing the loan details, or an error code.
    (get-loan-details (principal) (response (tuple (collateral-amount uint) (borrowed-amount uint) (collateral-token principal) (debt-token principal) (health-factor uint)) uint))
  )
)
