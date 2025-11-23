;; trait-dimensional.clar
;; Dimensional finance traits for collateral and position management

;; ===========================================
;; COLLATERAL MANAGER TRAIT
;; ===========================================
(define-trait collateral-manager-trait
  (
    ;; Deposit funds into collateral manager
    (deposit-funds (uint principal) (response bool uint))
    
    ;; Withdraw funds from collateral manager  
    (withdraw-funds (uint principal) (response bool uint))
    
    ;; Get collateral balance for an account
    (get-collateral-balance (principal) (response uint uint))
    
    ;; Get total collateral under management
    (get-total-collateral () (response uint uint))
    
    ;; Check if account has sufficient collateral
    (has-sufficient-collateral (principal uint) (response bool uint))
    
    ;; Update collateral requirements
    (update-collateral-requirements (uint uint) (response bool uint))
  )
)

;; ===========================================
;; POSITION MANAGER TRAIT  
;; ===========================================
(define-trait position-manager-trait
  (
    ;; Open a new position
    (open-position 
      {
        owner: principal,
        asset: principal, 
        collateral: uint,
        size: uint,
        entry-price: uint,
        leverage: uint,
        is-long: bool
      }
    ) (response uint uint))
    
    ;; Close an existing position
    (close-position (uint uint) (response bool uint))
    
    ;; Get position details
    (get-position (uint) (response (optional {
      owner: principal,
      asset: principal,
      collateral: uint, 
      size: uint,
      entry-price: uint,
      leverage: uint,
      is-long: bool
    }) uint))
    
    ;; Get all positions for an owner
    (get-positions-by-owner (principal) (response (list 100 uint) uint))
    
    ;; Update position parameters
    (update-position (uint {
      collateral: (optional uint),
      size: (optional uint), 
      leverage: (optional uint)
    }) (response bool uint))
    
    ;; Get position health metrics
    (get-position-health (uint) (response {
      health-ratio: uint,
      liquidation-price: uint,
      unrealized-pnl: uint
    } uint))
  )
)

;; ===========================================
;; DIMENSIONAL ENGINE TRAIT
;; ===========================================
(define-trait dimensional-engine-trait
  (
    ;; Calculate position health
    (calculate-health (uint) (response uint uint))
    
    ;; Get liquidation price
    (get-liquidation-price (uint) (response uint uint))
    
    ;; Calculate funding rate
    (calculate-funding-rate (principal) (response uint uint))
    
    ;; Apply funding payments
    (apply-funding (principal) (response bool uint))
    
    ;; Get market data
    (get-market-data (principal) (response {
      price: uint,
      volatility: uint,
      volume: uint
    } uint))
  )
)
