(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

(define-trait pool-creation-trait
  (
    ;; @notice Create a new pool
    (create-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint) (pool-type (string-ascii 64)) (response principal (err uint)))

    ;; @notice Get a pool address by its tokens and fee
    (get-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint) (response (optional principal) (err uint)))

    ;; @notice Get all pools created by the factory
    (get-all-pools () (response (list 100 (tuple (token-a principal) (token-b principal) (fee-bps uint) (pool-address principal) (pool-type (string-ascii 64)))) (err uint)))

    ;; @notice Set a new pool implementation for a given pool type
    (set-pool-implementation (pool-type (string-ascii 64)) (implementation-contract principal) (response bool (err uint)))

    ;; @notice Get the pool implementation for a given pool type
    (get-pool-implementation (pool-type (string-ascii 64)) (response (optional principal) (err uint)))
  )
)
