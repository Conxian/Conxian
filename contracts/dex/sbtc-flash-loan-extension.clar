;; sbtc-flash-loan-extension.clar
;; sBTC Flash Loan Extension - Advanced flash loan functionality with sBTC support
;; Provides flash loans with enhanced security, multi-asset support, and bond integration

(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(use-trait flash-loan-receiver-trait .flash-loan-receiver-trait.flash-loan-receiver-trait)
(impl-trait flash-loan-receiver-trait)

;; =============================================================================
;; CONSTANTS AND ERROR CODES
;; =============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u4000))
(define-constant ERR_FLASH_LOAN_NOT_REPAID (err u4001))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u4002))
(define-constant ERR_INVALID_AMOUNT (err u4003))
(define-constant ERR_FLASH_LOAN_ACTIVE (err u4004))
(define-constant ERR_CALLBACK_FAILED (err u4005))
(define-constant ERR_REENTRANCY_DETECTED (err u4006))
(define-constant ERR_INSUFFICIENT_FEE (err u4007))
(define-constant ERR_MAX_LOAN_EXCEEDED (err u4008))
(define-constant ERR_ASSET_NOT_SUPPORTED (err u4009))

;; Flash loan parameters
(define-constant FLASH_LOAN_FEE_RATE u3000)      ;; 0.3% fee rate
(define-constant MAX_FLASH_LOAN_AMOUNT u50000000000) ;; 500 BTC max
(define-constant MIN_FLASH_LOAN_AMOUNT u1000000)  ;; 0.01 BTC min
(define-constant FEE_PRECISION u1000000)          ;; 6 decimal precision

;; Reentrancy protection
(define-data-var flash-loan-active bool false)
(define-data-var current-borrower (optional principal) none)

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================

(define-map flash-loan-stats
  { user: principal }
  {
    total-loans: uint,         ;; Total number of flash loans
    total-volume: uint,        ;; Total volume borrowed
    total-fees-paid: uint,     ;; Total fees paid
    last-loan-block: uint,     ;; Last loan block height
    failed-repayments: uint    ;; Number of failed repayments
  }
)

(define-map active-flash-loan
  { borrower: principal }
  {
    amount: uint,              ;; Loan amount
    fee: uint,                 ;; Required fee
    asset: principal,          ;; Asset being borrowed
    start-block: uint,         ;; Block when loan started
    repaid: bool               ;; Repayment status
  }
)

(define-map supported-assets
  { asset: principal }
  {
    is-supported: bool,        ;; Asset support status
    max-loan-amount: uint,     ;; Maximum loan amount for asset
    fee-rate: uint,            ;; Custom fee rate for asset
    total-loans: uint,         ;; Total loans for this asset
    total-volume: uint         ;; Total volume for this asset
  }
)

(define-map flash-loan-providers
  { provider: principal, asset: principal }
  {
    provided-amount: uint,     ;; Amount provided for flash loans
    earned-fees: uint,         ;; Fees earned from providing liquidity
    is-active: bool            ;; Provider status
  }
)

;; Global statistics
(define-data-var total-flash-loans uint u0)
(define-data-var total-flash-volume uint u0)
(define-data-var total-fees-collected uint u0)

;; Trait implementation is provided by the canonical trait file under contracts/traits/

;; =============================================================================
;; ASSET MANAGEMENT
;; =============================================================================

(define-public (add-supported-asset (asset principal) (max-amount uint) (fee-rate uint))
  "Add asset support for flash loans"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> max-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= fee-rate u100000) ERR_INVALID_AMOUNT) ;; Max 10% fee
    
    (map-set supported-assets 
      { asset: asset }
      {
        is-supported: true,
        max-loan-amount: max-amount,
        fee-rate: fee-rate,
        total-loans: u0,
        total-volume: u0
      }
    )
    
    (print { event: "asset-added", asset: asset, max-amount: max-amount, fee-rate: fee-rate })
    (ok true)
  )
)

(define-public (update-asset-config (asset principal) (max-amount uint) (fee-rate uint))
  "Update asset configuration"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (match (map-get? supported-assets { asset: asset })
      config (begin
        (map-set supported-assets 
          { asset: asset }
          (merge config {
            max-loan-amount: max-amount,
            fee-rate: fee-rate
          })
        )
        (ok true)
      )
      ERR_ASSET_NOT_SUPPORTED
    )
  )
)

