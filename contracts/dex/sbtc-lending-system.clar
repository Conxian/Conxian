;; sbtc-lending-system.clar  
;; Enhanced Lending System with sBTC Collateral Support
;; Implements lending/borrowing with sBTC as collateral and enterprise bond integration

(use-trait sip-010-ft-trait '.all-traits.sip-010-ft-trait)

;; =============================================================================
;; CONSTANTS
;; =============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INVALID_ASSET (err u301))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u302))
(define-constant ERR_POSITION_NOT_FOUND (err u303))
(define-constant ERR_LIQUIDATION_NOT_ALLOWED (err u304))
(define-constant ERR_MARKET_PAUSED (err u305))
(define-constant ERR_BORROW_CAP_EXCEEDED (err u306))
(define-constant ERR_SUPPLY_CAP_EXCEEDED (err u307))
(define-constant ERR_INVALID_AMOUNT (err u308))
(define-constant ERR_HEALTH_FACTOR_TOO_LOW (err u309))

;; Lending parameters
(define-constant MIN_HEALTH_FACTOR u1200000) ;; 1.2 minimum health factor
(define-constant LIQUIDATION_INCENTIVE u1100000) ;; 10% liquidation incentive
(define-constant CLOSE_FACTOR u5000) ;; 50% max liquidation per transaction
(define-constant ENTERPRISE_LOAN_THRESHOLD u100000000000) ;; 100k tokens for enterprise bonds

;; Interest rate model constants
(define-constant BLOCKS_PER_YEAR u52560) ;; ~365 * 144 blocks
(define-constant BASE_RATE u200000) ;; 2% base rate
(define-constant MULTIPLIER u180000) ;; 18% rate multiplier
(define-constant JUMP_MULTIPLIER u4000000) ;; 400% jump rate multiplier  
(define-constant KINK u800000) ;; 80% optimal utilization

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================

(define-map lending-markets
  { asset: principal }
  {
    supply-enabled: bool,
    borrow-enabled: bool,
    ltv: uint, ;; loan-to-value ratio (basis points)
    liquidation-threshold: uint, ;; liquidation threshold (basis points)
    liquidation-penalty: uint, ;; liquidation penalty (basis points)
    reserve-factor: uint, ;; reserve factor (basis points)
    supply-cap: (optional uint),
    borrow-cap: (optional uint),
    enterprise-bonds-enabled: bool,
    active: bool
  })

(define-map market-state
  { asset: principal }
  {
    total-supply: uint,
    total-borrows: uint,
    total-reserves: uint,
    supply-index: uint,
    borrow-index: uint,
    supply-rate: uint,
    borrow-rate: uint,
    last-accrual-block: uint,
    utilization-rate: uint
  })

(define-map user-positions
  { user: principal, asset: principal }
  {
    supplied: uint,
    borrowed: uint,
    supply-index: uint,
    borrow-index: uint,
    last-interaction-block: uint,
    collateral-enabled: bool,
    enterprise-bond-eligible: bool
  })

(define-map collateral-factors
  { asset: principal }
  {
    collateral-factor: uint, ;; max % of collateral value that can be borrowed against
    liquidation-threshold: uint, ;; threshold below which liquidation can occur
    liquidation-penalty: uint, ;; penalty for liquidation
    price-feed: principal, ;; oracle contract
    last-price-update: uint
  })

;; Enterprise bond tracking
(define-map enterprise-positions
  { user: principal }
  {
    total-borrowed: uint,
    bond-series-count: uint,
    bond-eligible: bool,
    risk-rating: (string-ascii 10),
    last-assessment: uint
  })

;; Liquidation tracking
(define-map liquidation-history
  { liquidator: principal, borrower: principal, asset: principal, block: uint }
  {
    collateral-seized: uint,
    debt-repaid: uint,
    liquidation-incentive: uint,
    health-factor-before: uint,
    health-factor-after: uint
  })

;; Market pause controls
(define-data-var global-pause bool false)
(define-map market-pause { asset: principal } bool)

;; =============================================================================
;; SUPPLY FUNCTIONS
;; =============================================================================

