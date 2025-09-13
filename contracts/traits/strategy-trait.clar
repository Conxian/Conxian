;; Strategy Trait - Yield strategy interface for vault integration
;; Supports multiple yield strategies with enhanced tokenomics integration

(define-trait strategy-trait
  (
    ;; Core strategy operations
    (deploy-funds (uint) (response uint uint))
    (withdraw-funds (uint) (response uint uint))
    (harvest-rewards () (response uint uint))
    
    ;; Strategy information
    (get-total-deployed () (response uint uint))
    (get-current-value () (response uint uint))
    (get-expected-apy () (response uint uint))
    (get-strategy-risk-level () (response uint uint))
    
    ;; Asset management
    (get-underlying-asset () (response principal uint))
    (emergency-exit () (response uint uint))
    
    ;; Enhanced tokenomics integration  
    (distribute-rewards () (response uint uint))
    (get-performance-fee () (response uint uint))
    (update-dimensional-weights () (response bool uint))
  )
)



