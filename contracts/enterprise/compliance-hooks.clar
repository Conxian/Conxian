;; compliance-hooks.clar
;; Provides compliance hooks for the Conxian DEX.

(define-constant ERR_UNAUTHORIZED (err u7000))

(define-public (check-kyc (user principal))
  (let ((kyc-tier (unwrap! (contract-call? .kyc-registry get-kyc-tier user) ERR_UNAUTHORIZED)))
    (asserts! (>= kyc-tier u1) ERR_UNAUTHORIZED)
    (ok true)
  )
)

(define-public (check-aml (user principal))
  (let ((status (unwrap! (contract-call? .kyc-registry get-identity-status user) ERR_UNAUTHORIZED)))
    ;; Check if Sanctioned bit (0x2) is set
    (asserts! (is-eq (mod (/ (get status-flags status) u2) u2) u0) ERR_UNAUTHORIZED)
    (ok true)
  )
)
