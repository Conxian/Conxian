;; sbtc-lending-integration.clar
;; sBTC Lending Integration - extends comprehensive lending system
;; Provides sBTC-specific lending, borrowing, and collateral management

(use-trait ft-trait .all-traits.sip-010-ft-trait)

;; =============================================================================
;; CONSTANTS AND ERROR CODES
;; =============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant sbtc-integration .sbtc-integration)
(define-constant ERR_NOT_AUTHORIZED (err u2000))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u2001))
(define-constant ERR_LIQUIDATION_THRESHOLD_REACHED (err u2002))
(define-constant ERR_BORROW_CAP_EXCEEDED (err u2003))
(define-constant ERR_SUPPLY_CAP_EXCEEDED (err u2004))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u2005))
(define-constant ERR_INVALID_AMOUNT (err u2006))
(define-constant ERR_POSITION_NOT_FOUND (err u2007))
(define-constant ERR_LIQUIDATION_NOT_AVAILABLE (err u2008))
(define-constant ERR_HEALTH_FACTOR_OK (err u2009))

;; Minimum amounts
(define-constant MIN_SUPPLY_AMOUNT u100000)    ;; 0.001 BTC
(define-constant MIN_BORROW_AMOUNT u100000)    ;; 0.001 BTC
(define-constant LIQUIDATION_CLOSE_FACTOR u500000) ;; 50% max liquidation

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================

(define-map user-positions
  { user: principal, asset: principal }
  {
    supply-balance: uint,        ;; Users supply balance
    borrow-balance: uint,        ;; Users borrow balance
    supply-index: uint,          ;; Interest index at last supply action
    borrow-index: uint,          ;; Interest index at last borrow action
    last-interaction: uint       ;; Last interaction block
  }
)

(define-map liquidation-queue
  { liquidator: principal, borrower: principal, asset: principal }
  {
    debt-amount: uint,           ;; Amount of debt being liquidated
    collateral-asset: principal, ;; Collateral being seized
    collateral-amount: uint,     ;; Amount of collateral to seize
    timestamp: uint,             ;; Liquidation timestamp
    status: uint                 ;; 0 = pending, 1 = completed, 2 = failed
  }
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-user-position (user principal) (asset principal))
  "Get users lending position for asset"
  (map-get? user-positions { user: user, asset: asset })
)

(define-read-only (get-user-supply-balance (user principal) (asset principal))
  "Get users current supply balance with accrued interest"
  (match (get-user-position user asset)
    position (let ((supply-balance (get supply-balance position))
                   (supply-index (get supply-index position)))
      ;; Calculate accrued interest based on current supply rate
      (match (contract-call? sbtc-integration calculate-interest-rates asset)
        rates (let ((current-index (+ supply-index u1))) ;; Simplified - should use actual index calculation
          (* supply-balance (/ current-index supply-index))
        )
        supply-balance
      )
    )
    u0
  )
)

(define-read-only (get-user-borrow-balance (user principal) (asset principal))
  "Get users current borrow balance with accrued interest"
  (match (get-user-position user asset)
    position (let ((borrow-balance (get borrow-balance position))
                   (borrow-index (get borrow-index position)))
      ;; Calculate accrued interest on borrows
      (match (contract-call? sbtc-integration calculate-interest-rates asset)
        rates (let ((current-index (+ borrow-index u1))) ;; Simplified calculation
          (* borrow-balance (/ current-index borrow-index))
        )
        borrow-balance
      )
    )
    u0
  )
)

(define-read-only (calculate-account-liquidity (user principal))
  "Calculate users account liquidity (collateral value - borrowed value)"
  (let ((sbtc-supply (get-user-supply-balance user (get-constant sbtc-integration SBTC_MAINNET)))
        (sbtc-borrow (get-user-borrow-balance user (get-constant sbtc-integration SBTC_MAINNET))))
    (match (contract-call? sbtc-integration calculate-collateral-value (get-constant sbtc-integration SBTC_MAINNET) sbtc-supply)
      collateral-value (match (contract-call? sbtc-integration get-sbtc-price)
        price (let ((borrow-value (* sbtc-borrow price)))
          (if (>= collateral-value borrow-value)
            (ok (- collateral-value borrow-value))
            (ok u0) ;; Account is underwater
          )
        )
        (ok u0)
      )
      (ok u0)
    )
  )
)

