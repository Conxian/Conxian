;; liquidation-trait.clar
;; Defines the standard interface for liquidation operations in the Conxian protocol

(use-trait standard-constants 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSR.standard-constants-trait)

(define-trait liquidation-trait
  (
    ;; Check if a position can be liquidated
    (can-liquidate-position 
      (borrower principal) 
      (debt-asset principal) 
      (collateral-asset principal)
    ) (response bool uint)
    
    ;; Liquidate a single position
    (liquidate-position
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
      (debt-amount uint)
      (max-collateral-amount uint)
    ) (response (tuple (debt-repaid uint) (collateral-seized uint)) uint)
    
    ;; Batch liquidate multiple positions
    (liquidate-multiple-positions
      (positions (list 10 (tuple 
        (borrower principal) 
        (debt-asset principal) 
        (collateral-asset principal) 
        (debt-amount uint)
      )))
    ) (response (tuple (success-count uint) (total-debt-repaid uint) (total-collateral-seized uint)) uint)
    
    ;; Calculate liquidation amounts
    (calculate-liquidation-amounts
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
      (debt-amount uint)
    ) (response (tuple 
        (max-debt-repayable uint)
        (collateral-to-seize uint)
        (liquidation-incentive uint)
        (debt-value uint)
        (collateral-value uint)
      ) uint)
      
    ;; Emergency liquidation (admin only)
    (emergency-liquidate
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
    ) (response bool uint)
  )
)

;; Error codes for liquidation operations
(define-constant ERR_LIQUIDATION_PAUSED (err u1001))
(define-constant ERR_UNAUTHORIZED (err u1002))
(define-constant ERR_INVALID_AMOUNT (err u1003))
(define-constant ERR_POSITION_NOT_UNDERWATER (err u1004))
(define-constant ERR_SLIPPAGE_TOO_HIGH (err u1005))
(define-constant ERR_LIQUIDATION_NOT_PROFITABLE (err u1006))
(define-constant ERR_MAX_POSITIONS_EXCEEDED (err u1007))
(define-constant ERR_ASSET_NOT_WHITELISTED (err u1008))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u1009))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1010))