(define-public (supply (asset <sip-010-ft-trait>) (amount uint))
  "Supply tokens to earn interest"
  (let ((asset-contract (contract-of asset)))
    (begin
      (asserts! (not (var-get global-pause)) ERR_MARKET_PAUSED)
      (asserts! (not (unwrap! (map-get? market-pause { asset: asset-contract }) (ok false))) ERR_MARKET_PAUSED)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      
      ;; Validate market
      (let ((market (unwrap! (map-get? lending-markets { asset: asset-contract }) ERR_INVALID_ASSET)))
        (asserts! (get active market) ERR_MARKET_PAUSED)
        (asserts! (get supply-enabled market) ERR_MARKET_PAUSED)
        
        ;; Check supply cap
        (match (get supply-cap market)
          cap (let ((current-supply (get-total-supply asset-contract)))
                (asserts! (<= (+ current-supply amount) cap) ERR_SUPPLY_CAP_EXCEEDED))
          true)
        
        ;; Accrue interest
        (try! (accrue-interest asset-contract))
        
        ;; Transfer tokens to contract
        (try! (contract-call? asset transfer amount tx-sender (as-contract tx-sender) none))
        
        ;; Update user position
        (let ((user-pos (default-to {
                          supplied: u0,
                          borrowed: u0,
                          supply-index: u1000000,
                          borrow-index: u1000000,
                          last-interaction-block: stacks-block-height,
                          collateral-enabled: false,
                          enterprise-bond-eligible: false
                        } (map-get? user-positions { user: tx-sender, asset: asset-contract }))))
          
          (map-set user-positions
            { user: tx-sender, asset: asset-contract }
            (merge user-pos {
              supplied: (+ (get supplied user-pos) amount),
              last-interaction-block: stacks-block-height
            })))
        
        ;; Update market state
        (let ((market-data (unwrap-panic (map-get? market-state { asset: asset-contract }))))
          (map-set market-state
            { asset: asset-contract }
            (merge market-data {
              total-supply: (+ (get total-supply market-data) amount)
            })))
        
        (print {
          event: "supply",
          user: tx-sender,
          asset: asset-contract,
          amount: amount
        })
        
        (ok amount)))))

(define-public (withdraw (asset <sip-010-ft-trait>) (amount uint))
  "Withdraw supplied tokens"
  (let ((asset-contract (contract-of asset)))
    (begin
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      
      ;; Accrue interest
      (try! (accrue-interest asset-contract))
      
      ;; Check user position
      (let ((user-pos (unwrap! (map-get? user-positions { user: tx-sender, asset: asset-contract }) ERR_POSITION_NOT_FOUND)))
        (asserts! (>= (get supplied user-pos) amount) ERR_INSUFFICIENT_COLLATERAL)
        
        ;; If collateral enabled, check health factor
        (if (get collateral-enabled user-pos)
          (let ((new-supplied (- (get supplied user-pos) amount)))
            (asserts! (>= (try! (calculate-health-factor tx-sender)) MIN_HEALTH_FACTOR) ERR_HEALTH_FACTOR_TOO_LOW))
          true)
        
        ;; Transfer tokens to user
        (try! (contract-call? asset transfer amount (as-contract tx-sender) tx-sender none))
        
        ;; Update user position
        (map-set user-positions
          { user: tx-sender, asset: asset-contract }
          (merge user-pos {
            supplied: (- (get supplied user-pos) amount),
            last-interaction-block: stacks-block-height
          }))
        
        ;; Update market state
        (let ((market-data (unwrap-panic (map-get? market-state { asset: asset-contract }))))
          (map-set market-state
            { asset: asset-contract }
            (merge market-data {
              total-supply: (- (get total-supply market-data) amount)
            })))
        
        (print {
          event: "withdraw",
          user: tx-sender,
          asset: asset-contract,
          amount: amount
        })
        
        (ok amount)))))

;; =============================================================================
;; BORROW FUNCTIONS  
;; =============================================================================

