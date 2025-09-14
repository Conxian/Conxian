;; sbtc-bond-integration.clar
;; sBTC Bond Integration - Advanced bond issuance with sBTC collateral and yields
;; Provides enterprise bond structuring, sBTC yield distribution, and risk management

(use-trait ft-trait .sip-010-trait)

;; =============================================================================
;; CONSTANTS AND ERROR CODES
;; =============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u5000))
(define-constant ERR_INVALID_BOND_TERMS (err u5001))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u5002))
(define-constant ERR_BOND_NOT_FOUND (err u5003))
(define-constant ERR_BOND_ALREADY_MATURED (err u5004))
(define-constant ERR_INSUFFICIENT_YIELD (err u5005))
(define-constant ERR_EARLY_REDEMPTION_NOT_ALLOWED (err u5006))
(define-constant ERR_LIQUIDATION_THRESHOLD_BREACHED (err u5007))
(define-constant ERR_INVALID_YIELD_DISTRIBUTION (err u5008))

;; Bond parameters
(define-constant MIN_BOND_AMOUNT u10000000000)    ;; 100 BTC minimum
(define-constant MAX_BOND_AMOUNT u500000000000)   ;; 5000 BTC maximum
(define-constant MIN_MATURITY_BLOCKS u52560)      ;; ~1 year (10min blocks)
(define-constant MAX_MATURITY_BLOCKS u262800)     ;; ~5 years
(define-constant COLLATERAL_RATIO u1200000)       ;; 120% collateralization
(define-constant LIQUIDATION_THRESHOLD u1100000)  ;; 110% liquidation threshold

;; Yield parameters
(define-constant BASE_YIELD_RATE u50000)          ;; 5% base yield
(define-constant MAX_YIELD_RATE u200000)          ;; 20% max yield
(define-constant YIELD_PRECISION u1000000)        ;; 6 decimal precision

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================

(define-map sbtc-bonds
  { bond-id: uint }
  {
    issuer: principal,         ;; Bond issuer
    principal-amount: uint,    ;; Bond principal in satoshis
    coupon-rate: uint,         ;; Annual coupon rate
    maturity-block: uint,      ;; Maturity block height
    issue-block: uint,         ;; Issue block height
    collateral-amount: uint,   ;; sBTC collateral amount
    collateral-ratio: uint,    ;; Current collateralization ratio
    is-callable: bool,         ;; Can be called early
    call-premium: uint,        ;; Early call premium
    status: uint               ;; 0=active, 1=matured, 2=called, 3=defaulted
  }
)

(define-map bond-holders
  { bond-id: uint, holder: principal }
  {
    amount-held: uint,         ;; Amount of bond held
    purchase-block: uint,      ;; When bond was purchased
    purchase-price: uint,      ;; Purchase price per unit
    accrued-interest: uint,    ;; Accrued interest
    last-interest-claim: uint  ;; Last interest claim block
  }
)

(define-map yield-distribution-pools
  { pool-id: uint }
  {
    total-sbtc-deposited: uint, ;; Total sBTC in yield pool
    total-bonds-backed: uint,   ;; Total bonds backed by pool
    current-yield-rate: uint,   ;; Current annualized yield rate
    last-yield-calculation: uint, ;; Last yield calculation block
    pool-manager: principal,    ;; Pool manager
    is-active: bool            ;; Pool status
  }
)

(define-map bond-yield-allocations
  { bond-id: uint, pool-id: uint }
  {
    allocated-amount: uint,    ;; Amount allocated from pool
    yield-share: uint,         ;; Share of pool yields
    allocation-block: uint     ;; When allocation was made
  }
)

(define-map enterprise-loan-bonds
  { loan-id: uint }
  {
    bond-ids: (list 10 uint),  ;; Associated bond IDs
    total-bond-value: uint,    ;; Total value of bonds
    loan-to-bond-ratio: uint,  ;; Loan to bond value ratio
    risk-tier: uint            ;; Risk tier (1-5, 5 being highest risk)
  }
)

;; Global state
(define-data-var next-bond-id uint u1)
(define-data-var next-pool-id uint u1)
(define-data-var total-sbtc-bonds uint u0)
(define-data-var total-yield-distributed uint u0)

;; =============================================================================
;; BOND ISSUANCE
;; =============================================================================

