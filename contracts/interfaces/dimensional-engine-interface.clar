;; ============================================================
;; DIMENSIONAL ENGINE INTERFACE (v3.9.0+)
;; ============================================================
;; Interface for the Dimensional Engine that handles multi-dimensional positions

(use-trait base-contract .base-contract.base-contract-trait)
(use-trait oracle .oracle-pricing.oracle-aggregator-v2-trait)
(use-trait token .sip-standards.sip-010-ft-trait)
(use-trait risk .risk-trait.risk-trait)

(define-trait dimensional-engine-trait
  (
    ;; ======================
    ;; POSITION MANAGEMENT
    ;; ======================
    
    ;; Open a new position
    (open-position 
      (asset principal) 
      (collateral uint) 
      (leverage uint) 
      (is-long bool) 
      (stop-loss (optional uint)) 
      (take-profit (optional uint))
    ) (response uint uint)
    
    ;; Close a position
    (close-position 
      (position-id uint) 
      (slippage (optional uint))
    ) (response (tuple (collateral-returned uint) (pnl int)) uint)
    
    ;; Liquidate a position
    (liquidate-position 
      (position-id uint) 
      (liquidator principal)
    ) (response (tuple (collateral-returned uint) (reward uint)) uint)
    
    ;; Add collateral to a position
    (add-collateral 
      (position-id uint) 
      (amount uint)
    ) (response bool uint)
    
    ;; Remove collateral from a position
    (remove-collateral 
      (position-id uint) 
      (amount uint)
    ) (response bool uint)
    
    ;; ======================
    /// RISK MANAGEMENT
    ;; ======================
    
    ;; Update position risk parameters
    (update-risk-parameters 
      (max-leverage uint) 
      (maintenance-margin uint) 
      (liquidation-penalty uint)
    ) (response bool uint)
    
    ;; Get position health factor
    (get-position-health 
      (position-id uint)
    ) (response uint uint)
    
    ;; Check if position can be liquidated
    (can-liquidate 
      (position-id uint)
    ) (response bool uint)
    
    ;; ======================
    /// ORACLE & PRICING
    ;; ======================
    
    ;; Update oracle address
    (set-oracle 
      (oracle principal)
    ) (response bool uint)
    
    ;; Get current price with confidence interval
    (get-price-with-confidence 
      (asset principal)
    ) (response (tuple (price uint) (confidence uint) (last-updated uint)) uint)
    
    ;; ======================
    /// FUNDING RATES
    ;; ======================
    
    ;; Update funding rate
    (update-funding-rate 
      (asset principal)
    ) (response int uint)
    
    ;; Get current funding rate
    (get-funding-rate 
      (asset principal)
    ) (response int uint)
    
    ;; ======================
    /// INSURANCE & FEES
    ;; ======================
    
    ;; Withdraw protocol fees
    (withdraw-fees 
      (token principal) 
      (amount uint) 
      (recipient principal
    )) (response bool uint)
    
    ;; Update fee parameters
    (update-fee-parameters 
      (protocol-fee uint) 
      (liquidation-fee uint)
    ) (response bool uint)
    
    ;; ======================
    /// VIEW FUNCTIONS
    ;; ======================
    
    ;; Get position details
    (get-position 
      (position-id uint)
    ) (response 
        (tuple 
          (owner principal)
          (asset principal)
          (collateral uint)
          (size uint)
          (entry-price uint)
          (leverage uint)
          (is-long bool)
          (funding-rate int)
          (last-updated uint)
          (stop-loss (optional uint))
          (take-profit (optional uint))
        ) 
        uint
      )
    
    ;; Get total open interest
    (get-open-interest 
      (asset principal)
    ) (response (tuple (long uint) (short uint)) uint)
    
    ;; Get protocol stats
    (get-protocol-stats) 
    (response 
      (tuple
        (total-positions-opened uint)
        (total-volume uint)
        (total-fees-collected uint)
        (total-value-locked uint)
      ) 
      uint
    )
  )
)

;; ======================
;; EVENTS
;; ======================

(define-event PositionOpened
  ((position-id uint)
   (owner principal)
   (asset principal)
   (collateral uint)
   (size uint)
   (leverage uint)
   (is-long bool)
   (entry-price uint))
)

(define-event PositionClosed
  ((position-id uint)
   (owner principal)
   (collateral-returned uint)
   (pnl int)
   (close-price uint))
)

(define-event PositionLiquidated
  ((position-id uint)
   (owner principal)
   (liquidator principal)
   (collateral-returned uint)
   (liquidation-reward uint)
   (liquidation-price uint))
)

(define-event FundingRateUpdated
  ((asset principal)
   (rate int)
   (timestamp uint))
)

(define-event RiskParametersUpdated
  ((max-leverage uint)
   (maintenance-margin uint)
   (liquidation-penalty uint))
)

(define-event FeeParametersUpdated
  ((protocol-fee uint)
   (liquidation-fee uint))
)

(define-event OracleUpdated
  (oracle principal)
)