(define-public (borrow (asset <sip-010-ft-trait>) (amount uint))
  "Borrow tokens against collateral"
  (let ((asset-contract (contract-of asset)))
    (begin
      (asserts! (not (var-get global-pause)) ERR_MARKET_PAUSED)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      
      ;; Validate market
      (let ((market (unwrap! (map-get? lending-markets { asset: asset-contract }) ERR_INVALID_ASSET)))
        (asserts! (get active market) ERR_MARKET_PAUSED)
        (asserts! (get borrow-enabled market) ERR_MARKET_PAUSED)
        
        ;; Check borrow cap
        (match (get borrow-cap market)
          cap (let ((current-borrows (get-total-borrows asset-contract)))
                (asserts! (<= (+ current-borrows amount) cap) ERR_BORROW_CAP_EXCEEDED))
          true)
        
        ;; Accrue interest
        (try! (accrue-interest asset-contract))
        
        ;; Check health factor after borrow
        (let ((current-health (try! (calculate-health-factor tx-sender))))
          (asserts! (>= current-health MIN_HEALTH_FACTOR) ERR_HEALTH_FACTOR_TOO_LOW))
        
        ;; Check if enterprise bond eligible
        (let ((total-borrow-value (+ (get-user-total-borrow-value tx-sender) amount)))
          (if (>= total-borrow-value ENTERPRISE_LOAN_THRESHOLD)
            (try! (initiate-enterprise-bond tx-sender amount asset-contract))
            true))
        
        ;; Transfer tokens to user
        (try! (contract-call? asset transfer amount (as-contract tx-sender) tx-sender none))
        
        ;; Update user position
        (let ((user-pos (default-to {
                          supplied: u0,
                          borrowed: u0,
                          supply-index: u1000000,
                          borrow-index: u1000000,
                          last-interaction-block: stacks-block-height,
                          collateral-enabled: false,
                          enterprise-bond-eligible: false
                        } (map-get? user-positions { user: tx-sender, asset: asset-contract }))))
          
          (map-set user-positions
            { user: tx-sender, asset: asset-contract }
            (merge user-pos {
              borrowed: (+ (get borrowed user-pos) amount),
              last-interaction-block: stacks-block-height,
              enterprise-bond-eligible: (>= total-borrow-value ENTERPRISE_LOAN_THRESHOLD)
            })))
        
        ;; Update market state
        (let ((market-data (unwrap-panic (map-get? market-state { asset: asset-contract }))))
          (map-set market-state
            { asset: asset-contract }
            (merge market-data {
              total-borrows: (+ (get total-borrows market-data) amount)
            })))
        
        (print {
          event: "borrow",
          user: tx-sender,
          asset: asset-contract,
          amount: amount,
          enterprise-eligible: (>= total-borrow-value ENTERPRISE_LOAN_THRESHOLD)
        })
        
        (ok amount)))))

(define-public (repay (asset <sip-010-ft-trait>) (amount uint))
  "Repay borrowed tokens"
  (let ((asset-contract (contract-of asset)))
    (begin
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      
      ;; Accrue interest
      (try! (accrue-interest asset-contract))
      
      ;; Check user position
      (let ((user-pos (unwrap! (map-get? user-positions { user: tx-sender, asset: asset-contract }) ERR_POSITION_NOT_FOUND)))
        (let ((repay-amount (min amount (get borrowed user-pos))))
          
          ;; Transfer tokens from user
          (try! (contract-call? asset transfer repay-amount tx-sender (as-contract tx-sender) none))
          
          ;; Update user position
          (map-set user-positions
            { user: tx-sender, asset: asset-contract }
            (merge user-pos {
              borrowed: (- (get borrowed user-pos) repay-amount),
              last-interaction-block: stacks-block-height
            }))
          
          ;; Update market state
          (let ((market-data (unwrap-panic (map-get? market-state { asset: asset-contract }))))
            (map-set market-state
              { asset: asset-contract }
              (merge market-data {
                total-borrows: (- (get total-borrows market-data) repay-amount)
              })))
          
          (print {
            event: "repay",
            user: tx-sender,
            asset: asset-contract,
            amount: repay-amount
          })
          
          (ok repay-amount))))))

