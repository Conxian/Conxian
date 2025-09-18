;; sip-009-nft-trait.clar
;; SIP-009 Non-Fungible Token Trait

(define-trait sip-009-nft-trait
  ;; Returns the last token ID, or none if there are no tokens
  (get-last-token-id () (response (optional uint) uint))
  
  ;; Get the owner of a token
  (get-owner (token-id uint) (response (optional principal) uint))
  
  ;; Get the token URI
  (get-token-uri (token-id uint) (response (optional (string-utf8 256)) uint))
  
  ;; Transfer a token
  (transfer (token-id uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  
  ;; Mint a new token (only callable by the contract itself)
  (mint (audit-id uint) (metadata (string-utf8 256)) (recipient principal) (response uint uint))
  
  ;; Burn a token (only callable by the contract itself or token owner)
  (burn (token-id uint) (owner principal) (response bool uint))
  
  ;; Get the token ID for a specific audit
  (get-token-by-audit (audit-id uint) (response (optional uint) uint))
  
  ;; Get the audit ID for a specific token
  (get-audit-by-token (token-id uint) (response (optional uint) uint))
  
  ;; Set the base token URI (admin only)
  (set-base-token-uri (uri (string-utf8 256)) (response bool uint))
  
  ;; Update token metadata (admin only)
  (update-metadata (token-id uint) (metadata (string-utf8 256)) (response bool uint))
)
