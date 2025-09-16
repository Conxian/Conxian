;; lending-system-trait.clar
;; Standard interface for lending and borrowing systems
;; Supports both flash loans and traditional collateralized loans

(use-trait ft-trait 'sip-010-ft-trait)

(define-trait lending-system-trait
  (
    ;; === FLASH LOAN FUNCTIONS ===
    ;; Execute a flash loan
    (flash-loan (<ft-trait> uint principal (buff 256)) (response bool uint))
    
    ;; Get maximum flash loan amount for an asset
    (get-max-flash-loan (<ft-trait>) (response uint uint))
    
    ;; Get flash loan fee for an asset and amount
    (get-flash-loan-fee (<ft-trait> uint) (response uint uint))
    
    ;; === TRADITIONAL LENDING FUNCTIONS ===
    ;; Supply assets to earn interest
    (supply (<ft-trait> uint) (response uint uint))
    
    ;; Withdraw supplied assets
    (withdraw (<ft-trait> uint) (response uint uint))
    
    ;; Borrow against collateral
    (borrow (<ft-trait> uint) (response uint uint))
    
    ;; Repay borrowed assets
    (repay (<ft-trait> uint) (response uint uint))
    
    ;; Liquidate undercollateralized positions
    (liquidate (principal <ft-trait> uint) (response uint uint))
    
    ;; === INFORMATION FUNCTIONS ===
    ;; Get users supply balance
    (get-supply-balance (principal <ft-trait>) (response uint uint))
    
    ;; Get users borrow balance
    (get-borrow-balance (principal <ft-trait>) (response uint uint))
    
    ;; Get users collateral value in USD
    (get-collateral-value (principal) (response uint uint))
    
    ;; Get users health factor
    (get-health-factor (principal) (response uint uint))
    
    ;; Get current supply APY for an asset
    (get-supply-apy (<ft-trait>) (response uint uint))
    
    ;; Get current borrow APY for an asset
    (get-borrow-apy (<ft-trait>) (response uint uint))
    
    ;; === ADMIN FUNCTIONS ===
    ;; Set interest rate model parameters
    (set-interest-rate-model (<ft-trait> uint uint uint) (response bool uint))
    
    ;; Set collateral factor for an asset
    (set-collateral-factor (<ft-trait> uint) (response bool uint))
    
    ;; Set liquidation threshold
    (set-liquidation-threshold (<ft-trait> uint) (response bool uint))
    
    ;; Pause/unpause the system
    (set-paused (bool) (response bool uint))
  )
)





