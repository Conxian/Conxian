(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)


(define-trait batch-auction-trait
  (
    (create-auction (token-sell <sip-010-ft-trait>) (token-buy <sip-010-ft-trait>) (amount uint) (duration uint) (response uint (err uint)))
    (place-bid (auction-id uint) (amount uint) (response bool (err uint)))
    (settle-auction (auction-id uint) (response bool (err uint)))
    (get-auction-status (auction-id uint) (response (tuple (status (string-ascii 32)) (total-bids uint)) (err uint)))
  )
)
