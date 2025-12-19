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
(define-constant ERR_ENTERPRISE_DISABLED (err u5003))

(define-data-var account-manager-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.institutional-account-manager)
(define-data-var compliance-manager-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.compliance-manager)
(define-data-var advanced-order-manager-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.advanced-order-manager)
(define-data-var protocol-coordinator principal tx-sender)
(define-data-var enterprise-active bool false)
(define-data-var governance-contract (optional principal) none)
(define-data-var contract-owner principal tx-sender)

(define-private (is-protocol-paused)
  (contract-call? .conxian-protocol is-protocol-paused)
)

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-authorized)
  (or
    (is-contract-owner)
    (match (var-get governance-contract)
      gov (is-eq tx-sender gov)
      false
    )
  )
)

(define-public (set-enterprise-active (active bool))
  (begin
    (asserts! (is-authorized) (err u1000))
    (var-set enterprise-active active)
    (ok true)
  )
)

(define-public (set-governance-contract (gov principal))
  (begin
    (asserts! (is-contract-owner) (err u1000))
    (var-set governance-contract (some gov))
    (ok true)
  )
)

(define-public (set-protocol-coordinator (new-coordinator principal))
  (begin
    (asserts! (is-contract-owner) (err u1000))
    (var-set protocol-coordinator new-coordinator)
    (ok true)
  )
)

(define-public (register-account
    (account principal)
    (tier uint)
    (limit uint)
  )
  (begin
    (asserts! (not (unwrap! (is-protocol-paused) ERR_PROTOCOL_PAUSED))
      ERR_PROTOCOL_PAUSED
    )
    (asserts! (var-get enterprise-active) ERR_ENTERPRISE_DISABLED)
    (contract-call? .institutional-account-manager register-account account tier
      limit
    )
  )
)

(define-public (submit-twap-order
    (token-in principal)
    (token-out principal)
    (total-amount uint)
    (interval-blocks uint)
    (num-intervals uint)
  )
  (begin
    (asserts! (not (unwrap! (is-protocol-paused) ERR_PROTOCOL_PAUSED))
      ERR_PROTOCOL_PAUSED
    )
    (asserts! (var-get enterprise-active) ERR_ENTERPRISE_DISABLED)
    (try! (contract-call? .compliance-manager check-kyc-compliance tx-sender))
    (try! (contract-call? .institutional-account-manager check-and-update-daily-spent
      tx-sender total-amount
    ))
    (contract-call? .advanced-order-manager submit-twap-order token-in token-out
      total-amount interval-blocks num-intervals
    )
  )
)

(define-public (submit-iceberg-order
    (token-in principal)
    (token-out principal)
    (total-amount uint)
    (visible-amount uint)
  )
  (begin
    (asserts! (not (unwrap! (is-protocol-paused) ERR_PROTOCOL_PAUSED))
      ERR_PROTOCOL_PAUSED
    )
    (asserts! (var-get enterprise-active) ERR_ENTERPRISE_DISABLED)
    (try! (contract-call? .compliance-manager check-kyc-compliance tx-sender))
    (try! (contract-call? .institutional-account-manager check-and-update-daily-spent
      tx-sender total-amount
    ))
    (contract-call? .advanced-order-manager submit-iceberg-order token-in
      token-out total-amount visible-amount
    )
  )
)
