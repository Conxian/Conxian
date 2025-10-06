(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)


(define-trait cross-protocol-trait
  (
    (bridge-assets (from-token <sip-010-ft-trait>) (to-protocol (string-ascii 64)) (amount uint) (response uint (err uint)))
    (get-bridge-status (tx-id (buff 32)) (response (tuple (status (string-ascii 32)) (amount uint)) (err uint)))
  )
)