(define-public (issue-sbtc-backed-bond 
  (principal-amount uint)
  (coupon-rate uint)
  (maturity-blocks uint)
  (collateral-amount uint)
  (is-callable bool)
  (call-premium uint))
  "Issue new sBTC-backed bond"
  (let ((bond-id (var-get next-bond-id)))
    (begin
      ;; Validate bond terms
      (asserts! (>= principal-amount MIN_BOND_AMOUNT) ERR_INVALID_BOND_TERMS)
      (asserts! (<= principal-amount MAX_BOND_AMOUNT) ERR_INVALID_BOND_TERMS)
      (asserts! (>= maturity-blocks MIN_MATURITY_BLOCKS) ERR_INVALID_BOND_TERMS)
      (asserts! (<= maturity-blocks MAX_MATURITY_BLOCKS) ERR_INVALID_BOND_TERMS)
      (asserts! (<= coupon-rate MAX_YIELD_RATE) ERR_INVALID_BOND_TERMS)
      
      ;; Validate collateral ratio
      (match (contract-call? .sbtc-integration get-sbtc-price)
        sbtc-price (let ((collateral-value (* collateral-amount sbtc-price))
                         (required-collateral (/ (* principal-amount COLLATERAL_RATIO) u1000000)))
          (asserts! (>= collateral-value required-collateral) ERR_INSUFFICIENT_COLLATERAL)
          
          ;; Transfer collateral to contract
          (try! (contract-call? .sbtc-integration.SBTC_MAINNET transfer collateral-amount tx-sender (as-contract tx-sender) none))
          
          ;; Create bond
          (map-set sbtc-bonds 
            { bond-id: bond-id }
            {
              issuer: tx-sender,
              principal-amount: principal-amount,
              coupon-rate: coupon-rate,
              maturity-block: (+ block-height maturity-blocks),
              issue-block: block-height,
              collateral-amount: collateral-amount,
              collateral-ratio: (/ (* collateral-value u1000000) principal-amount),
              is-callable: is-callable,
              call-premium: call-premium,
              status: u0
            }
          )
          
          ;; Update global state
          (var-set next-bond-id (+ bond-id u1))
          (var-set total-sbtc-bonds (+ (var-get total-sbtc-bonds) principal-amount))
          
          (print { 
            event: "sbtc-bond-issued", 
            bond-id: bond-id, 
            issuer: tx-sender,
            principal: principal-amount,
            collateral: collateral-amount
          })
          (ok bond-id)
        )
        ERR_INSUFFICIENT_COLLATERAL
      )
    )
  )
)

(define-public (purchase-bond (bond-id uint) (amount uint))
  "Purchase bond units"
  (match (map-get? sbtc-bonds { bond-id: bond-id })
    bond (begin
      (asserts! (is-eq (get status bond) u0) ERR_BOND_ALREADY_MATURED)
      (asserts! (> amount u0) ERR_INVALID_BOND_TERMS)
      (asserts! (<= amount (get principal-amount bond)) ERR_INVALID_BOND_TERMS)
      
      ;; Calculate purchase price (simplified - could include market pricing)
      (let ((purchase-price amount))
        
        ;; Transfer payment to bond issuer
        (try! (contract-call? .sbtc-integration.SBTC_MAINNET transfer purchase-price tx-sender (get issuer bond) none))
        
        ;; Record bond holding
        (let ((existing-holding (default-to 
                                 { amount-held: u0, purchase-block: u0, purchase-price: u0, accrued-interest: u0, last-interest-claim: u0 }
                                 (map-get? bond-holders { bond-id: bond-id, holder: tx-sender }))))
          (map-set bond-holders 
            { bond-id: bond-id, holder: tx-sender }
            {
              amount-held: (+ (get amount-held existing-holding) amount),
              purchase-block: block-height,
              purchase-price: (+ (get purchase-price existing-holding) purchase-price),
              accrued-interest: (get accrued-interest existing-holding),
              last-interest-claim: (max (get last-interest-claim existing-holding) block-height)
            }
          )
        )
        
        (print { event: "bond-purchased", bond-id: bond-id, buyer: tx-sender, amount: amount })
        (ok true)
      )
    )
    ERR_BOND_NOT_FOUND
  )
)

;; =============================================================================
;; YIELD DISTRIBUTION POOLS
;; =============================================================================