;; =============================================================================
;; COLLATERAL MANAGEMENT
;; =============================================================================

(define-public (enable-collateral (asset <sip-010-ft-trait>))
  "Enable asset as collateral"
  (let ((asset-contract (contract-of asset)))
    (begin
      ;; Check user has supply position
      (let ((user-pos (unwrap! (map-get? user-positions { user: tx-sender, asset: asset-contract }) ERR_POSITION_NOT_FOUND)))
        (asserts! (> (get supplied user-pos) u0) ERR_INSUFFICIENT_COLLATERAL)
        
        ;; Enable collateral
        (map-set user-positions
          { user: tx-sender, asset: asset-contract }
          (merge user-pos {
            collateral-enabled: true,
            last-interaction-block: stacks-block-height
          }))
        
        (print {
          event: "collateral-enabled",
          user: tx-sender,
          asset: asset-contract
        })
        
        (ok true)))))

(define-public (disable-collateral (asset <sip-010-ft-trait>))
  "Disable asset as collateral"
  (let ((asset-contract (contract-of asset)))
    (begin
      ;; Check health factor remains above threshold
      (asserts! (>= (try! (calculate-health-factor tx-sender)) MIN_HEALTH_FACTOR) ERR_HEALTH_FACTOR_TOO_LOW)
      
      ;; Disable collateral
      (let ((user-pos (unwrap! (map-get? user-positions { user: tx-sender, asset: asset-contract }) ERR_POSITION_NOT_FOUND)))
        (map-set user-positions
          { user: tx-sender, asset: asset-contract }
          (merge user-pos {
            collateral-enabled: false,
            last-interaction-block: stacks-block-height
          }))
        
        (print {
          event: "collateral-disabled",
          user: tx-sender,
          asset: asset-contract
        })
        
        (ok true)))))

;; =============================================================================
;; LIQUIDATION FUNCTIONS
;; =============================================================================

(define-public (liquidate (borrower principal) 
                         (repay-asset <sip-010-ft-trait>) 
                         (collateral-asset <sip-010-ft-trait>) 
                         (repay-amount uint))
  "Liquidate undercollateralized position"
  (let ((repay-contract (contract-of repay-asset))
        (collateral-contract (contract-of collateral-asset)))
    (begin
      ;; Check borrower health factor
      (let ((health-factor (try! (calculate-health-factor borrower))))
        (asserts! (< health-factor u1000000) ERR_LIQUIDATION_NOT_ALLOWED)
        
        ;; Accrue interest for both assets
        (try! (accrue-interest repay-contract))
        (try! (accrue-interest collateral-contract))
        
        ;; Get positions
        (let ((borrow-pos (unwrap! (map-get? user-positions { user: borrower, asset: repay-contract }) ERR_POSITION_NOT_FOUND))
              (collateral-pos (unwrap! (map-get? user-positions { user: borrower, asset: collateral-contract }) ERR_POSITION_NOT_FOUND)))
          
          ;; Calculate liquidation amounts
          (let ((max-repay (/ (* (get borrowed borrow-pos) CLOSE_FACTOR) u10000))
                (actual-repay (min repay-amount max-repay)))
            
            ;; Calculate collateral to seize
            (let ((collateral-to-seize (try! (calculate-seize-tokens 
                                              repay-contract 
                                              collateral-contract 
                                              actual-repay))))
              
              ;; Transfer repayment from liquidator
              (try! (contract-call? repay-asset transfer actual-repay tx-sender (as-contract tx-sender) none))
              
              ;; Transfer collateral to liquidator
              (try! (contract-call? collateral-asset transfer collateral-to-seize (as-contract tx-sender) tx-sender none))
              
              ;; Update borrower positions
              (map-set user-positions
                { user: borrower, asset: repay-contract }
                (merge borrow-pos {
                  borrowed: (- (get borrowed borrow-pos) actual-repay)
                }))
              
              (map-set user-positions
                { user: borrower, asset: collateral-contract }
                (merge collateral-pos {
                  supplied: (- (get supplied collateral-pos) collateral-to-seize)
                }))
              
              ;; Record liquidation
              (map-set liquidation-history
                { liquidator: tx-sender, borrower: borrower, asset: repay-contract, block: stacks-block-height }
                {
                  collateral-seized: collateral-to-seize,
                  debt-repaid: actual-repay,
                  liquidation-incentive: (- collateral-to-seize actual-repay),
                  health-factor-before: health-factor,
                  health-factor-after: (try! (calculate-health-factor borrower))
                })
              
              (print {
                event: "liquidation",
                liquidator: tx-sender,
                borrower: borrower,
                repay-asset: repay-contract,
                collateral-asset: collateral-contract,
                repay-amount: actual-repay,
                collateral-seized: collateral-to-seize
              })
              
              (ok { repaid: actual-repay, seized: collateral-to-seize }))))))))

