;; compliance-manager.clar
;;
;; Manages KYC/AML checks and other regulatory compliance logic.

(impl-trait .enterprise-traits.compliance-manager-trait)

(define-constant ERR_COMPLIANCE_FAIL (err u5002))
(define-constant ERR_UNAUTHORIZED (err u5000))

(define-data-var governance-contract (optional principal) none)
(define-data-var contract-owner principal tx-sender)

(define-public (set-governance-contract (gov principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set governance-contract (some gov))
    (ok true)
  )
)

(define-public (check-kyc-compliance (account principal))
  (let ((tier (unwrap!
      (contract-call? .kyc-registry get-kyc-tier account)
      ERR_COMPLIANCE_FAIL
    )))
    (asserts! (>= tier u1) ERR_COMPLIANCE_FAIL)
    (ok true)
  )
)
