;; compliance-hooks.clar
;; Implementation of compliance hooks for the enterprise API

(impl-trait .compliance-hooks-trait.compliance-hooks-trait)

(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_ACCOUNT_NOT_VERIFIED (err u403))

(define-data-var contract-owner principal tx-sender)
(define-map verified-accounts principal bool)

(define-public (verify-account (account principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set verified-accounts account true)
    (ok true)
  )
)

(define-public (unverify-account (account principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-delete verified-accounts account)
    (ok true)
  )
)

(define-read-only (is-verified (account principal))
  (is-some (map-get? verified-accounts account))
)