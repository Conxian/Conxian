;; sbtc-lending-integration.clar
;; sBTC Lending Integration - extends comprehensive lending system
;; Provides sBTC-specific lending, borrowing, and collateral management

(use-trait sip-010-ft-trait .sip-010-trait-ft-standard.sip-010-trait)

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
(define-constant MIN_SUPPLY_AMOUNT u100000)     ;; 0.001 BTC
(define-constant MIN_BORROW_AMOUNT u100000)     ;; 0.001 BTC
(define-constant LIQUIDATION_CLOSE_FACTOR u500000)  ;; 50% max liquidation

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================

(define-map user-positions
  { user: principal, asset: principal }
  {
    supply-balance: uint,        ;; User's supply balance
    borrow-balance: uint,        ;; User's borrow balance
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
  "Get user's lending position for asset"
  (map-get? user-positions { user: user, asset: asset })
)

(define-read-only (get-user-supply-balance (user principal) (asset principal))
  "Get user's current supply balance with accrued interest"
  (match (get-user-position user asset)
    position (let (
      (supply-balance (get supply-balance position))
      (supply-index (get supply-index position))
    )
      ;; Calculate accrued interest based on current supply rate
      (match (contract-call? sbtc-integration calculate-interest-rates asset)
        rates (let (
          (current-index (+ supply-index u1))  ;; Simplified - should use actual index calculation
        )
          (* supply-balance (/ current-index supply-index))
        )
        supply-balance
      )
    )
    u0
  )
)

(define-read-only (get-user-borrow-balance (user principal) (asset principal))
  "Get user's current borrow balance with accrued interest"
  (match (get-user-position user asset)
    position (let (
      (borrow-balance (get borrow-balance position))
      (borrow-index (get borrow-index position))
    )
      ;; Calculate accrued interest on borrows
      (match (contract-call? sbtc-integration calculate-interest-rates asset)
        rates (let (
          (current-index (+ borrow-index u1))  ;; Simplified calculation
        )
          (* borrow-balance (/ current-index borrow-index))
        )
        borrow-balance
      )
    )
    u0
  )
)

(define-read-only (calculate-account-liquidity (user principal))
  "Calculate user's account liquidity (collateral value - borrowed value)"
  (let (
    (sbtc-supply (get-user-supply-balance user (contract-call? sbtc-integration get-sbtc-mainnet)))
    (sbtc-borrow (get-user-borrow-balance user (contract-call? sbtc-integration get-sbtc-mainnet)))
  )
    (match (contract-call? sbtc-integration calculate-collateral-value 
      (contract-call? sbtc-integration get-sbtc-mainnet) sbtc-supply)
      collateral-value (match (contract-call? sbtc-integration get-sbtc-price)
        price (let (
          (borrow-value (* sbtc-borrow price))
        )
          (if (>= collateral-value borrow-value)
            (ok (- collateral-value borrow-value))
            (ok u0)  ;; Account is underwater
          )
        )
        (ok u0)
      )
      (ok u0)
    )
  )
)

(define-read-only (calculate-health-factor (user principal))
  "Calculate user's health factor (>1.0 = healthy, <1.0 = can be liquidated)"
  (let (
    (sbtc-supply (get-user-supply-balance user (contract-call? sbtc-integration get-sbtc-mainnet)))
    (sbtc-borrow (get-user-borrow-balance user (contract-call? sbtc-integration get-sbtc-mainnet)))
  )
    (if (is-eq sbtc-borrow u0)
      (ok u2000000)  ;; Very high health factor if no borrows
      (match (contract-call? sbtc-integration calculate-liquidation-threshold 
        (contract-call? sbtc-integration get-sbtc-mainnet) sbtc-supply)
        liquidation-value (match (contract-call? sbtc-integration get-sbtc-price)
          price (let (
            (borrow-value (* sbtc-borrow price))
          )
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
    health-factor (if (< health-factor u1000000)  ;; Health factor < 1.0
      (let (
        (sbtc-supply (get-user-supply-balance borrower (contract-call? sbtc-integration get-sbtc-mainnet)))
        (sbtc-borrow (get-user-borrow-balance borrower (contract-call? sbtc-integration get-sbtc-mainnet)))
      )
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

(define-public (supply (asset <sip-010-ft-trait>) (amount uint))
  "Supply sBTC to earn interest"
  (let (
    (asset-principal (contract-of asset))
  )
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
      (let (
        (current-position (default-to
          {
            supply-balance: u0,
            borrow-balance: u0,
            supply-index: u1000000,
            borrow-index: u1000000,
            last-interaction: block-height
          }
          (get-user-position tx-sender asset-principal)
        ))
      )
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

(define-public (withdraw (asset <sip-010-ft-trait>) (amount uint))
  "Withdraw supplied sBTC"
  (let (
    (asset-principal (contract-of asset))
  )
    (begin
      ;; Validate operation
      (try! (contract-call? sbtc-integration validate-operation asset-principal "supply"))
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      
      ;; Accrue interest
      (try! (contract-call? sbtc-integration accrue-interest asset-principal))
      
      ;; Check user has sufficient balance
      (let (
        (current-supply (get-user-supply-balance tx-sender asset-principal))
      )
        (asserts! (>= current-supply amount) ERR_INSUFFICIENT_LIQUIDITY)
        
        ;; Check account liquidity after withdrawal
        (match (calculate-account-liquidity tx-sender)
          liquidity (match (contract-call? sbtc-integration get-sbtc-price)
            price (let (
              (withdrawal-value (* amount price))
            )
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

(define-public (borrow (asset <sip-010-ft-trait>) (amount uint))
  "Borrow sBTC against collateral"
  (let (
    (asset-principal (contract-of asset))
  )
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
          (let (
            (current-position (default-to
              {
                supply-balance: u0,
                borrow-balance: u0,
                supply-index: u1000000,
                borrow-index: u1000000,
                last-interaction: block-height
              }
              (get-user-position tx-sender asset-principal)
            ))
          )
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

(define-public (repay (asset <sip-010-ft-trait>) (amount uint))
  "Repay borrowed sBTC"
  (let (
    (asset-principal (contract-of asset))
    (user tx-sender)
  )
    (begin
      ;; Validate operation
      (try! (contract-call? sbtc-integration validate-operation asset-principal "borrow"))
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)

      ;; Accrue interest
      (try! (contract-call? sbtc-integration accrue-interest asset-principal))
      
      ;; Get user position
      (let ((position (unwrap! (map-get? user-positions { user: user, asset: asset-principal }) 
                             (err ERR_POSITION_NOT_FOUND))))
        (let ((borrow-balance (get borrow-balance position)))
          (asserts! (<= amount borrow-balance) ERR_INVALID_AMOUNT)
          
          ;; Transfer tokens from user to contract
          (try! (contract-call? asset transfer amount user (as-contract tx-sender) (none)))
          
          ;; Update user position
          (map-set! user-positions { user: user, asset: asset-principal }
            {
              supply-balance: (get supply-balance position),
              borrow-balance: (- borrow-balance amount),
              supply-index: (get supply-index position),
              borrow-index: (get borrow-index position),
              last-interaction: block-height
            }
          )
          
          ;; Update global borrow state
          (let ((market (unwrap! (map-get? market-state { asset: asset-principal })
                               (err ERR_POSITION_NOT_FOUND))))
            (map-set! market-state { asset: asset-principal }
              {
                total-supply: (get total-supply market),
                total-borrows: (- (get total-borrows market) amount),
                supply-rate: (get supply-rate market),
                borrow-rate: (get borrow-rate market),
                supply-index: (get supply-index market),
                borrow-index: (get borrow-index market),
                last-updated: block-height
              }
            )
          )
          
          (ok true)
        )
      )
    )
  )
)