(define-read-only (calculate-health-factor (user principal))
  "Calculate users health factor (>1.0 = healthy, <1.0 = can be liquidated)"
  (let ((sbtc-supply (get-user-supply-balance user (get-constant sbtc-integration SBTC_MAINNET)))
        (sbtc-borrow (get-user-borrow-balance user (get-constant sbtc-integration SBTC_MAINNET))))
    (if (is-eq sbtc-borrow u0)
      (ok u2000000) ;; Very high health factor if no borrows
      (match (contract-call? sbtc-integration calculate-liquidation-threshold (get-constant sbtc-integration SBTC_MAINNET) sbtc-supply)
        liquidation-value (match (contract-call? sbtc-integration get-sbtc-price)
          price (let ((borrow-value (* sbtc-borrow price)))
            (if (> borrow-value u0)
              (ok (/ (* liquidation-value u1000000) borrow-value))
              (ok u2000000)
            )
          )
          (ok u0)
        )
        (ok u0)
      )
    )
  )
)

(define-read-only (get-max-borrow-amount (user principal) (asset principal))
  "Calculate maximum amount user can borrow"
  (match (calculate-account-liquidity user)
    liquidity (match (contract-call? sbtc-integration get-sbtc-price)
      price (if (> price u0)
        (ok (/ liquidity price))
        (ok u0)
      )
      (ok u0)
    )
    (ok u0)
  )
)

(define-read-only (get-liquidation-info (borrower principal))
  "Get liquidation information for borrower"
  (match (calculate-health-factor borrower)
    health-factor (if (< health-factor u1000000) ;; Health factor < 1.0
      (let ((sbtc-supply (get-user-supply-balance borrower (get-constant sbtc-integration SBTC_MAINNET)))
            (sbtc-borrow (get-user-borrow-balance borrower (get-constant sbtc-integration SBTC_MAINNET))))
        (ok {
          can-liquidate: true,
          health-factor: health-factor,
          max-liquidation-amount: (/ (* sbtc-borrow LIQUIDATION_CLOSE_FACTOR) u1000000),
          collateral-available: sbtc-supply
        })
      )
      (ok {
        can-liquidate: false,
        health-factor: health-factor,
        max-liquidation-amount: u0,
        collateral-available: u0
      })
    )
    (ok {
      can-liquidate: false,
      health-factor: u0,
      max-liquidation-amount: u0,
      collateral-available: u0
    })
  )
)

;; =============================================================================
;; SUPPLY FUNCTIONS
;; =============================================================================

(define-public (supply (asset ft-trait) (amount uint))
  "Supply sBTC to earn interest"
  (let ((asset-principal (contract-of asset)))
    (begin
      ;; Validate operation
      (try! (contract-call? sbtc-integration validate-operation asset-principal "supply"))
      (asserts! (>= amount MIN_SUPPLY_AMOUNT) ERR_INVALID_AMOUNT)
      
      ;; Check supply cap
      (match (contract-call? sbtc-integration get-asset-metrics asset-principal)
        metrics (match (contract-call? sbtc-integration get-asset-config asset-principal)
          config (match (get supply-cap config)
            cap (asserts! (<= (+ (get total-supply metrics) amount) cap) ERR_SUPPLY_CAP_EXCEEDED)
            true
          )
          true
        )
        true
      )
      
      ;; Accrue interest before operation
      (try! (contract-call? sbtc-integration accrue-interest asset-principal))
      
      ;; Transfer tokens from user
      (try! (contract-call? asset transfer amount tx-sender (as-contract tx-sender) none))
      
      ;; Update user position
      (let ((current-position (default-to 
                               { 
                                 supply-balance: u0, 
                                 borrow-balance: u0, 
                                 supply-index: u1000000, 
                                 borrow-index: u1000000,
                                 last-interaction: block-height 
                               }
                               (get-user-position tx-sender asset-principal))))
        (map-set user-positions 
          { user: tx-sender, asset: asset-principal }
          (merge current-position {
            supply-balance: (+ (get supply-balance current-position) amount),
            last-interaction: block-height
          })
        )
      )
      
      (print { 
        event: "supply", 
        user: tx-sender, 
        asset: asset-principal, 
        amount: amount,
        block: block-height
      })
      (ok true)
    )
  )
)