(define-public (create-yield-pool (initial-sbtc-amount uint))
  "Create new yield distribution pool"
  (let ((pool-id (var-get next-pool-id)))
    (begin
      (asserts! (> initial-sbtc-amount u0) ERR_INVALID_YIELD_DISTRIBUTION)
      
      ;; Transfer sBTC to contract for yield generation
      (try! (contract-call? .sbtc-integration.SBTC_MAINNET transfer initial-sbtc-amount tx-sender (as-contract tx-sender) none))
      
      ;; Create yield pool
      (map-set yield-distribution-pools 
        { pool-id: pool-id }
        {
          total-sbtc-deposited: initial-sbtc-amount,
          total-bonds-backed: u0,
          current-yield-rate: BASE_YIELD_RATE,
          last-yield-calculation: block-height,
          pool-manager: tx-sender,
          is-active: true
        }
      )
      
      (var-set next-pool-id (+ pool-id u1))
      
      (print { event: "yield-pool-created", pool-id: pool-id, manager: tx-sender, initial-amount: initial-sbtc-amount })
      (ok pool-id)
    )
  )
)

(define-public (allocate-yield-to-bond (bond-id uint) (pool-id uint) (allocation-percentage uint))
  "Allocate yield from pool to specific bond"
  (begin
    ;; Validate allocation percentage
    (asserts! (<= allocation-percentage u1000000) ERR_INVALID_YIELD_DISTRIBUTION)
    
    (match (map-get? sbtc-bonds { bond-id: bond-id })
      bond (match (map-get? yield-distribution-pools { pool-id: pool-id })
        pool (begin
          ;; Verify pool manager authorization or bond issuer
          (asserts! (or (is-eq tx-sender (get pool-manager pool)) 
                       (is-eq tx-sender (get issuer bond))) ERR_NOT_AUTHORIZED)
          
          ;; Calculate allocation amount
          (let ((allocated-amount (/ (* (get total-sbtc-deposited pool) allocation-percentage) u1000000)))
            
            ;; Record allocation
            (map-set bond-yield-allocations 
              { bond-id: bond-id, pool-id: pool-id }
              {
                allocated-amount: allocated-amount,
                yield-share: allocation-percentage,
                allocation-block: block-height
              }
            )
            
            ;; Update pool
            (map-set yield-distribution-pools 
              { pool-id: pool-id }
              (merge pool {
                total-bonds-backed: (+ (get total-bonds-backed pool) (get principal-amount bond))
              })
            )
            
            (print { event: "yield-allocated", bond-id: bond-id, pool-id: pool-id, amount: allocated-amount })
            (ok true)
          )
        )
        ERR_BOND_NOT_FOUND
      )
      ERR_BOND_NOT_FOUND
    )
  )
)

(define-public (calculate-and-distribute-yield (pool-id uint))
  "Calculate and distribute yield for pool"
  (match (map-get? yield-distribution-pools { pool-id: pool-id })
    pool (begin
      (asserts! (is-eq tx-sender (get pool-manager pool)) ERR_NOT_AUTHORIZED)
      
      ;; Calculate blocks since last yield calculation
      (let ((blocks-elapsed (- block-height (get last-yield-calculation pool)))
            (annual-blocks u52560)) ;; Approximate blocks in a year
        
        ;; Calculate yield based on sBTC staking/lending returns
        (match (contract-call? .enhanced-yield-strategy get-current-apy)
          current-apy (let ((yield-amount (/ (* (get total-sbtc-deposited pool) current-apy blocks-elapsed) (* annual-blocks u1000000))))
            
            ;; Distribute yield proportionally to bond allocations
            (try! (distribute-pool-yield pool-id yield-amount))
            
            ;; Update pool state
            (map-set yield-distribution-pools 
              { pool-id: pool-id }
              (merge pool {
                current-yield-rate: current-apy,
                last-yield-calculation: block-height
              })
            )
            
            (var-set total-yield-distributed (+ (var-get total-yield-distributed) yield-amount))
            
            (print { event: "yield-distributed", pool-id: pool-id, amount: yield-amount })
            (ok yield-amount)
          )
          (err ERR_INSUFFICIENT_YIELD)
        )
      )
    )
    ERR_BOND_NOT_FOUND
  )
)

(define-private (distribute-pool-yield (pool-id uint) (total-yield uint))
  "Distribute yield to bond holders proportionally"
  ;; In a full implementation, this would iterate through all bonds with allocations
  ;; For now, well mark the yield as available for claiming
  (begin
    (print { event: "yield-available-for-claim", pool-id: pool-id, amount: total-yield })
    (ok true)
  )
)

;; =============================================================================
;; BOND SERVICING AND REDEMPTION
;; =============================================================================

