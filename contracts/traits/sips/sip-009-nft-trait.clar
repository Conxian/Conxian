(define-trait sip-009-nft-trait
  (
    (get-last-token-id () (response uint (err uint)))
    (get-token-uri (token-id uint) (response (optional (string-utf8 256)) (err uint)))
    (get-owner (token-id uint) (response (optional principal) (err uint)))
    (transfer (token-id uint) (sender principal) (recipient principal) (response bool (err uint)))
  )
)