;; =============================================================================
;; ENTERPRISE BOND INTEGRATION
;; =============================================================================

(define-private (initiate-enterprise-bond (borrower principal) (amount uint) (asset-contract principal))
  "Initiate enterprise bond for large loan"
  (begin
    ;; Update enterprise position
    (let ((enterprise-pos (default-to {
                            total-borrowed: u0,
                            bond-series-count: u0,
                            bond-eligible: true,
                            risk-rating: "AAA",
                            last-assessment: stacks-block-height
                          } (map-get? enterprise-positions { user: borrower }))))
      
      (map-set enterprise-positions
        { user: borrower }
        (merge enterprise-pos {
          total-borrowed: (+ (get total-borrowed enterprise-pos) amount),
          bond-series-count: (+ (get bond-series-count enterprise-pos) u1),
          last-assessment: stacks-block-height
        }))
      
      ;; Trigger bond issuance (would call bond-issuance-system.clar)
      (print {
        event: "enterprise-bond-initiated",
        borrower: borrower,
        amount: amount,
        asset: asset-contract,
        bond-series: (+ (get bond-series-count enterprise-pos) u1)
      })
      
      (ok true))))

;; =============================================================================
;; INTEREST RATE CALCULATIONS
;; =============================================================================

(define-public (accrue-interest (asset-contract principal))
  "Accrue interest for market"
  (match (map-get? market-state { asset: asset-contract })
    market-data (let ((blocks-elapsed (- stacks-block-height (get last-accrual-block market-data))))
      (if (> blocks-elapsed u0)
        (let ((utilization (calculate-utilization-rate asset-contract))
              (borrow-rate (calculate-borrow-rate utilization))
              (supply-rate (calculate-supply-rate utilization borrow-rate asset-contract))
              (interest-accumulated (* (* (get total-borrows market-data) borrow-rate) blocks-elapsed)))
          
          ;; Update market state
          (map-set market-state
            { asset: asset-contract }
            (merge market-data {
              total-borrows: (+ (get total-borrows market-data) interest-accumulated),
              total-reserves: (+ (get total-reserves market-data) (calculate-reserves interest-accumulated asset-contract)),
              borrow-rate: borrow-rate,
              supply-rate: supply-rate,
              utilization-rate: utilization,
              last-accrual-block: stacks-block-height
            }))
          
          (ok interest-accumulated))
        (ok u0)))
    ERR_INVALID_ASSET))

;; =============================================================================
;; UTILITY FUNCTIONS
;; =============================================================================

(define-read-only (calculate-health-factor (user principal))
  "Calculate user health factor"
  (let ((collateral-value (get-user-collateral-value user))
        (borrow-value (get-user-borrow-value user)))
    (if (is-eq borrow-value u0)
      (ok u1000000000) ;; Max health factor if no borrows
      (ok (/ (* collateral-value u1000000) borrow-value)))))

(define-read-only (calculate-utilization-rate (asset-contract principal))
  "Calculate market utilization rate"
  (match (map-get? market-state { asset: asset-contract })
    market-data (let ((total-supply (get total-supply market-data))
                      (total-borrows (get total-borrows market-data)))
      (if (is-eq total-supply u0)
        u0
        (/ (* total-borrows u1000000) total-supply)))
    u0))

