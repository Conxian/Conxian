(define-trait sip-010-ft-trait
  (
    (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))) (response bool uint))
    (get-balance (account principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-decimals () (response uint uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)
