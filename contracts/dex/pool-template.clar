(define-public (create-pool)
  (ok (as-contract (contract-call? .pool-factory-template create-pool-internal)))
)
