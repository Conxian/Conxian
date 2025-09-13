;; lending-system-trait.clar
;; Standard interface for lending and borrowing systems
;; Supports both flash loans and traditional collateralized loans

(use-trait sip10 'traits.sip-010-trait.sip-010-trait)

(define-trait lending-system-trait
  (
    ;; === FLASH LOAN FUNCTIONS ===
    ;; Execute a flash loan
    (flash-loan (<sip10> uint principal (buff 256)) (response bool uint))
    
    ;; Get maximum flash loan amount for an asset
    (get-max-flash-loan (<sip10>) (response uint uint))
    
    ;; Get flash loan fee for an asset and amount
    (get-flash-loan-fee (<sip10> uint) (response uint uint))
    
    ;; === TRADITIONAL LENDING FUNCTIONS ===
    ;; Supply assets to earn interest
    (supply (<sip10> uint) (response uint uint))
    
    ;; Withdraw supplied assets
    (withdraw (<sip10> uint) (response uint uint))
    
    ;; Borrow against collateral
    (borrow (<sip10> uint) (response uint uint))
    
    ;; Repay borrowed assets
    (repay (<sip10> uint) (response uint uint))
    
    ;; Liquidate undercollateralized positions
    (liquidate (principal <sip10> uint) (response uint uint))
    
    ;; === INFORMATION FUNCTIONS ===
    ;; Get user's supply balance
    (get-supply-balance (principal <sip10>) (response uint uint))
    
    ;; Get user's borrow balance
    (get-borrow-balance (principal <sip10>) (response uint uint))
    
    ;; Get user's collateral value in USD
    (get-collateral-value (principal) (response uint uint))
    
    ;; Get user's health factor
    (get-health-factor (principal) (response uint uint))
    
    ;; Get current supply APY for an asset
    (get-supply-apy (<sip10>) (response uint uint))
    
    ;; Get current borrow APY for an asset
    (get-borrow-apy (<sip10>) (response uint uint))
    
    ;; === ADMIN FUNCTIONS ===
    ;; Set interest rate model parameters
    (set-interest-rate-model (<sip10> uint uint uint) (response bool uint))
    
    ;; Set collateral factor for an asset
    (set-collateral-factor (<sip10> uint) (response bool uint))
    
    ;; Set liquidation threshold
    (set-liquidation-threshold (<sip10> uint) (response bool uint))
    
    ;; Pause/unpause the system
    (set-paused (bool) (response bool uint))
  )
)



