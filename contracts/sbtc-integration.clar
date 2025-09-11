;; sbtc-integration.clar
;; sBTC Integration Module for Conxian Protocol
;; Provides sBTC asset management, risk parameters, and oracle integration

(impl-trait .sip-010-trait.sip-010-trait)

;; =============================================================================
;; CONSTANTS AND ERROR CODES
;; =============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1000))
(define-constant ERR_INVALID_PARAMS (err u1001))
(define-constant ERR_ASSET_NOT_FOUND (err u1002))
(define-constant ERR_ASSET_INACTIVE (err u1003))
(define-constant ERR_ORACLE_STALE (err u1004))
(define-constant ERR_PRICE_DEVIATION (err u1005))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1006))
(define-constant ERR_BORROW_CAP_EXCEEDED (err u1007))
(define-constant ERR_CIRCUIT_BREAKER_ACTIVE (err u1008))

;; sBTC mainnet and testnet contract addresses
(define-constant SBTC_MAINNET 'SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.sbtc-token)
(define-constant SBTC_TESTNET 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sbtc-token)

;; Risk management constants
(define-constant DEFAULT_LTV u700000)           ;; 70% in basis points (1e6 scale)
(define-constant DEFAULT_LIQ_THRESHOLD u750000) ;; 75% liquidation threshold
(define-constant DEFAULT_LIQ_PENALTY u100000)   ;; 10% liquidation penalty
(define-constant DEFAULT_RESERVE_FACTOR u200000) ;; 20% reserve factor
(define-constant FLASH_LOAN_FEE u120)           ;; 12 basis points (0.12%)

;; Oracle parameters
(define-constant MAX_PRICE_DEVIATION u200000)   ;; 20% max price deviation
(define-constant ORACLE_STALE_THRESHOLD u17280) ;; ~24 hours in Nakamoto blocks (was u144)
(define-constant MIN_CONFIRMATION_BLOCKS u6)    ;; Min confirmations for peg-in

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================

(define-map asset-config
  { token: principal }
  {
    ltv: uint,                    ;; Loan-to-value ratio (basis points)
    liquidation-threshold: uint,  ;; Liquidation threshold (basis points)
    liquidation-penalty: uint,    ;; Liquidation penalty (basis points)
    reserve-factor: uint,         ;; Reserve factor for interest (basis points)
    borrow-cap: (optional uint),  ;; Maximum borrow amount
    supply-cap: (optional uint),  ;; Maximum supply amount
    active: bool,                 ;; Asset is active for operations
    supply-enabled: bool,         ;; Supply operations enabled
    borrow-enabled: bool,         ;; Borrow operations enabled
    flash-loan-enabled: bool,     ;; Flash loans enabled
    bond-enabled: bool           ;; Bond issuance enabled for large loans
  }
)

(define-map oracle-config
  { asset: principal }
  {
    primary-oracle: principal,    ;; Primary price oracle
    secondary-oracle: (optional principal), ;; Backup oracle
    last-price: uint,            ;; Last known price (8 decimals)
    last-update-block: uint,     ;; Last price update block
    price-deviation-threshold: uint, ;; Max allowed price deviation
    circuit-breaker-active: bool ;; Emergency circuit breaker status
  }
)

(define-map interest-rate-config
  { asset: principal }
  {
    base-rate: uint,             ;; Base interest rate (per block)
    slope1: uint,                ;; Interest rate slope (0-kink1)
    slope2: uint,                ;; Interest rate slope (kink1-kink2)
    jump-multiplier: uint,       ;; Jump rate multiplier above kink2
    kink1: uint,                 ;; First kink utilization point
    kink2: uint                  ;; Second kink utilization point
  }
)

(define-map asset-metrics
  { asset: principal }
  {
    total-supply: uint,          ;; Total supplied amount
    total-borrows: uint,         ;; Total borrowed amount
    supply-rate: uint,           ;; Current supply APY
    borrow-rate: uint,           ;; Current borrow APY
    utilization-rate: uint,      ;; Current utilization rate
    last-accrual-block: uint,    ;; Last interest accrual block
    reserve-balance: uint        ;; Protocol reserves
  }
)

;; Risk assessment data
(define-map risk-status
  { asset: principal }
  {
    risk-level: uint,            ;; Risk level (1-5, 5 = highest risk)
    volatility-index: uint,      ;; 30-day volatility index
    liquidity-score: uint,       ;; Liquidity depth score
    peg-stability: uint,         ;; Peg stability metric for sBTC
    last-risk-update: uint       ;; Last risk assessment block
  }
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-asset-config (token principal))
  (map-get? asset-config { token: token })
)

(define-read-only (get-oracle-config (asset principal))
  (map-get? oracle-config { asset: asset })
)

