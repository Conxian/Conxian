;; Yield Optimizer
;; Automated strategy selection and allocation

(use-trait vault-trait .defi-traits.vault-trait)

(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_INVALID_STRATEGY (err u6001))

(define-data-var contract-owner principal tx-sender)

(define-map strategies
    { strategy: principal }
    { active: bool, apy: uint, risk-score: uint }
)

(define-public (add-strategy (strategy principal) (apy uint) (risk uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map-set strategies { strategy: strategy } { active: true, apy: apy, risk-score: risk })
        (ok true)
    )
)

(define-public (optimize-allocation (vault <vault-trait>) (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        ;; Placeholder: Logic to pick best strategy would go here.
        ;; For now, we just allocate to the vault itself or a sub-strategy.
        (contract-call? vault allocate-to-strategy tx-sender amount)
    )
)
