(define-public (create-pool-internal)
  (ok (as-contract (contract-call? .dex-factory create-pool-internal)))
)
