(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)


(define-trait asset-vault-trait
  (
    (deposit (token <sip-010-ft-trait>) (amount uint) (response uint (err uint)))
    (withdraw (token <sip-010-ft-trait>) (amount uint) (response uint (err uint)))
    (get-balance (token <sip-010-ft-trait>) (user principal) (response uint (err uint)))
    (get-total-assets (token <sip-010-ft-trait>) (response uint (err uint)))
  )
)
