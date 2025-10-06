(define-trait sip-010-ft-trait
  (
    (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))) (response bool (err uint)))
    (get-balance (account principal) (response uint (err uint)))
    (get-total-supply () (response uint (err uint)))
    (get-decimals () (response uint (err uint)))
    (get-name () (response (string-ascii 32) (err uint)))
    (get-symbol () (response (string-ascii 10) (err uint)))
    (get-token-uri () (response (optional (string-utf8 256)) (err uint)))
  )
)
