;; Standard Traits for Conxian Protocol
;; This file contains all standard traits used across the Conxian Protocol

;; ===== Access Control Trait =====
(define-trait access-control-trait
  (
    ;; Role Management
    (has-role (principal (string-ascii 32)) (response bool uint))
    (grant-role (principal (string-ascii 32)) (response bool uint))
    (revoke-role (principal (string-ascii 32)) (response bool uint))
    
    ;; Role-based Access Control
    (only-role ((string-ascii 32)) (response bool uint))
    (only-roles ((list 10 (string-ascii 32))) (response bool uint))
  )
)

;; ===== SIP-010 Fungible Token Standard =====
(define-trait sip-010-ft-trait
  (
    ;; Standard SIP-010 functions
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)


;; ===== Pool Trait =====
(define-trait pool-trait
  (
    (add-liquidity (uint uint principal) (response (tuple (dx uint) (dy uint) (shares uint)) uint))
    (remove-liquidity (uint principal) (response (tuple (dx uint) (dy uint)) uint))
    (swap (uint principal principal) (response (tuple (dx uint) (dy uint)) uint))
    (get-reserves () (response (tuple (reserve-x uint) (reserve-y uint)) uint))
    (get-total-supply () (response uint uint))
  )
)

;; ===== Oracle Trait =====
(define-trait oracle-trait
  (
    (update-price (uint) (response bool uint))
    (get-price () (response uint uint))
    (get-last-updated () (response uint uint))
  )
)
