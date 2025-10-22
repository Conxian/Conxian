;; sbtc-flash-loan-vault.clar
;; Enhanced Flash Loan Vault with sBTC Support
;; Implements secure flash loans with sBTC collateral and risk management

;; ===== Traits =====
(use-trait ft-trait .all-traits.sip-010-trait)
(use-trait flash-loan-receiver-trait .all-traits.flash-loan-receiver-trait)

;; =============================================================================
;; CONSTANTS
;; =============================================================================
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_ASSET (err u201))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u202))
(define-constant ERR_FLASH_LOAN_NOT_REPAID (err u203))
(define-constant ERR_INVALID_FEE (err u204))
(define-constant ERR_REENTRANCY (err u205))
(define-constant ERR_ASSET_PAUSED (err u206))
(define-constant ERR_AMOUNT_TOO_LARGE (err u207))
(define-constant ERR_CALLBACK_FAILED (err u208))
(define-constant ERR_INVALID_AMOUNT (err u209))
(define-constant ERR_CIRCUIT_BREAKER_ACTIVE (err u210))

;; Flash loan limits
(define-constant MAX_FLASH_LOAN_RATIO u9000) ;; 90% of available liquidity
(define-constant MIN_FLASH_LOAN_AMOUNT u1000000) ;; 1 token minimum (6 decimals)
(define-constant DEFAULT_FLASH_FEE u10) ;; 10 basis points (0.1%)
(define-constant MAX_FEE_RATE u1000) ;; 10% maximum fee
(define-constant MAX_UTILIZATION u10000) ;; 100% in basis points

;; Circuit breaker thresholds
(define-constant CIRCUIT_BREAKER_THRESHOLD u5000000000) ;; 5000 tokens
(define-constant MAX_HOURLY_VOLUME u10000000000) ;; 10000 tokens per hour
(define-constant BLOCKS_PER_HOUR u144) ;; ~24 hours at 1 block/10min
(define-constant REPAYMENT_DEADLINE_BLOCKS u10) ;; 10 blocks to repay

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================
(define-map flash-loan-config
  { asset: principal }
  {
    enabled: bool,
    fee-rate: uint, ;; basis points
    max-loan-amount: uint,
    min-loan-amount: uint,
    max-utilization: uint, ;; max % of pool that can be borrowed
    circuit-breaker-active: bool,
    total-flash-loaned: uint,
    last-reset-block: uint
  })

(define-map liquidity-pools
  { asset: principal }
  {
    total-liquidity: uint,
    available-liquidity: uint,
    reserved-liquidity: uint,
    flash-loan-volume: uint,
    hourly-volume: uint,
    last-volume-reset: uint,
    utilization-rate: uint
  })

(define-map active-flash-loans
  { borrower: principal, asset: principal, nonce: uint }
  {
    amount: uint,
    fee: uint,
    start-block: uint,
    repayment-deadline: uint,
    callback-contract: (optional principal),
    status: (string-ascii 20)
  })

(define-map flash-loan-stats
  { asset: principal }
  {
    total-loans: uint,
    total-volume: uint,
    total-fees-collected: uint,
    largest-loan: uint,
    failed-loans: uint,
    last-loan-block: uint
  })

;; Reentrancy guard
(define-data-var flash-loan-active bool false)
(define-data-var current-borrower (optional principal) none)
(define-data-var flash-loan-nonce uint u0)

;; Emergency controls
(define-data-var vault-paused bool false)
(define-data-var emergency-admin (optional principal) none)

;; Circuit breaker integration
(define-data-var circuit-breaker principal .circuit-breaker)