(define-public (withdraw (asset ft-trait) (amount uint))
  "Withdraw supplied sBTC"
  (let ((asset-principal (contract-of asset)))
    (begin
      ;; Validate operation
      (try! (contract-call? sbtc-integration validate-operation asset-principal "supply"))
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      
      ;; Accrue interest
      (try! (contract-call? sbtc-integration accrue-interest asset-principal))
      
      ;; Check user has sufficient balance
      (let ((current-supply (get-user-supply-balance tx-sender asset-principal)))
        (asserts! (>= current-supply amount) ERR_INSUFFICIENT_LIQUIDITY)
        
        ;; Check account liquidity after withdrawal
        (match (calculate-account-liquidity tx-sender)
          liquidity (match (contract-call? sbtc-integration get-sbtc-price)
            price (let ((withdrawal-value (* amount price)))
              (asserts! (>= liquidity withdrawal-value) ERR_INSUFFICIENT_COLLATERAL)
              
              ;; Update user position
              (match (get-user-position tx-sender asset-principal)
                position (begin
                  (map-set user-positions 
                    { user: tx-sender, asset: asset-principal }
                    (merge position {
                      supply-balance: (- (get supply-balance position) amount),
                      last-interaction: block-height
                    })
                  )
                  
                  ;; Transfer tokens to user
                  (try! (as-contract (contract-call? asset transfer amount tx-sender tx-sender none)))
                  
                  (print { 
                    event: "withdraw", 
                    user: tx-sender, 
                    asset: asset-principal, 
                    amount: amount 
                  })
                  (ok true)
                )
                ERR_POSITION_NOT_FOUND
              )
            )
            ERR_INSUFFICIENT_COLLATERAL
          )
          ERR_INSUFFICIENT_COLLATERAL
        )
      )
    )
  )
)

;; =============================================================================
;; BORROW FUNCTIONS
;; =============================================================================

(define-public (borrow (asset ft-trait) (amount uint))
  "Borrow sBTC against collateral"
  (let ((asset-principal (contract-of asset)))
    (begin
      ;; Validate operation
      (try! (contract-call? sbtc-integration validate-operation asset-principal "borrow"))
      (asserts! (>= amount MIN_BORROW_AMOUNT) ERR_INVALID_AMOUNT)
      
      ;; Check borrow cap
      (match (contract-call? sbtc-integration get-asset-metrics asset-principal)
        metrics (match (contract-call? sbtc-integration get-asset-config asset-principal)
          config (match (get borrow-cap config)
            cap (asserts! (<= (+ (get total-borrows metrics) amount) cap) ERR_BORROW_CAP_EXCEEDED)
            true
          )
          true
        )
        true
      )
      
      ;; Accrue interest
      (try! (contract-call? sbtc-integration accrue-interest asset-principal))
      
      ;; Check user can borrow this amount
      (match (get-max-borrow-amount tx-sender asset-principal)
        max-borrow (begin
          (asserts! (>= max-borrow amount) ERR_INSUFFICIENT_COLLATERAL)
          
          ;; Update user position
          (let ((current-position (default-to 
                                   { 
                                     supply-balance: u0, 
                                     borrow-balance: u0, 
                                     supply-index: u1000000, 
                                     borrow-index: u1000000,
                                     last-interaction: block-height 
                                   }
                                   (get-user-position tx-sender asset-principal))))
            (map-set user-positions 
              { user: tx-sender, asset: asset-principal }
              (merge current-position {
                borrow-balance: (+ (get borrow-balance current-position) amount),
                last-interaction: block-height
              })
            )
          )
          
          ;; Transfer tokens to user
          (try! (as-contract (contract-call? asset transfer amount tx-sender tx-sender none)))
          
          (print { 
            event: "borrow", 
            user: tx-sender, 
            asset: asset-principal, 
            amount: amount 
          })
          (ok true)
        )
        ERR_INSUFFICIENT_COLLATERAL
      )
    )
  )
)

(define-public (repay (asset ft-trait) (amount uint))
  "Repay borrowed sBTC"
  (let ((asset-principal (contract-of asset)))
    (begin
      ;; Validate operation
      (try! (contract-call? sbtc-integration validate-operation asset-principal "borrow"))
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      
      ;; Accrue interest
      (try! (contract-call? sbtc-integration accrue-interest asset-principal))
      
      ;; Check user has borrow balance
      (let ((current-borrow (get-user-borrow-balance tx-sender asset-principal)))
        (asserts! (> current-borrow u0) ERR_POSITION_NOT_FOUND)
        
        ;; Calculate actual repay amount (min of amount and balance)
        (let ((repay-amount (if (<= amount current-borrow) amount current-borrow)))
          
          ;; Transfer tokens from user
          (try! (contract-call? asset transfer repay-amount tx-sender (as-contract tx-sender) none))
          
          ;; Update user position
          (match (get-user-position tx-sender asset-principal)
            position (begin
              (map-set user-positions 
                { user: tx-sender, asset: asset-principal }
                (merge position {
                  borrow-balance: (- (get borrow-balance position) repay-amount),
                  last-interaction: block-height
                })
              )
              
              (print { 
                event: "repay", 
                user: tx-sender, 
                asset: asset-principal, 
                amount: repay-amount 
              })
              (ok repay-amount)
            )
            ERR_POSITION_NOT_FOUND
          )
        )
      )
    )
  )
)

