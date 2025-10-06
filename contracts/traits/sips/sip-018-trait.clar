(define-trait sip-018-trait
  (
    (transfer (token-id uint) (amount uint) (sender principal) (recipient principal) (response bool (err uint)))
    (transfer-memo (token-id uint) (amount uint) (sender principal) (recipient principal) (memo (buff 34)) (response bool (err uint)))
    (get-balance (token-id uint) (user principal) (response uint (err uint)))
    (get-overall-balance (user principal) (response uint (err uint)))
    (get-total-supply (token-id uint) (response uint (err uint)))
    (get-overall-supply () (response uint (err uint)))
    (get-decimals (token-id uint) (response uint (err uint)))
    (get-token-uri (token-id uint) (response (optional (string-utf8 256)) (err uint)))
  )
)