(define-public (claim-bond-interest (bond-id uint))
  "Claim accrued interest on bond holdings"
  (match (map-get? bond-holders { bond-id: bond-id, holder: tx-sender })
    holding (match (map-get? sbtc-bonds { bond-id: bond-id })
      bond (let ((blocks-since-claim (- block-height (get last-interest-claim holding)))
                 (annual-blocks u52560)
                 (interest-amount (/ (* (get amount-held holding) (get coupon-rate bond) blocks-since-claim) (* annual-blocks u1000000))))
        
        ;; Transfer interest to bond holder
        (try! (as-contract (contract-call? .sbtc-integration.SBTC_MAINNET transfer interest-amount tx-sender tx-sender none)))
        
        ;; Update holding record
        (map-set bond-holders 
          { bond-id: bond-id, holder: tx-sender }
          (merge holding {
            accrued-interest: (+ (get accrued-interest holding) interest-amount),
            last-interest-claim: block-height
          })
        )
        
        (print { event: "interest-claimed", bond-id: bond-id, holder: tx-sender, amount: interest-amount })
        (ok interest-amount)
      )
      ERR_BOND_NOT_FOUND
    )
    ERR_BOND_NOT_FOUND
  )
)

(define-public (redeem-matured-bond (bond-id uint))
  "Redeem bond at maturity"
  (match (map-get? sbtc-bonds { bond-id: bond-id })
    bond (match (map-get? bond-holders { bond-id: bond-id, holder: tx-sender })
      holding (begin
        (asserts! (>= block-height (get maturity-block bond)) ERR_EARLY_REDEMPTION_NOT_ALLOWED)
        (asserts! (is-eq (get status bond) u0) ERR_BOND_ALREADY_MATURED)
        
        ;; Calculate redemption amount (principal + final interest)
        (let ((redemption-amount (get amount-held holding)))
          
          ;; Transfer redemption amount to holder
          (try! (as-contract (contract-call? .sbtc-integration.SBTC_MAINNET transfer redemption-amount tx-sender tx-sender none)))
          
          ;; Mark bond portion as redeemed
          (map-delete bond-holders { bond-id: bond-id, holder: tx-sender })
          
          ;; Check if all bond units have been redeemed and update status
          ;; (Simplified - in full implementation would check all holders)
          (map-set sbtc-bonds 
            { bond-id: bond-id }
            (merge bond { status: u1 })
          )
          
          (print { event: "bond-redeemed", bond-id: bond-id, holder: tx-sender, amount: redemption-amount })
          (ok redemption-amount)
        )
      )
      ERR_BOND_NOT_FOUND
    )
    ERR_BOND_NOT_FOUND
  )
)

(define-public (early-call-bond (bond-id uint))
  "Call bond early (issuer only)"
  (match (map-get? sbtc-bonds { bond-id: bond-id })
    bond (begin
      (asserts! (is-eq tx-sender (get issuer bond)) ERR_NOT_AUTHORIZED)
      (asserts! (get is-callable bond) ERR_EARLY_REDEMPTION_NOT_ALLOWED)
      (asserts! (is-eq (get status bond) u0) ERR_BOND_ALREADY_MATURED)
      
      ;; Calculate call price (principal + call premium)
      (let ((call-price (+ (get principal-amount bond) (get call-premium bond))))
        
        ;; Mark bond as called
        (map-set sbtc-bonds 
          { bond-id: bond-id }
          (merge bond { status: u2 })
        )
        
        ;; In full implementation, would process all bond holders
        (print { event: "bond-called", bond-id: bond-id, call-price: call-price })
        (ok call-price)
      )
    )
    ERR_BOND_NOT_FOUND
  )
)

;; =============================================================================
;; RISK MANAGEMENT
;; =============================================================================

(define-public (check-bond-collateralization (bond-id uint))
  "Check and update bond collateralization ratio"
  (match (map-get? sbtc-bonds { bond-id: bond-id })
    bond (match (contract-call? .sbtc-integration get-sbtc-price)
      sbtc-price (let ((current-collateral-value (* (get collateral-amount bond) sbtc-price))
                       (current-ratio (/ (* current-collateral-value u1000000) (get principal-amount bond))))
        
        ;; Update collateral ratio
        (map-set sbtc-bonds 
          { bond-id: bond-id }
          (merge bond { collateral-ratio: current-ratio })
        )
        
        ;; Check if liquidation threshold is breached
        (if (< current-ratio LIQUIDATION_THRESHOLD)
          (begin
            (print { event: "bond-undercollateralized", bond-id: bond-id, ratio: current-ratio })
            (err ERR_LIQUIDATION_THRESHOLD_BREACHED)
          )
          (ok current-ratio)
        )
      )
      (err ERR_INSUFFICIENT_COLLATERAL)
    )
    ERR_BOND_NOT_FOUND
  )
)