(define-read-only (get-asset-metrics (asset principal))
  (map-get? asset-metrics { asset: asset })
)

(define-read-only (get-risk-status (asset principal))
  (map-get? risk-status { asset: asset })
)

(define-read-only (get-sbtc-price)
  "Get current sBTC price in USD (8 decimals)"
  (let ((oracle-cfg (unwrap-panic (get-oracle-config SBTC_MAINNET))))
    (if (< (- block-height (get last-update-block oracle-cfg)) ORACLE_STALE_THRESHOLD)
      (ok (get last-price oracle-cfg))
      ERR_ORACLE_STALE
    )
  )
)

(define-read-only (calculate-collateral-value (token principal) (amount uint))
  "Calculate USD value of collateral with LTV applied"
  (match (get-asset-config token)
    config (match (get-sbtc-price)
      price (ok (* (* amount price) (get ltv config)))
      error error
    )
    ERR_ASSET_NOT_FOUND
  )
)

(define-read-only (calculate-liquidation-threshold (token principal) (amount uint))
  "Calculate liquidation threshold value"
  (match (get-asset-config token)
    config (match (get-sbtc-price)
      price (ok (* (* amount price) (get liquidation-threshold config)))
      error error
    )
    ERR_ASSET_NOT_FOUND
  )
)

(define-read-only (get-utilization-rate (asset principal))
  "Calculate current utilization rate for asset"
  (match (get-asset-metrics asset)
    metrics (let ((total-supply (get total-supply metrics))
                  (total-borrows (get total-borrows metrics)))
      (if (is-eq total-supply u0)
        (ok u0)
        (ok (/ (* total-borrows u1000000) total-supply))
      )
    )
    ERR_ASSET_NOT_FOUND
  )
)

(define-read-only (calculate-interest-rates (asset principal))
  "Calculate current supply and borrow interest rates"
  (match (get-interest-rate-config asset)
    rate-config (match (get-utilization-rate asset)
      utilization (let ((base-rate (get base-rate rate-config))
                        (slope1 (get slope1 rate-config))
                        (slope2 (get slope2 rate-config))
                        (jump-multiplier (get jump-multiplier rate-config))
                        (kink1 (get kink1 rate-config))
                        (kink2 (get kink2 rate-config)))
        (let ((borrow-rate (cond
          (<= utilization kink1)
            (+ base-rate (* utilization slope1))
          (<= utilization kink2)
            (+ base-rate (+ (* kink1 slope1) (* (- utilization kink1) slope2)))
          (+ base-rate (+ (* kink1 slope1) (+ (* (- kink2 kink1) slope2) 
             (* (- utilization kink2) jump-multiplier)))))))
          (supply-rate (match (get-asset-config asset)
            config (* borrow-rate (- u1000000 (get reserve-factor config)))
            u0
          )))
        (ok { borrow-rate: borrow-rate, supply-rate: supply-rate })
      )
      error error
    )
    ERR_ASSET_NOT_FOUND
  )
)

(define-read-only (is-asset-active (token principal))
  "Check if asset is active for operations"
  (match (get-asset-config token)
    config (get active config)
    false
  )
)

(define-read-only (can-supply (token principal))
  "Check if supply operations are enabled"
  (match (get-asset-config token)
    config (and (get active config) (get supply-enabled config))
    false
  )
)

(define-read-only (can-borrow (token principal))
  "Check if borrow operations are enabled"
  (match (get-asset-config token)
    config (and (get active config) (get borrow-enabled config))
    false
  )
)

(define-read-only (can-flash-loan (token principal))
  "Check if flash loans are enabled"
  (match (get-asset-config token)
    config (and (get active config) (get flash-loan-enabled config))
    false
  )
)

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-public (register-sbtc-asset (token principal))
  "Register sBTC asset with default parameters"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    ;; Set asset configuration
    (map-set asset-config { token: token }
      {
        ltv: DEFAULT_LTV,
        liquidation-threshold: DEFAULT_LIQ_THRESHOLD,
        liquidation-penalty: DEFAULT_LIQ_PENALTY,
        reserve-factor: DEFAULT_RESERVE_FACTOR,
        borrow-cap: none,
        supply-cap: none,
        active: false,
        supply-enabled: false,
        borrow-enabled: false,
        flash-loan-enabled: false,
        bond-enabled: false
      }
    )
    
    ;; Initialize metrics
    (map-set asset-metrics { asset: token }
      {
        total-supply: u0,
        total-borrows: u0,
        supply-rate: u0,
        borrow-rate: u0,
        utilization-rate: u0,
        last-accrual-block: block-height,
        reserve-balance: u0
      }
    )
    
    ;; Set default interest rate model
    (map-set interest-rate-config { asset: token }
      {
        base-rate: u200,         ;; 2% base rate (per year, scaled)
        slope1: u400,            ;; 4% slope to kink1
        slope2: u6000,           ;; 60% slope from kink1 to kink2
        jump-multiplier: u20000, ;; 200% jump multiplier above kink2
        kink1: u800000,          ;; 80% utilization kink1
        kink2: u900000           ;; 90% utilization kink2
      }
    )
    
    (print { event: "sbtc-asset-registered", token: token })
    (ok true)
  )
)

