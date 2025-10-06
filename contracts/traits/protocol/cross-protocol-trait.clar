(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

(define-trait cross-protocol-trait
  (
    (bridge-assets (from-token <sip-010-ft-trait>) (to-protocol (string-ascii 64)) (amount uint) (response uint (err uint)))
    (get-bridge-status (tx-id (buff 32)) (response (tuple (status (string-ascii 32)) (amount uint)) (err uint)))
  )
)
