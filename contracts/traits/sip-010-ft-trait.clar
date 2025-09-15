;; SIP-010 Fungible Token Trait with additional functionality

(use-trait sip-010-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sip-010-trait)

(define-trait sip-010-ft-trait
  (
    ;; Inherit all functions from sip-010-trait
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-decimals () (response uint uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 10) uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
    
    ;; Additional functions for extended functionality
    (mint (uint principal) (response bool uint))
    (burn (uint) (response bool uint))
    (set-contract-owner (principal) (response bool uint))
    (get-contract-owner () (response principal uint))
    (set-token-uri ((optional (string-utf8 256))) (response bool uint))
  )
)