(define-public (set-asset-parameters (token principal) 
                                   (ltv uint) 
                                   (liq-threshold uint) 
                                   (liq-penalty uint)
                                   (reserve-factor uint))
  "Set risk parameters for sBTC asset"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= ltv liq-threshold) ERR_INVALID_PARAMS)
    (asserts! (<= liq-threshold u1000000) ERR_INVALID_PARAMS)
    (asserts! (<= reserve-factor u1000000) ERR_INVALID_PARAMS)
    
    (match (get-asset-config token)
      config (begin
        (map-set asset-config { token: token }
          (merge config {
            ltv: ltv,
            liquidation-threshold: liq-threshold,
            liquidation-penalty: liq-penalty,
            reserve-factor: reserve-factor
          })
        )
        (print { event: "sbtc-params-updated", token: token, ltv: ltv, liq-threshold: liq-threshold })
        (ok true)
      )
      ERR_ASSET_NOT_FOUND
    )
  )
)

(define-public (set-borrow-supply-caps (token principal) (borrow-cap (optional uint)) (supply-cap (optional uint)))
  "Set borrow and supply caps for asset"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (match (get-asset-config token)
      config (begin
        (map-set asset-config { token: token }
          (merge config {
            borrow-cap: borrow-cap,
            supply-cap: supply-cap
          })
        )
        (print { event: "sbtc-caps-updated", token: token, borrow-cap: borrow-cap, supply-cap: supply-cap })
        (ok true)
      )
      ERR_ASSET_NOT_FOUND
    )
  )
)

(define-public (activate-asset-operations (token principal) 
                                        (supply bool) 
                                        (borrow bool) 
                                        (flash-loan bool)
                                        (bond bool))
  "Enable/disable specific operations for sBTC"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (match (get-asset-config token)
      config (begin
        (map-set asset-config { token: token }
          (merge config {
            active: true,
            supply-enabled: supply,
            borrow-enabled: borrow,
            flash-loan-enabled: flash-loan,
            bond-enabled: bond
          })
        )
        (print { event: "sbtc-operations-updated", token: token, supply: supply, borrow: borrow, flash-loan: flash-loan })
        (ok true)
      )
      ERR_ASSET_NOT_FOUND
    )
  )
)

(define-public (set-oracle-config (asset principal) 
                                (primary-oracle principal) 
                                (secondary-oracle (optional principal))
                                (deviation-threshold uint))
  "Configure price oracle for sBTC"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= deviation-threshold u1000000) ERR_INVALID_PARAMS)
    
    (map-set oracle-config { asset: asset }
      {
        primary-oracle: primary-oracle,
        secondary-oracle: secondary-oracle,
        last-price: u0,
        last-update-block: block-height,
        price-deviation-threshold: deviation-threshold,
        circuit-breaker-active: false
      }
    )
    
    (print { event: "oracle-config-set", asset: asset, primary-oracle: primary-oracle })
    (ok true)
  )
)

(define-public (update-price (asset principal) (new-price uint))
  "Update asset price (oracle only)"
  (match (get-oracle-config asset)
    oracle-cfg (begin
      ;; Only authorized oracles can update price
      (asserts! (or (is-eq tx-sender (get primary-oracle oracle-cfg))
                   (is-some (and (get secondary-oracle oracle-cfg) 
                                (is-eq tx-sender (unwrap-panic (get secondary-oracle oracle-cfg))))))
                ERR_NOT_AUTHORIZED)
      
      ;; Check price deviation
      (let ((last-price (get last-price oracle-cfg))
            (deviation-threshold (get price-deviation-threshold oracle-cfg)))
        (if (and (> last-price u0) (> new-price u0))
          (let ((price-change (if (> new-price last-price)
                               (/ (* (- new-price last-price) u1000000) last-price)
                               (/ (* (- last-price new-price) u1000000) last-price))))
            (if (> price-change deviation-threshold)
              (begin
                ;; Activate circuit breaker for large price movements
                (map-set oracle-config { asset: asset }
                  (merge oracle-cfg { circuit-breaker-active: true }))
                ERR_PRICE_DEVIATION
              )
              (begin
                ;; Normal price update
                (map-set oracle-config { asset: asset }
                  (merge oracle-cfg { 
                    last-price: new-price,
                    last-update-block: block-height,
                    circuit-breaker-active: false
                  }))
                (ok true)
              )
            )
          )
          (begin
            ;; First price or zero price handling
            (map-set oracle-config { asset: asset }
              (merge oracle-cfg { 
                last-price: new-price,
                last-update-block: block-height
              }))
            (ok true)
          )
        )
      )
    )
    ERR_ASSET_NOT_FOUND
  )
)

