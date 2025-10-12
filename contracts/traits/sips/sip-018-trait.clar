(define-trait sip-018-trait
  (
    (get-balance (token-id uint) (user principal) (response uint uint))
    (get-overall-balance (user principal) (response uint uint))
    (get-total-supply (token-id uint) (response uint uint))
    (get-overall-supply () (response uint uint))
    (get-decimals (token-id uint) (response uint uint))
    (get-token-uri (token-id uint) (response (optional (string-ascii 256)) uint))
    (transfer (token-id uint) (amount uint) (sender principal) (recipient principal) (response bool uint))
    (transfer-memo (token-id uint) (amount uint) (sender principal) (recipient principal) (memo (buff 34)) (response bool uint))
  )
)
