;; enterprise-traits.clar
;;
;; This file defines the standard traits for the Conxian Enterprise Module. These
;; traits ensure a clean, secure, and maintainable interface between the enterprise
;; facade and its specialized manager contracts.

;; --------------------------------------------------------------------------------
;; Account Manager Trait
;;
;; Manages the lifecycle of institutional accounts, including registration,
;; tiering, and permissions.
;; --------------------------------------------------------------------------------
(define-trait account-manager-trait
  (
    ;; register-account
    ;;
    ;; Registers a new institutional account with a specified tier and daily limit.
    ;;
    ;; @param account: The principal of the account to register.
    ;; @param tier: The access tier for the account.
    ;; @param limit: The daily transaction limit for the account.
    ;;
    ;; @returns (response bool)
    (register-account (principal uint uint) (response bool uint))

    ;; check-and-update-daily-spent
    ;;
    ;; Checks if an account has exceeded its daily limit and updates the spent amount.
    ;;
    ;; @param account: The principal of the account to check.
    ;; @param amount: The transaction amount to check against the daily limit.
    ;;
    ;; @returns (response bool)
    (check-and-update-daily-spent (principal uint) (response bool uint))
  )
)

;; --------------------------------------------------------------------------------
;; Compliance Manager Trait
;;
;; Manages KYC/AML checks and other regulatory compliance logic.
;; --------------------------------------------------------------------------------
(define-trait compliance-manager-trait
  (
    ;; check-kyc-compliance
    ;;
    ;; Verifies if an account is KYC compliant.
    ;;
    ;; @param account: The principal of the account to check.
    ;;
    ;; @returns (response bool)
    (check-kyc-compliance (principal) (response bool uint))
  )
)

;; --------------------------------------------------------------------------------
;; Advanced Order Manager Trait
;;
;; Manages the lifecycle of sophisticated order types, such as TWAP and Iceberg
;; orders.
;; --------------------------------------------------------------------------------
(define-trait advanced-order-manager-trait
  (
    ;; submit-twap-order
    ;;
    ;; Submits a new Time-Weighted Average Price (TWAP) order.
    ;;
    ;; @param token-in: The principal of the input token.
    ;; @param token-out: The principal of the output token.
    ;; @param total-amount: The total amount to be traded.
    ;; @param interval-blocks: The number of blocks between each trade.
    ;; @param num-intervals: The total number of trades.
    ;;
    ;; @returns (response uint) The ID of the new order.
    (submit-twap-order (principal principal uint uint uint) (response uint uint))

    ;; submit-iceberg-order
    ;;
    ;; Submits a new Iceberg order.
    ;;
    ;; @param token-in: The principal of the input token.
    ;; @param token-out: The principal of the output token.
    ;; @param total-amount: The total amount to be traded.
    ;; @param visible-amount: The amount to be publicly visible in the order book.
    ;;
    ;; @returns (response uint) The ID of the new order.
    (submit-iceberg-order (principal principal uint uint) (response uint uint))
  )
)