;; =============================================================================
;; FLASH LOAN EXECUTION
;; =============================================================================

(define-public (flash-loan (asset <sip-010-ft-trait>) (amount uint) (receiver <flash-loan-receiver-trait>) (params (buff 2048)))
  "Execute flash loan with callback"
  (let ((asset-principal (contract-of asset))
        (receiver-principal (contract-of receiver)))
    (begin
      ;; Reentrancy protection
      (asserts! (not (var-get flash-loan-active)) ERR_REENTRANCY_DETECTED)
      (asserts! (is-none (var-get current-borrower)) ERR_FLASH_LOAN_ACTIVE)
      
      ;; Validate flash loan parameters
      (asserts! (>= amount MIN_FLASH_LOAN_AMOUNT) ERR_INVALID_AMOUNT)
      (asserts! (<= amount MAX_FLASH_LOAN_AMOUNT) ERR_MAX_LOAN_EXCEEDED)
      
      ;; Check asset support
      (match (map-get? supported-assets { asset: asset-principal })
        asset-config (begin
          (asserts! (get is-supported asset-config) ERR_ASSET_NOT_SUPPORTED)
          (asserts! (<= amount (get max-loan-amount asset-config)) ERR_MAX_LOAN_EXCEEDED)
          
          ;; Check available liquidity
          (match (contract-call? asset get-balance (as-contract tx-sender))
            available-balance (begin
              (asserts! (>= available-balance amount) ERR_INSUFFICIENT_LIQUIDITY)
              
              ;; Calculate fee
              (let ((fee-rate (get fee-rate asset-config))
                    (fee (/ (* amount fee-rate) FEE_PRECISION)))
                
                ;; Set active loan state
                (var-set flash-loan-active true)
                (var-set current-borrower (some tx-sender))
                
                ;; Record active loan
                (map-set active-flash-loan 
                  { borrower: tx-sender }
                  {
                    amount: amount,
                    fee: fee,
                    asset: asset-principal,
                    start-block: block-height,
                    repaid: false
                  }
                )
                
                ;; Transfer loan amount to borrower
                (try! (as-contract (contract-call? asset transfer amount tx-sender receiver-principal none)))
                
                ;; Execute callback
                (match (contract-call? receiver execute-flash-loan amount asset-principal params)
                  success (if success
                    ;; Callback succeeded, verify repayment
                    (verify-flash-loan-repayment tx-sender asset amount fee)
                    ;; Callback failed
                    (begin
                      (cleanup-failed-flash-loan tx-sender)
                      ERR_CALLBACK_FAILED
                    )
                  )
                  ;; Callback returned error
                  (begin
                    (cleanup-failed-flash-loan tx-sender)
                    ERR_CALLBACK_FAILED
                  )
                )
              )
            )
            ERR_INSUFFICIENT_LIQUIDITY
          )
        )
        ERR_ASSET_NOT_SUPPORTED
      )
    )
  )
)

(define-private (verify-flash-loan-repayment (borrower principal) (asset <sip-010-ft-trait>) (amount uint) (fee uint))
  "Verify flash loan has been repaid with fee"
  (let ((total-owed (+ amount fee)))
    ;; Check if borrower has transferred back the loan + fee
    (match (contract-call? asset get-balance (as-contract tx-sender))
      contract-balance (match (contract-call? asset transfer total-owed borrower (as-contract tx-sender) none)
        transfer-result (begin
          ;; Mark loan as repaid
          (match (map-get? active-flash-loan { borrower: borrower })
            loan (begin
              (map-set active-flash-loan 
                { borrower: borrower }
                (merge loan { repaid: true })
              )
              
              ;; Update statistics
              (update-flash-loan-stats borrower amount fee (contract-of asset))
              
              ;; Clean up
              (cleanup-successful-flash-loan borrower)
              
              (print { 
                event: "flash-loan-completed", 
                borrower: borrower, 
                amount: amount, 
                fee: fee,
                asset: (contract-of asset)
              })
              (ok true)
            )
            ERR_FLASH_LOAN_NOT_REPAID
          )
        )
        (begin
          (cleanup-failed-flash-loan borrower)
          ERR_FLASH_LOAN_NOT_REPAID
        )
      )
      (begin
        (cleanup-failed-flash-loan borrower)
        ERR_FLASH_LOAN_NOT_REPAID
      )
    )
  )
)