;; =============================================================================
;; CORE FLASH LOAN FUNCTIONS
;; =============================================================================
(define-public (flash-loan (asset <ft-trait>)
                          (amount uint)
                          (receiver <flash-loan-receiver-trait>)
                          (params (buff 1024)))
  (let (
      (asset-contract (contract-of asset))
      (receiver-contract (contract-of receiver))
      (nonce (var-get flash-loan-nonce))
      (config (unwrap! (map-get? flash-loan-config { asset: asset-contract }) ERR_INVALID_ASSET))
      (pool (unwrap! (map-get? liquidity-pools { asset: asset-contract }) ERR_INVALID_ASSET))
      (fee (calculate-flash-loan-fee asset-contract amount))
      (total-repayment (+ amount fee)))
    
    ;; Pre-flight checks
    (asserts! (not (var-get flash-loan-active)) ERR_REENTRANCY)
    (asserts! (not (var-get vault-paused)) ERR_ASSET_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Validate flash loan parameters
    (try! (validate-flash-loan asset-contract amount config pool))
    
    ;; Check circuit breaker
    (try! (contract-call? .circuit-breaker check-operation "flash-loan" amount))
    
    ;; Start flash loan
    (var-set flash-loan-active true)
    (var-set current-borrower (some tx-sender))
    (var-set flash-loan-nonce (+ nonce u1))
    
    ;; Record active loan
    (map-set active-flash-loans
      { borrower: tx-sender, asset: asset-contract, nonce: nonce }
      {
        amount: amount,
        fee: fee,
        start-block: block-height,
        repayment-deadline: (+ block-height REPAYMENT_DEADLINE_BLOCKS),
        callback-contract: (some receiver-contract),
        status: "active"
      })
    
    ;; Update pool state
    (map-set liquidity-pools
      { asset: asset-contract }
      (merge pool {
        available-liquidity: (- (get available-liquidity pool) amount),
        flash-loan-volume: (+ (get flash-loan-volume pool) amount),
        hourly-volume: (+ (get hourly-volume pool) amount)
      }))
    
    ;; Transfer tokens to borrower
    (try! (as-contract (contract-call? asset transfer amount tx-sender tx-sender none)))
    
    ;; Execute callback
    (match (contract-call? receiver on-flash-loan tx-sender asset amount fee params)
      success (try! (complete-flash-loan asset amount fee nonce))
      error (try! (fail-flash-loan asset-contract amount fee nonce)))
    
    ;; Record operation with circuit breaker
    (try! (contract-call? .circuit-breaker record-operation "flash-loan" amount true))
    
    (print {
      event: "flash-loan-completed",
      borrower: tx-sender,
      asset: asset-contract,
      amount: amount,
      fee: fee,
      nonce: nonce
    })
    
    (ok nonce)))

(define-private (complete-flash-loan (asset <ft-trait>)
                                    (amount uint)
                                    (fee uint)
                                    (nonce uint))
  (let (
    (asset-contract (contract-of asset))
    (total-repayment (+ amount fee))
    (borrower (unwrap! (var-get current-borrower) ERR_UNAUTHORIZED)))
    
    ;; Verify repayment
    (try! (contract-call? asset transfer-from borrower (as-contract tx-sender) total-repayment none))
    
    ;; Update loan status
    (match (map-get? active-flash-loans { borrower: borrower, asset: asset-contract, nonce: nonce })
      loan-data (map-set active-flash-loans
                  { borrower: borrower, asset: asset-contract, nonce: nonce }
                  (merge loan-data { status: "completed" }))
      false)
    
    ;; Update pool state
    (match (map-get? liquidity-pools { asset: asset-contract })
      pool (map-set liquidity-pools
             { asset: asset-contract }
             (merge pool {
               available-liquidity: (+ (get available-liquidity pool) amount),
               reserved-liquidity: (+ (get reserved-liquidity pool) fee)
             }))
      false)
    
    ;; Update statistics
    (update-flash-loan-stats asset-contract amount fee true)
    
    ;; Clear reentrancy guard
    (var-set flash-loan-active false)
    (var-set current-borrower none)
    
    (ok true)))

(define-private (fail-flash-loan (asset-contract principal)
                                 (amount uint)
                                 (fee uint)
                                 (nonce uint))
  (let ((borrower (unwrap! (var-get current-borrower) ERR_UNAUTHORIZED)))
    ;; Update loan status
    (match (map-get? active-flash-loans { borrower: borrower, asset: asset-contract, nonce: nonce })
      loan-data (map-set active-flash-loans
                  { borrower: borrower, asset: asset-contract, nonce: nonce }
                  (merge loan-data { status: "failed" }))
      false)
    
    ;; Restore pool liquidity
    (match (map-get? liquidity-pools { asset: asset-contract })
      pool (map-set liquidity-pools
             { asset: asset-contract }
             (merge pool {
               available-liquidity: (+ (get available-liquidity pool) amount)
             }))
      false)
    
    ;; Update failure statistics
    (update-flash-loan-stats asset-contract amount fee false)
    
    ;; Record failure with circuit breaker
    (contract-call? .circuit-breaker record-operation "flash-loan" amount false)
    
    ;; Clear reentrancy guard
    (var-set flash-loan-active false)
    (var-set current-borrower none)
    
    ERR_FLASH_LOAN_NOT_REPAID))

;; =============================================================================
;; LIQUIDITY MANAGEMENT
;; =============================================================================
(define-public (add-liquidity (asset <ft-trait>) (amount uint))
  (let ((asset-contract (contract-of asset)))
    (asserts! (not (var-get vault-paused)) ERR_ASSET_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer tokens to vault
    (try! (contract-call? asset transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update pool state
    (match (map-get? liquidity-pools { asset: asset-contract })
      pool (map-set liquidity-pools
             { asset: asset-contract }
             (merge pool {
               total-liquidity: (+ (get total-liquidity pool) amount),
               available-liquidity: (+ (get available-liquidity pool) amount)
             }))
      ;; Initialize new pool
      (map-set liquidity-pools
        { asset: asset-contract }
        {
          total-liquidity: amount,
          available-liquidity: amount,
          reserved-liquidity: u0,
          flash-loan-volume: u0,
          hourly-volume: u0,
          last-volume-reset: block-height,
          utilization-rate: u0
        }))
    
    (print {
      event: "liquidity-added",
      provider: tx-sender,
      asset: asset-contract,
      amount: amount
    })
    
    (ok amount)))

(define-public (remove-liquidity (asset <ft-trait>) (amount uint))
  (let ((asset-contract (contract-of asset)))
    (match (map-get? liquidity-pools { asset: asset-contract })
      pool (begin
        (asserts! (>= (get available-liquidity pool) amount) ERR_INSUFFICIENT_LIQUIDITY)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        
        ;; Transfer tokens from vault
        (try! (as-contract (contract-call? asset transfer amount tx-sender tx-sender none)))
        
        ;; Update pool state
        (map-set liquidity-pools
          { asset: asset-contract }
          (merge pool {
            total-liquidity: (- (get total-liquidity pool) amount),
            available-liquidity: (- (get available-liquidity pool) amount)
          }))
        
        (print {
          event: "liquidity-removed",
          provider: tx-sender,
          asset: asset-contract,
          amount: amount
        })
        
        (ok amount))
      ERR_INVALID_ASSET)))

;; =============================================================================
;; VALIDATION AND UTILITY FUNCTIONS
;; =============================================================================
(define-private (validate-flash-loan (asset-contract principal) 
                                     (amount uint)
                                     (config (tuple (enabled bool) (fee-rate uint) (max-loan-amount uint) 
                                                    (min-loan-amount uint) (max-utilization uint) 
                                                    (circuit-breaker-active bool) (total-flash-loaned uint) 
                                                    (last-reset-block uint)))
                                     (pool (tuple (total-liquidity uint) (available-liquidity uint) 
                                                  (reserved-liquidity uint) (flash-loan-volume uint) 
                                                  (hourly-volume uint) (last-volume-reset uint) 
                                                  (utilization-rate uint))))
  (begin
    (asserts! (get enabled config) ERR_ASSET_PAUSED)
    (asserts! (not (get circuit-breaker-active config)) ERR_CIRCUIT_BREAKER_ACTIVE)
    (asserts! (>= amount (get min-loan-amount config)) ERR_INVALID_AMOUNT)
    (asserts! (<= amount (get max-loan-amount config)) ERR_AMOUNT_TOO_LARGE)
    (asserts! (>= (get available-liquidity pool) amount) ERR_INSUFFICIENT_LIQUIDITY)
    
    ;; Check utilization limits
    (let ((max-borrowable (/ (* (get total-liquidity pool) (get max-utilization config)) u10000)))
      (asserts! (<= amount max-borrowable) ERR_AMOUNT_TOO_LARGE))
    
    ;; Check hourly volume limits
    (let ((current-hour-block (/ block-height BLOCKS_PER_HOUR))
          (last-reset-hour (/ (get last-volume-reset pool) BLOCKS_PER_HOUR)))
      (if (> current-hour-block last-reset-hour)
        ;; Reset hourly volume
        (map-set liquidity-pools
          { asset: asset-contract }
          (merge pool { hourly-volume: u0, last-volume-reset: block-height }))
        (asserts! (<= (+ (get hourly-volume pool) amount) MAX_HOURLY_VOLUME) ERR_AMOUNT_TOO_LARGE)))
    
    (ok true)))

(define-read-only (calculate-flash-loan-fee (asset-contract principal) (amount uint))
  (match (map-get? flash-loan-config { asset: asset-contract })
    config (/ (* amount (get fee-rate config)) u10000)
    u0))

(define-read-only (get-available-liquidity (asset-contract principal))
  (match (map-get? liquidity-pools { asset: asset-contract })
    pool (some (get available-liquidity pool))
    none))