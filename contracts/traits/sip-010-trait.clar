;; SIP-010 Trait - Standard interface for fungible tokens
;; This is the official SIP-010 trait definition

(define-trait sip-010-trait
  (
    ;; Transfer from the sender to a new principal
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    
    ;; Get token balance for a principal
    (get-balance (principal) (response uint uint))
    
    ;; Get the total supply of the token
    (get-total-supply () (response uint uint))
    
    ;; Get the number of decimals for the token
    (get-decimals () (response uint uint))
    
    ;; Get the token name
    (get-name () (response (string-ascii 32) uint))
    
    ;; Get the token symbol
    (get-symbol () (response (string-ascii 10) uint))
    
    ;; Get the token URI (optional)
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