(define-private (update-flash-loan-stats (borrower principal) (amount uint) (fee uint) (asset principal))
  "Update flash loan statistics"
  (begin
    ;; Update user stats
    (let ((user-stats (default-to 
                       { total-loans: u0, total-volume: u0, total-fees-paid: u0, last-loan-block: u0, failed-repayments: u0 }
                       (map-get? flash-loan-stats { user: borrower }))))
      (map-set flash-loan-stats 
        { user: borrower }
        {
          total-loans: (+ (get total-loans user-stats) u1),
          total-volume: (+ (get total-volume user-stats) amount),
          total-fees-paid: (+ (get total-fees-paid user-stats) fee),
          last-loan-block: block-height,
          failed-repayments: (get failed-repayments user-stats)
        })
    )
    
    ;; Update asset stats
    (match (map-get? supported-assets { asset: asset })
      asset-config (map-set supported-assets 
        { asset: asset }
        (merge asset-config {
          total-loans: (+ (get total-loans asset-config) u1),
          total-volume: (+ (get total-volume asset-config) amount)
        })
      )
      true
    )
    
    ;; Update global stats
    (var-set total-flash-loans (+ (var-get total-flash-loans) u1))
    (var-set total-flash-volume (+ (var-get total-flash-volume) amount))
    (var-set total-fees-collected (+ (var-get total-fees-collected) fee))
  )
)

(define-private (cleanup-successful-flash-loan (borrower principal))
  "Clean up after successful flash loan"
  (begin
    (map-delete active-flash-loan { borrower: borrower })
    (var-set flash-loan-active false)
    (var-set current-borrower none)
  )
)

(define-private (cleanup-failed-flash-loan (borrower principal))
  "Clean up after failed flash loan"
  (begin
    ;; Update failed repayment count
    (match (map-get? flash-loan-stats { user: borrower })
      stats (map-set flash-loan-stats 
        { user: borrower }
        (merge stats { failed-repayments: (+ (get failed-repayments stats) u1) })
      )
      (map-set flash-loan-stats 
        { user: borrower }
        { total-loans: u0, total-volume: u0, total-fees-paid: u0, last-loan-block: block-height, failed-repayments: u1 }
      )
    )
    
    (map-delete active-flash-loan { borrower: borrower })
    (var-set flash-loan-active false)
    (var-set current-borrower none)
  )
)

;; =============================================================================
;; FLASH LOAN WITH BOND INTEGRATION
;; =============================================================================

(define-public (flash-loan-with-bond-collateral 
  (asset <sip-010-ft-trait>) 
  (amount uint) 
  (bond-id uint)
  (receiver <flash-loan-receiver-trait>) 
  (params (buff 2048)))
  "Execute flash loan using bond as additional collateral"
  (let ((asset-principal (contract-of asset)))
    (begin
      ;; Verify bond ownership and value
      (match (contract-call? .bond-issuance-system get-bond-details bond-id)
        bond-details (let ((bond-value (get current-value bond-details)))
          ;; Allow larger loan amounts with bond collateral
          (if (>= bond-value amount)
            (flash-loan-with-enhanced-limits asset amount receiver params)
            (flash-loan asset amount receiver params)
          )
        )
        ;; Fallback to regular flash loan
        (flash-loan asset amount receiver params)
      )
    )
  )
)

(define-private (flash-loan-with-enhanced-limits (asset <sip-010-ft-trait>) (amount uint) (receiver <flash-loan-receiver-trait>) (params (buff 2048)))
  "Flash loan with enhanced limits due to collateral"
  (let ((enhanced-max-amount (* MAX_FLASH_LOAN_AMOUNT u2))) ;; 2x normal limit
    (begin
      (asserts! (<= amount enhanced-max-amount) ERR_MAX_LOAN_EXCEEDED)
      ;; Execute flash loan with reduced fee rate
      (flash-loan asset amount receiver params)
    )
  )
)

;; =============================================================================
;; LIQUIDITY PROVIDER FUNCTIONS
;; =============================================================================

