;; Vault state queries
(define-public (test-vault-state)
  (begin
    (print {
      total-balance: (unwrap-panic (contract-call? .vault get-total-balance)),
      total-shares: (unwrap-panic (contract-call? .vault get-total-shares)),
      admin: (unwrap-panic (contract-call? .vault get-admin)),
      paused: (unwrap-panic (contract-call? .vault get-paused))
    })
    (ok true)
  )
)