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
(define-trait account-manager-trait (
  (register-account
    (principal uint uint)
    (response bool uint)
  )
  (check-and-update-daily-spent
    (principal uint)
    (response bool uint)
  )
))

;; --------------------------------------------------------------------------------
;; Compliance Manager Trait
;;
;; Manages KYC/AML checks and other regulatory compliance logic.
;; --------------------------------------------------------------------------------
(define-trait compliance-manager-trait (
  (check-kyc-compliance
    (principal)
    (response bool uint)
  )
))

;; --------------------------------------------------------------------------------
;; Advanced Order Manager Trait
;;
;; Manages the lifecycle of sophisticated order types, such as TWAP and Iceberg
;; orders.
;; --------------------------------------------------------------------------------
(define-trait advanced-order-manager-trait (
  (submit-twap-order
    (principal principal uint uint uint)
    (response uint uint)
  )
  (submit-iceberg-order
    (principal principal uint uint)
    (response uint uint)
  )
))