;; =============================================================================
;; LIQUIDATION FUNCTIONS
;; =============================================================================

(define-public (liquidate (borrower principal) (asset ft-trait) (repay-amount uint) (collateral-asset ft-trait))
  "Liquidate undercollateralized position"
  (let ((asset-principal (contract-of asset))
        (collateral-principal (contract-of collateral-asset)))
    (begin
      ;; Check if borrower can be liquidated
      (match (get-liquidation-info borrower)
        liq-info (begin
          (asserts! (get can-liquidate liq-info) ERR_LIQUIDATION_NOT_AVAILABLE)
          (asserts! (<= repay-amount (get max-liquidation-amount liq-info)) ERR_INVALID_AMOUNT)
          
          ;; Accrue interest for both assets
          (try! (contract-call? sbtc-integration accrue-interest asset-principal))
          (try! (contract-call? sbtc-integration accrue-interest collateral-principal))
          
          ;; Calculate collateral to seize
          (match (contract-call? sbtc-integration get-sbtc-price)
            price (match (contract-call? sbtc-integration get-asset-config collateral-principal)
              collateral-config (let ((liquidation-penalty (get liquidation-penalty collateral-config))
                                     (collateral-to-seize (* repay-amount (+ u1000000 liquidation-penalty))))
                
                ;; Verify borrower has sufficient collateral
                (let ((borrower-collateral (get-user-supply-balance borrower collateral-principal)))
                  (asserts! (>= borrower-collateral collateral-to-seize) ERR_INSUFFICIENT_COLLATERAL)
                  
                  ;; Transfer repayment from liquidator
                  (try! (contract-call? asset transfer repay-amount tx-sender (as-contract tx-sender) none))
                  
                  ;; Transfer collateral to liquidator
                  (try! (as-contract (contract-call? collateral-asset transfer collateral-to-seize tx-sender tx-sender none)))
                  
                  ;; Update borrower positions
                  (match (get-user-position borrower asset-principal)
                    borrow-position (begin
                      (map-set user-positions 
                        { user: borrower, asset: asset-principal }
                        (merge borrow-position {
                          borrow-balance: (- (get borrow-balance borrow-position) repay-amount),
                          last-interaction: block-height
                        })
                      )
                      
                      ;; Update borrower collateral position
                      (match (get-user-position borrower collateral-principal)
                        collateral-position (begin
                          (map-set user-positions 
                            { user: borrower, asset: collateral-principal }
                            (merge collateral-position {
                              supply-balance: (- (get supply-balance collateral-position) collateral-to-seize),
                              last-interaction: block-height
                            })
                          )
                          
                          (print { 
                            event: "liquidation", 
                            liquidator: tx-sender,
                            borrower: borrower,
                            debt-asset: asset-principal,
                            repay-amount: repay-amount,
                            collateral-asset: collateral-principal,
                            collateral-seized: collateral-to-seize
                          })
                          (ok true)
                        )
                        ERR_POSITION_NOT_FOUND
                      )
                    )
                    ERR_POSITION_NOT_FOUND
                  )
                )
              )
              ERR_LIQUIDATION_NOT_AVAILABLE
            )
            ERR_LIQUIDATION_NOT_AVAILABLE
          )
        )
        ERR_HEALTH_FACTOR_OK
      )
    )
  )
)

;; =============================================================================
;; INTEGRATION FUNCTIONS
;; =============================================================================

(define-public (get-account-summary (user principal))
  "Get comprehensive account summary"
  (let ((sbtc-supply (get-user-supply-balance user (get-constant sbtc-integration SBTC_MAINNET)))
        (sbtc-borrow (get-user-borrow-balance user (get-constant sbtc-integration SBTC_MAINNET))))
    (match (calculate-health-factor user)
      health-factor (match (calculate-account-liquidity user)
        liquidity (ok {
          supply-balance: sbtc-supply,
          borrow-balance: sbtc-borrow,
          health-factor: health-factor,
          account-liquidity: liquidity,
          can-be-liquidated: (< health-factor u1000000)
        })
        (err u0)
      )
      (err u0)
    )
  )
)





