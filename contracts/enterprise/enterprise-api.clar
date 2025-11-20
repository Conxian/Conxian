;; enterprise-api.clar
;; Provides enterprise-grade features for the Conxian DEX.

(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_ACCOUNT_NOT_FOUND (err u6001))
(define-constant ERR_INVALID_TIER (err u6002))

(define-map enterprise-accounts { user: principal } {
  tier: uint,
  kyc-status: bool
})

(define-public (register-account (user principal) (tier uint))
  (begin
    (asserts! (is-eq tx-sender .admin) ERR_UNAUTHORIZED)
    (map-set enterprise-accounts { user: user } { tier: tier, kyc-status: false })
    (ok true)
  )
)

(define-public (set-kyc-status (user principal) (status bool))
  (begin
    (asserts! (is-eq tx-sender .compliance-officer) ERR_UNAUTHORIZED)
    (let ((account (unwrap! (map-get? enterprise-accounts { user: user }) ERR_ACCOUNT_NOT_FOUND)))
      (map-set enterprise-accounts { user: user } (merge account { kyc-status: status }))
    )
    (ok true)
  )
)

(define-read-only (get-account-info (user principal))
  (map-get? enterprise-accounts { user: user })
)
