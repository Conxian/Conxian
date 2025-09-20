;; all-traits.clar
;; Centralized trait definitions for the Conxian protocol

;; ===========================================
;; CORE TRAITS
;; ===========================================

;; Access Control Trait
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

;; SIP-010 Fungible Token Standard
(define-trait sip-010-ft-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-decimals () (response uint uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 10) uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Lending System Trait
(define-trait lending-system-trait
  (
    ;; Flash Loan Functions
    (flash-loan (principal uint principal (buff 256)) (response bool uint))
    (get-max-flash-loan (principal) (response uint uint))
    (get-flash-loan-fee (principal uint) (response uint uint))
    
    ;; Traditional Lending Functions
    (supply (principal uint) (response bool uint))
    (withdraw (principal uint) (response bool uint))
    (borrow (principal uint) (response bool uint))
    (repay (principal uint) (response bool uint))
    
    ;; Interest Rate Functions
    (get-supply-rate (principal) (response uint uint))
    (get-borrow-rate (principal) (response uint uint))
    
    ;; Collateral Management
    (enter-market (principal) (response bool uint))
    (exit-market (principal) (response bool uint))
    
    ;; Account Information
    (get-account-liquidity (principal) (response (tuple (liquidity uint) (shortfall uint)) uint))
    (get-account-borrows (principal) (response (list 100 (tuple (asset principal) (amount uint) (index uint))) uint))
    (get-account-supplies (principal) (response (list 100 (tuple (asset principal) (amount uint) (index uint))) uint))
  )
)

;; Bond Trait
(define-trait bond-trait
  (
    (create-bond (principal uint uint uint) (response uint uint))
    (redeem (uint) (response uint uint))
    (is-bond-mature () (response bool uint))
    (get-bond-price () (response uint uint))
    (get-yield () (response uint uint))
  )
)

;; DEX Pool Trait
(define-trait pool-trait
  (
    (initialize (principal principal) (response bool uint))
    (add-liquidity (uint uint uint uint uint) (response (tuple (shares uint) (amount-a uint) (amount-b uint)) uint))
    (remove-liquidity (uint uint uint uint) (response (tuple (amount-a uint) (amount-b uint)) uint))
    (swap (principal uint uint (optional principal)) (response uint uint))
    (get-reserves () (response (tuple (reserve-a uint) (reserve-b uint)) uint))
    (get-tokens () (response (tuple (token-a principal) (token-b principal)) uint))
  )
)

;; DEX Factory Trait
(define-trait factory-trait
  (
    (create-pool (principal principal uint) (response principal uint))
    (get-pool (principal principal) (response (optional principal) uint))
    (get-pool-info (principal) (response (optional (tuple (token-a principal) (token-b principal) (fee-bps uint) (created-at uint))) uint))
  )
)

;; DEX Router Trait
(define-trait router-trait
  (
    (swap-exact-tokens-for-tokens (uint uint (list 5 principal) principal uint) (response uint uint))
    (add-liquidity (principal principal uint uint uint uint principal uint) (response (tuple (shares uint) (amount-a uint) (amount-b uint)) uint))
    (remove-liquidity (principal principal uint uint uint principal uint) (response (tuple (amount-a uint) (amount-b uint)) uint))
  )
)

;; Oracle Trait
(define-trait oracle-trait
  (
    (get-price (principal) (response uint uint))
    (update-price (principal uint) (response bool uint))
    (get-last-updated (principal) (response uint uint))
  )
)

;; Flash Loan Receiver Trait
(define-trait flash-loan-receiver-trait
  (
    (execute-operation (principal uint uint (buff 256)) (response bool uint))
  )
)

;; Circuit Breaker Trait
(define-trait circuit-breaker-trait
  (
    (check-circuit-state (string-ascii 64) (response uint uint))
    (record-success (string-ascii 64) (response uint uint))
    (record-failure (string-ascii 64) (response uint uint))
  )
)

;; Pausable Trait
(define-trait pausable-trait
  (
    (pause () (response bool uint))
    (unpause () (response bool uint))
    (paused () (response bool uint))
  )
)

;; Ownable Trait
(define-trait ownable-trait
  (
    (get-owner () (response principal uint))
    (transfer-ownership (principal) (response bool uint))
    (renounce-ownership () (response bool uint))
  )
)

;; SIP-010 Mintable Fungible Token Trait
(define-trait sip-010-ft-mintable-trait
  (
    (mint (principal uint) (response bool uint))
    (burn (uint) (response bool uint))
  )
)

;; Monitor Trait for System Integration
(define-trait monitor-trait
  (
    (notify-mint (uint principal) (response bool uint))
    (notify-burn (uint principal) (response bool uint))
    (notify-transfer (uint principal principal) (response bool uint))
  )
)

;; SIP-009 Non-Fungible Token Standard
(define-trait sip-009-nft-trait
  (
    (transfer (principal principal uint (optional (buff 34))) (response bool uint))
    (get-owner (uint) (response (optional principal) uint))
    (get-token-uri (uint) (response (optional (string-utf8 256)) uint))
    (get-last-token-id () (response uint uint))
    (get-token-by-index (principal uint) (response (optional uint) uint))
  )
)

;; Reentrancy Guard Trait
(define-trait reentrancy-guard-trait
  (
    (non-reentrant () (response bool uint))
  )
)

;; Advanced Math Library Trait
(define-trait math-trait
  (
    ;; Basic Operations
    (mul-down (uint uint) (response uint uint))
    (div-down (uint uint) (response uint uint))
    (safe-div (uint uint) (response uint uint))
    (abs-int (int) (response uint uint))
    (abs-uint (uint) (response uint uint))
    
    ;; Advanced Functions
    (exp-fixed (uint) (response uint uint))
    (ln-fixed (uint) (response uint uint))
    (sqrt-fixed (uint) (response uint uint))
    (pow-fixed (uint uint) (response uint uint))
    
    ;; Utility Functions
    (safe-add (uint uint) (response uint uint))
    (safe-sub (uint uint) (response uint uint))
    (safe-mul (uint uint) (response uint uint))
  )
)

