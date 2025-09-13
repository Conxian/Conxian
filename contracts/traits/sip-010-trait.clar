;; SIP-010 Fungible Token Trait

(define-trait sip-010-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-decimals () (response uint uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 10) uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
    (set-token-uri ((optional (string-utf8 256))) (response bool uint))
  )
)



