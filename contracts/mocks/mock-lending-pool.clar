;; mock-lending-pool.clar
;; Minimal implementation of lending-pool-trait for testing liquidation-manager.

(use-trait lending-pool-trait .defi-traits.lending-pool-trait)

(impl-trait .defi-traits.lending-pool-trait)

(define-data-var health-factor uint u2000000000000000000) ;; default > 1e18 (healthy)

(define-public (set-health-factor (hf uint))
  (begin
    (var-set health-factor hf)
    (ok true)
  )
)

(define-read-only (get-health-factor (borrower principal))
  (ok (var-get health-factor))
)

(define-public (update-position (borrower principal) (delta uint))
  (ok true)
)

(define-read-only (get-liquidation-amounts
    (borrower principal)
    (debt-asset principal)
    (collateral-asset principal)
    (debt-amount uint)
  )
  (ok { collateral-to-seize: debt-amount })
)

(define-public (liquidate
    (borrower principal)
    (debt-asset principal)
    (collateral-asset principal)
    (debt-amount uint)
    (collateral-to-seize uint)
  )
  (ok true)
)
