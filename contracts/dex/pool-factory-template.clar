(use-trait ft-trait ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(use-trait dex-factory-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.dex-factory-trait)

(define-constant DEX-FACTORY-CONTRACT (contract-of .dex-factory))

(define-public (create-pool-internal (token-a <ft-trait>) (token-b <ft-trait>) (token-a-amount uint) (token-b-amount uint) (factory-contract <dex-factory-trait>))
  (contract-call? factory-contract create-pool-internal token-a token-b token-a-amount token-b-amount)
)