(define-read-only (calculate-borrow-rate (utilization uint))
  "Calculate current borrow rate based on utilization"
  (if (<= utilization KINK)
    (+ BASE_RATE (/ (* utilization MULTIPLIER) u1000000))
    (+ BASE_RATE (+ MULTIPLIER (/ (* (- utilization KINK) JUMP_MULTIPLIER) u1000000)))))

(define-read-only (calculate-supply-rate (utilization uint) (borrow-rate uint) (asset-contract principal))
  "Calculate current supply rate"
  (match (map-get? lending-markets { asset: asset-contract })
    market (let ((reserve-factor (get reserve-factor market)))
      (/ (* (* utilization borrow-rate) (- u1000000 reserve-factor)) u1000000))
    u0))

(define-read-only (get-user-collateral-value (user principal))
  "Get total collateral value for user"
  ;; Implementation would iterate through all user positions
  ;; This is a simplified version
  u0)

(define-read-only (get-user-borrow-value (user principal))
  "Get total borrow value for user"
  ;; Implementation would iterate through all user positions
  ;; This is a simplified version  
  u0)

(define-read-only (get-user-total-borrow-value (user principal))
  "Get total USD value of all user borrows"
  ;; Implementation would calculate total borrow value across all assets
  u0)

(define-read-only (get-total-supply (asset-contract principal))
  "Get total supply for asset"
  (match (map-get? market-state { asset: asset-contract })
    market-data (get total-supply market-data)
    u0))

(define-read-only (get-total-borrows (asset-contract principal))
  "Get total borrows for asset"
  (match (map-get? market-state { asset: asset-contract })
    market-data (get total-borrows market-data)
    u0))

(define-read-only (calculate-seize-tokens (repay-asset principal) 
                                        (collateral-asset principal) 
                                        (repay-amount uint))
  "Calculate tokens to seize in liquidation"
  ;; Simplified calculation - would use oracle prices in production
  (ok (/ (* repay-amount LIQUIDATION_INCENTIVE) u1000000)))

(define-read-only (calculate-reserves (interest-accumulated uint) (asset-contract principal))
  "Calculate reserves from interest"
  (match (map-get? lending-markets { asset: asset-contract })
    market (/ (* interest-accumulated (get reserve-factor market)) u1000000)
    u0))

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-market-info (asset-contract principal))
  "Get market information"
  {
    config: (map-get? lending-markets { asset: asset-contract }),
    state: (map-get? market-state { asset: asset-contract })
  })

(define-read-only (get-user-position (user principal) (asset-contract principal))
  "Get user position"
  (map-get? user-positions { user: user, asset: asset-contract }))

(define-read-only (get-enterprise-position (user principal))
  "Get enterprise position"
  (map-get? enterprise-positions { user: user }))

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-public (add-market (asset-contract principal) 
                          (ltv uint) 
                          (liq-threshold uint) 
                          (liq-penalty uint) 
                          (reserve-factor uint))
  "Add new lending market"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    ;; Set market config
    (map-set lending-markets
      { asset: asset-contract }
      {
        supply-enabled: true,
        borrow-enabled: true,
        ltv: ltv,
        liquidation-threshold: liq-threshold,
        liquidation-penalty: liq-penalty,
        reserve-factor: reserve-factor,
        supply-cap: none,
        borrow-cap: none,
        enterprise-bonds-enabled: true,
        active: true
      })
    
    ;; Initialize market state
    (map-set market-state
      { asset: asset-contract }
      {
        total-supply: u0,
        total-borrows: u0,
        total-reserves: u0,
        supply-index: u1000000,
        borrow-index: u1000000,
        supply-rate: u0,
        borrow-rate: u0,
        last-accrual-block: stacks-block-height,
        utilization-rate: u0
      })
    
    (print {
      event: "market-added",
      asset: asset-contract,
      ltv: ltv
    })
    
    (ok true)))

;; Initialize contract
(print {
  event: "sbtc-lending-system-deployed",
  owner: CONTRACT_OWNER,
  version: "1.0.0"
})





