;; enterprise-facade.clar
;;
;; This contract is the single, secure entry point for all institutional-grade
;; operations in the Conxian Protocol. It is a facade that delegates all logic to
;; a set of specialized, single-responsibility manager contracts.

(use-trait account-manager .enterprise-traits.account-manager-trait)
(use-trait compliance-manager .enterprise-traits.compliance-manager-trait)
(use-trait advanced-order-manager .enterprise-traits.advanced-order-manager-trait)
(use-trait protocol-support-trait .core-traits.protocol-support-trait)

(define-constant ERR_PROTOCOL_PAUSED (err u5001))

(define-data-var account-manager-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.institutional-account-manager)
(define-data-var compliance-manager-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.compliance-manager)
(define-data-var advanced-order-manager-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.advanced-order-manager)
(define-data-var protocol-coordinator principal tx-sender)

(define-private (is-protocol-paused)
  (contract-call? (var-get protocol-coordinator) is-protocol-paused)
)

(define-public (register-account (account principal) (tier uint) (limit uint))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (contract-call? (var-get account-manager-address) register-account account tier limit)
  )
)

(define-public (submit-twap-order (token-in principal) (token-out principal) (total-amount uint) (interval-blocks uint) (num-intervals uint))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (try! (contract-call? (var-get compliance-manager-address) check-kyc-compliance tx-sender))
    (try! (contract-call? (var-get account-manager-address) check-and-update-daily-spent tx-sender total-amount))
    (contract-call? (var-get advanced-order-manager-address) submit-twap-order token-in token-out total-amount interval-blocks num-intervals)
  )
)

(define-public (submit-iceberg-order (token-in principal) (token-out principal) (total-amount uint) (visible-amount uint))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (try! (contract-call? (var-get compliance-manager-address) check-kyc-compliance tx-sender))
    (try! (contract-call? (var-get account-manager-address) check-and-update-daily-spent tx-sender total-amount))
    (contract-call? (var-get advanced-order-manager-address) submit-iceberg-order token-in token-out total-amount visible-amount)
  )
)

(define-data-var contract-owner principal tx-sender)

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-public (set-protocol-coordinator (new-coordinator principal))
  (begin
    (asserts! (is-contract-owner) (err u1000))
    (var-set protocol-coordinator new-coordinator)
    (ok true)
  )
)
