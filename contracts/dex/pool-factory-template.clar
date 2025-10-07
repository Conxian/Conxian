(use-trait dex-factory-trait .all-traits.dex-factory-trait)
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)

(define-constant DEX-FACTORY-CONTRACT (contract-of .dex-factory))

(define-public (create-pool-internal (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (token-a-amount uint) (token-b-amount uint) (factory-contract <dex-factory-trait>))
  (contract-call? factory-contract create-pool-internal token-a token-b token-a-amount token-b-amount)
)

