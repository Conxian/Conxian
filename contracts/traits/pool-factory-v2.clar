;; pool-factory-v2.clar
;; Pool factory V2 trait for DEX liquidity management

;; ===========================================
;; POOL FACTORY V2 TRAIT
;; ===========================================
(define-trait pool-factory-v2-trait
  (
    ;; Create a new liquidity pool
    (create-pool 
      {
        token-a: principal,
        token-b: principal,
        fee-rate: uint,
        initial-liquidity: uint,
        initial-price: uint
      }
    ) (response principal uint))
    
    ;; Get pool address for token pair
    (get-pool-address (principal principal) (response (optional principal) uint))
    
    ;; Get all pools
    (get-all-pools () (response (list 100 principal) uint))
    
    ;; Get pools by token
    (get-pools-by-token (principal) (response (list 50 principal) uint))
    
    ;; Update pool parameters
    (update-pool-params 
      (principal {
        fee-rate: (optional uint),
        max-slippage: (optional uint)
      })
    ) (response bool uint))
    
    ;; Enable/disable pool
    (toggle-pool (principal bool) (response bool uint))
    
    ;; Get pool creation fee
    (get-creation-fee () (response uint uint))
    
    ;; Set pool creation fee
    (set-creation-fee (uint) (response bool uint))
    
    ;; Get factory owner
    (get-owner () (response principal uint))
    
    ;; Transfer factory ownership
    (transfer-ownership (principal) (response bool uint))
  )
)

;; ===========================================
;; ENHANCED POOL TRAIT FOR V2
;; ===========================================
(define-trait enhanced-pool-trait
  (
    ;; Add liquidity to pool
    (add-liquidity 
      {
        token-a-amount: uint,
        token-b-amount: uint,
        min-a-amount: uint,
        min-b-amount: uint,
        recipient: principal
      }
    ) (response {
      liquidity-shares: uint,
      token-a-used: uint,
      token-b-used: uint
    } uint))
    
    ;; Remove liquidity from pool
    (remove-liquidity 
      {
        shares: uint,
        min-a-amount: uint,
        min-b-amount: uint,
        recipient: principal
      }
    ) (response {
      token-a-received: uint,
      token-b-received: uint
    } uint))
    
    ;; Swap tokens
    (swap 
      {
        token-in: principal,
        token-out: principal,
        amount-in: uint,
        min-amount-out: uint,
        recipient: principal
      }
    ) (response {
      amount-out: uint,
      fee-paid: uint
    } uint))
    
    ;; Get pool reserves
    (get-reserves () (response {
      reserve-a: uint,
      reserve-b: uint
    } uint))
    
    ;; Get pool statistics
    (get-pool-stats () (response {
      total-liquidity: uint,
      volume-24h: uint,
      fees-24h: uint,
      apr: uint
    } uint))
    
    ;; Get liquidity token price
    (get-liquidity-price () (response uint uint))
    
    ;; Calculate optimal swap amount
    (calculate-optimal-swap (principal uint uint) (response uint uint))
  )
)
