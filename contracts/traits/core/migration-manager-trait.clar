(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

(define-trait migration-manager-trait
  (
    (initiate-migration (from-token <sip-010-ft-trait>) (to-token <sip-010-ft-trait>) (amount uint) (response bool (err uint)))
    (complete-migration (migration-id uint) (response bool (err uint)))
    (get-migration-status (migration-id uint) (response (tuple (status (string-ascii 32)) (from-amount uint) (to-amount uint)) (err uint)))
  )
)
