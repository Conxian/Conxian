;; sip-010-ft-trait.clar
;; This file is deprecated. Please use all-traits.clar instead.
;; The sip-010-ft-trait is now defined in all-traits.clar

;; SIP-010 Fungible Token Trait with additional functionality
;; This is a complete implementation of SIP-010 with extensions

(define-trait sip-010-ft-trait
  (
    ;; Standard SIP-010 functions
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-decimals () (response uint uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 10) uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
    
    ;; Extended functionality
    (mint (uint principal) (response bool uint))
    (burn (uint) (response bool uint))
    (set-contract-owner (principal) (response bool uint))
    (get-contract-owner () (response principal uint))
    (set-token-uri ((optional (string-utf8 256))) (response bool uint))
  )
)
