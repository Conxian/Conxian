(define-trait sip-009-nft-trait
  (
    (get-last-token-id () (response uint uint))
    (get-token-uri (token-id uint) (response (optional (string-ascii 256)) uint))
    (get-owner (token-id uint) (response (optional principal) uint))
    (transfer (token-id uint) (sender principal) (recipient principal) (response bool uint))
  )
)
