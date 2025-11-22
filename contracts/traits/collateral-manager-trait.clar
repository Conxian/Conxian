;; @desc A trait for managing collateral in the dimensional engine.

(define-trait collateral-manager-trait
  (
    ;; @desc Deposit funds into the internal ledger.
    ;; @param amount: The amount to deposit.
    ;; @param token: The token to deposit.
    ;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
    ;; @param token: The token to deposit.

    ;; @desc Withdraw funds from the internal ledger.
    ;; @param amount: The amount to withdraw.
    ;; @param token: The token to withdraw.
    ;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
    ;; @param token: The token to withdraw.

    ;; @desc Get the internal balance of a user.
    ;; @param user: The principal of the user.
    ;; @returns (response uint uint): The internal balance of the user.
    (get-balance (principal) (response uint uint))
  )
)
