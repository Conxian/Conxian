;; ===========================================
;; LENDING SYSTEM TRAIT
;; ===========================================
;; Interface for a decentralized lending system
;;
;; This trait provides functions for depositing collateral, borrowing assets,
;; repaying loans, and managing liquidation processes.
;;
;; Example usage:
;;   (use-trait lending-system .lending-system-trait.lending-system-trait)
(define-trait lending-system-trait
  (
    ;; Deposit collateral into the lending system
    ;; @param token: principal of the collateral token
    ;; @param amount: amount of collateral to deposit
    ;; @return (response bool uint): success flag and error code
    (deposit-collateral (principal uint) (response bool uint))

    ;; Borrow assets from the lending system
    ;; @param token: principal of the asset to borrow
    ;; @param amount: amount of asset to borrow
    ;; @return (response bool uint): success flag and error code
    (borrow (principal uint) (response bool uint))

    ;; Repay a loan
    ;; @param token: principal of the asset to repay
    ;; @param amount: amount to repay
    ;; @return (response bool uint): success flag and error code
    (repay (principal uint) (response bool uint))

    ;; Liquidate an unhealthy loan
    ;; @param borrower: principal of the borrower with the unhealthy loan
    ;; @param collateral-token: principal of the collateral token
    ;; @param debt-token: principal of the debt token
    ;; @return (response bool uint): success flag and error code
    (liquidate (principal principal principal) (response bool uint))

    ;; Get current loan details for a borrower
    ;; @param borrower: principal of the borrower
    ;; @return (response (tuple ...) uint): loan details and error code
    (get-loan-details (principal) (response (tuple (collateral-amount uint) (borrowed-amount uint) (collateral-token principal) (debt-token principal) (health-factor uint)) uint))
  )
)
