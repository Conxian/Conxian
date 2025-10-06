(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

(define-trait factory-trait
  (
    (create-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint) (pool-type (string-ascii 64)) (response principal (err uint)))
    (get-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint) (response (optional principal) (err uint)))
    (get-pool-count () (response uint (err uint)))
    (register-pool-implementation (pool-type (string-ascii 64)) (implementation-contract principal) (response bool (err uint)))
  )
)