(define-public (toggle-circuit-breaker (asset principal) (active bool))
  "Manually toggle circuit breaker"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (match (get-oracle-config asset)
      oracle-cfg (begin
        (map-set oracle-config { asset: asset }
          (merge oracle-cfg { circuit-breaker-active: active }))
        (print { event: "circuit-breaker-toggled", asset: asset, active: active })
        (ok true)
      )
      ERR_ASSET_NOT_FOUND
    )
  )
)

;; =============================================================================
;; BITCOIN BRIDGE FUNCTIONS
;; =============================================================================

(define-public (peg-in (bitcoin-tx-id (buff 32)) (amount uint) (recipient principal))
  "Handle Bitcoin peg-in: mint sBTC tokens after verifying Bitcoin lock"
  (begin
    ;; Verify Bitcoin transaction has sufficient confirmations
    (asserts! (> (block-height) (+ (get min-confirmation-blocks) (get bitcoin-block-height bitcoin-tx-id)))
              ERR_INSUFFICIENT_CONFIRMATIONS)
              
    ;; Mint sBTC tokens to recipient
    (try! (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sbtc-token mint amount recipient))
    
    (print { event: "peg-in-success", tx-id: bitcoin-tx-id, amount: amount, recipient: recipient })
    (ok true)
  )
)

(define-public (peg-out (amount uint) (bitcoin-address (string-utf8 42)))
  "Handle sBTC peg-out: burn sBTC tokens and initiate Bitcoin transfer"
  (begin
    ;; Verify user has sufficient balance
    (try! (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sbtc-token transfer 
                          amount tx-sender (as-contract)))
    
    ;; Burn sBTC tokens
    (try! (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sbtc-token burn amount))
    
    ;; Initiate Bitcoin transfer (actual Bitcoin transfer handled off-chain)
    (print { event: "peg-out-initiated", amount: amount, bitcoin-address: bitcoin-address })
    (ok true)
  )
)

;; =============================================================================
;; UTILITY FUNCTIONS
;; =============================================================================

(define-public (accrue-interest (asset principal))
  "Accrue interest for asset"
  (match (get-asset-metrics asset)
    metrics (match (calculate-interest-rates asset)
      rates (let ((blocks-elapsed (- block-height (get last-accrual-block metrics)))
                  (borrow-rate (get borrow-rate rates))
                  (total-borrows (get total-borrows metrics)))
        (if (> blocks-elapsed u0)
          (let ((interest-accrued (* (* total-borrows borrow-rate) blocks-elapsed))
                (new-total-borrows (+ total-borrows interest-accrued)))
            (begin
              (map-set asset-metrics { asset: asset }
                (merge metrics {
                  total-borrows: new-total-borrows,
                  last-accrual-block: block-height
                }))
              (ok interest-accrued)
            )
          )
          (ok u0)
        )
      )
      error error
    )
    ERR_ASSET_NOT_FOUND
  )
)

;; =============================================================================
;; INTEGRATION FUNCTIONS
;; =============================================================================

(define-public (validate-operation (token principal) (operation (string-ascii 20)))
  "Validate if operation is allowed for asset"
  (match (get-asset-config token)
    config (match (get-oracle-config token)
      oracle-cfg (begin
        ;; Check circuit breaker
        (asserts! (not (get circuit-breaker-active oracle-cfg)) ERR_CIRCUIT_BREAKER_ACTIVE)
        
        ;; Check operation-specific permissions
        (if (is-eq operation "supply")
          (asserts! (get supply-enabled config) ERR_ASSET_INACTIVE)
          (if (is-eq operation "borrow")
            (asserts! (get borrow-enabled config) ERR_ASSET_INACTIVE)
            (if (is-eq operation "flash-loan")
              (asserts! (get flash-loan-enabled config) ERR_ASSET_INACTIVE)
              true
            )
          )
        )
        (ok true)
      )
      ERR_ASSET_NOT_FOUND
    )
    ERR_ASSET_NOT_FOUND
  )
)

;; Initialize sBTC on contract deployment
(begin
  (try! (register-sbtc-asset SBTC_MAINNET))
  (print { event: "sbtc-integration-deployed", version: "1.0.0" })
)