(define-public (liquidate-undercollateralized-bond (bond-id uint))
  "Liquidate bond with insufficient collateral"
  (match (check-bond-collateralization bond-id)
    ratio (err ERR_LIQUIDATION_THRESHOLD_BREACHED) ;; Not undercollateralized
    (match (map-get? sbtc-bonds { bond-id: bond-id })
      bond (begin
        ;; Transfer collateral to liquidator at discount
        (let ((liquidation-amount (/ (* (get collateral-amount bond) u950000) u1000000))) ;; 5% discount
          (try! (as-contract (contract-call? .sbtc-integration.SBTC_MAINNET transfer liquidation-amount tx-sender tx-sender none)))
          
          ;; Mark bond as defaulted
          (map-set sbtc-bonds 
            { bond-id: bond-id }
            (merge bond { status: u3 })
          )
          
          (print { event: "bond-liquidated", bond-id: bond-id, liquidator: tx-sender })
          (ok liquidation-amount)
        )
      )
      ERR_BOND_NOT_FOUND
    )
  )
)

;; =============================================================================
;; ENTERPRISE LOAN INTEGRATION
;; =============================================================================

(define-public (create-enterprise-loan-bond (loan-id uint) (bond-structure (list 10 { amount: uint, coupon: uint, maturity: uint })))
  "Create multiple bonds to back enterprise loan"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED) ;; Or loan manager
    
    ;; Create bonds for loan structure
    (let ((bond-ids (create-loan-bonds bond-structure)))
      
      ;; Calculate total bond value
      (let ((total-value (fold sum-bond-amounts bond-structure u0)))
        (map-set enterprise-loan-bonds 
          { loan-id: loan-id }
          {
            bond-ids: bond-ids,
            total-bond-value: total-value,
            loan-to-bond-ratio: u800000, ;; 80% loan-to-value
            risk-tier: u3 ;; Medium risk
          }
        )
        
        (print { event: "enterprise-loan-bonds-created", loan-id: loan-id, total-value: total-value })
        (ok bond-ids)
      )
    )
  )
)

(define-private (create-loan-bonds (bond-structure (list 10 { amount: uint, coupon: uint, maturity: uint })))
  "Create bonds for loan structure"
  ;; Simplified implementation - would iterate and create each bond
  (list (var-get next-bond-id))
)

(define-private (sum-bond-amounts (bond-spec { amount: uint, coupon: uint, maturity: uint }) (acc uint))
  "Sum bond amounts"
  (+ acc (get amount bond-spec))
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-bond-details (bond-id uint))
  "Get comprehensive bond details"
  (match (map-get? sbtc-bonds { bond-id: bond-id })
    bond (ok bond)
    (err ERR_BOND_NOT_FOUND)
  )
)

(define-read-only (get-bond-holding (bond-id uint) (holder principal))
  "Get bond holding details"
  (map-get? bond-holders { bond-id: bond-id, holder: holder })
)

(define-read-only (get-yield-pool-info (pool-id uint))
  "Get yield pool information"
  (map-get? yield-distribution-pools { pool-id: pool-id })
)

(define-read-only (get-bond-yield-allocation (bond-id uint) (pool-id uint))
  "Get bond yield allocation details"
  (map-get? bond-yield-allocations { bond-id: bond-id, pool-id: pool-id })
)

(define-read-only (calculate-bond-value (bond-id uint))
  "Calculate current bond market value"
  (match (map-get? sbtc-bonds { bond-id: bond-id })
    bond (let ((remaining-blocks (if (> (get maturity-block bond) block-height)
                                   (- (get maturity-block bond) block-height)
                                   u0)))
      ;; Simplified present value calculation
      (ok (/ (* (get principal-amount bond) u950000) u1000000)) ;; 5% discount
    )
    (err ERR_BOND_NOT_FOUND)
  )
)

(define-read-only (get-global-bond-stats)
  "Get global bond statistics"
  {
    total-bonds-issued: (- (var-get next-bond-id) u1),
    total-bond-value: (var-get total-sbtc-bonds),
    total-yield-distributed: (var-get total-yield-distributed),
    active-yield-pools: (- (var-get next-pool-id) u1)
  }
)