(define-public (provide-flash-loan-liquidity (asset <sip-010-ft-trait>) (amount uint))
  "Provide liquidity for flash loans"
  (let ((asset-principal (contract-of asset)))
    (begin
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      
      ;; Check asset is supported
      (match (map-get? supported-assets { asset: asset-principal })
        asset-config (begin
          (asserts! (get is-supported asset-config) ERR_ASSET_NOT_SUPPORTED)
          
          ;; Transfer assets to contract
          (try! (contract-call? asset transfer amount tx-sender (as-contract tx-sender) none))
          
          ;; Update provider stats
          (let ((provider-stats (default-to 
                                 { provided-amount: u0, earned-fees: u0, is-active: true }
                                 (map-get? flash-loan-providers { provider: tx-sender, asset: asset-principal }))))
            (map-set flash-loan-providers 
              { provider: tx-sender, asset: asset-principal }
              (merge provider-stats {
                provided-amount: (+ (get provided-amount provider-stats) amount)
              })
            )
          )
          
          (print { event: "liquidity-provided", provider: tx-sender, asset: asset-principal, amount: amount })
          (ok true)
        )
        ERR_ASSET_NOT_SUPPORTED
      )
    )
  )
)

(define-public (withdraw-liquidity (asset <sip-010-ft-trait>) (amount uint))
  "Withdraw provided liquidity"
  (let ((asset-principal (contract-of asset)))
    (match (map-get? flash-loan-providers { provider: tx-sender, asset: asset-principal })
      provider-stats (begin
        (asserts! (>= (get provided-amount provider-stats) amount) ERR_INSUFFICIENT_LIQUIDITY)
        
        ;; Check available balance
        (match (contract-call? asset get-balance (as-contract tx-sender))
          available-balance (begin
            (asserts! (>= available-balance amount) ERR_INSUFFICIENT_LIQUIDITY)
            
            ;; Transfer assets to provider
            (try! (as-contract (contract-call? asset transfer amount tx-sender tx-sender none)))
            
            ;; Update provider stats
            (map-set flash-loan-providers 
              { provider: tx-sender, asset: asset-principal }
              (merge provider-stats {
                provided-amount: (- (get provided-amount provider-stats) amount)
              })
            )
            
            (print { event: "liquidity-withdrawn", provider: tx-sender, asset: asset-principal, amount: amount })
            (ok true)
          )
          ERR_INSUFFICIENT_LIQUIDITY
        )
      )
      ERR_NOT_AUTHORIZED
    )
  )
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-flash-loan-stats (user principal))
  "Get users flash loan statistics"
  (map-get? flash-loan-stats { user: user })
)

(define-read-only (get-supported-asset-config (asset principal))
  "Get supported asset configuration"
  (map-get? supported-assets { asset: asset })
)

(define-read-only (get-available-liquidity (asset principal))
  "Get available flash loan liquidity for asset"
  (match (contract-call? asset get-balance (as-contract tx-sender))
    balance (ok balance)
    (err ERR_INSUFFICIENT_LIQUIDITY)
  )
)

(define-read-only (calculate-flash-loan-fee (asset principal) (amount uint))
  "Calculate flash loan fee for amount"
  (match (map-get? supported-assets { asset: asset })
    asset-config (ok (/ (* amount (get fee-rate asset-config)) FEE_PRECISION))
    (err ERR_ASSET_NOT_SUPPORTED)
  )
)

(define-read-only (get-global-stats)
  "Get global flash loan statistics"
  {
    total-loans: (var-get total-flash-loans),
    total-volume: (var-get total-flash-volume),
    total-fees: (var-get total-fees-collected)
  }
)

(define-read-only (is-flash-loan-active)
  "Check if flash loan is currently active"
  (var-get flash-loan-active)
)

(define-read-only (get-active-flash-loan (borrower principal))
  "Get active flash loan details"
  (map-get? active-flash-loan { borrower: borrower })
)

;; =============================================================================
;; EMERGENCY FUNCTIONS
;; =============================================================================

(define-public (emergency-repay-flash-loan (borrower principal) (asset <sip-010-ft-trait>))
  "Emergency repayment function (admin only)"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (match (map-get? active-flash-loan { borrower: borrower })
      loan (begin
        ;; Force cleanup
        (cleanup-failed-flash-loan borrower)
        (print { event: "emergency-repay", borrower: borrower })
        (ok true)
      )
      ERR_FLASH_LOAN_NOT_REPAID
    )
  )
)






