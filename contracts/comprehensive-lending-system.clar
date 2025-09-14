;; comprehensive-lending-system.clar
;; Full-featured lending and borrowing system with flash loans
;; Supports multiple assets, collateralization, and liquidations

(impl-trait .lending-system-trait.lending-system-trait)

(use-trait sip10 .sip-010-trait.sip-010-trait)
(use-trait flash-loan-receiver .flash-loan-receiver-trait.flash-loan-receiver-trait)

;; === CONSTANTS ===
(define-constant ERR_UNAUTHORIZED (err u5001))
(define-constant ERR_PAUSED (err u5002))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u5003))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u5004))
(define-constant ERR_FLASH_LOAN_FAILED (err u5005))
(define-constant ERR_INVALID_ASSET (err u5006))
(define-constant ERR_ZERO_AMOUNT (err u5007))
(define-constant ERR_TRANSFER_FAILED (err u5008))
(define-constant ERR_POSITION_HEALTHY (err u5009))
(define-constant ERR_LIQUIDATION_TOO_MUCH (err u5010))

(define-constant PRECISION u1000000000000000000) ;; 18 decimals
(define-constant LIQUIDATION_BONUS u50000000000000000) ;; 5% liquidation bonus
(define-constant CLOSE_FACTOR u500000000000000000) ;; 50% max liquidation per tx
(define-constant MIN_HEALTH_FACTOR u1000000000000000000) ;; 1.0 minimum health factor

;; === ADMIN ===
(define-data-var admin principal tx-sender)
(define-data-var paused bool false)

;; === SUPPORTED ASSETS ===
(define-map supported-assets
  { asset: principal }
  {
    is-supported: bool,
    collateral-factor: uint,    ;; Percentage of value that can be borrowed against
    liquidation-threshold: uint, ;; Percentage at which liquidation can occur
    liquidation-bonus: uint,     ;; Bonus for liquidators
    flash-loan-enabled: bool,
    flash-loan-fee-bps: uint    ;; Flash loan fee in basis points
  })

(define-data-var supported-assets-list (list 50 principal) (list))

;; === USER BALANCES ===
;; User supply balances (principal amounts)
(define-map user-supply-balances
  { user: principal, asset: principal }
  { 
    principal-balance: uint,
    supply-index: uint
  })

;; User borrow balances (principal amounts)
(define-map user-borrow-balances
  { user: principal, asset: principal }
  {
    principal-balance: uint,
    borrow-index: uint
  })

;; User collateral status
(define-map user-collateral-status
  { user: principal, asset: principal }
  { is-collateral: bool })

;; === ORACLE INTEGRATION ===
;; Simple price storage (in production, would integrate with external oracle)
(define-map asset-prices
  { asset: principal }
  { price: uint, last-update: uint }) ;; Price in USD with 18 decimals

;; === ADMIN FUNCTIONS ===
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)))

(define-public (set-paused (pause bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set paused pause)
    (ok true)))

(define-public (add-supported-asset 
  (asset <sip10>) 
  (collateral-factor uint) 
  (liquidation-threshold uint) 
  (liquidation-bonus uint)
  (flash-loan-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (<= collateral-factor PRECISION) ERR_UNAUTHORIZED)
    (asserts! (<= liquidation-threshold PRECISION) ERR_UNAUTHORIZED)
    (asserts! (<= liquidation-bonus PRECISION) ERR_UNAUTHORIZED)
    (asserts! (<= flash-loan-fee-bps u10000) ERR_UNAUTHORIZED) ;; Max 100%
    
    (let ((asset-principal (contract-of asset)))
      (map-set supported-assets
        { asset: asset-principal }
        {
          is-supported: true,
          collateral-factor: collateral-factor,
          liquidation-threshold: liquidation-threshold,
          liquidation-bonus: liquidation-bonus,
          flash-loan-enabled: true,
          flash-loan-fee-bps: flash-loan-fee-bps
        })
      
      ;; Initialize market in interest rate model
      (try! (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.interest-rate-model initialize-market asset-principal u0))

      ;; Add to the list of supported assets
      (var-set supported-assets-list (unwrap-panic (as-max-len? (append (var-get supported-assets-list) asset-principal) u50)))

      (ok true))))

(define-public (set-asset-price (asset <sip10>) (price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (let ((asset-principal (contract-of asset)))
      (map-set asset-prices
        { asset: asset-principal }
        { price: price, last-update: block-height })
      (ok true))))

;; === SUPPLY FUNCTIONS ===
(define-public (supply (asset <sip10>) (amount uint))
  (let ((user tx-sender)
        (asset-principal (contract-of asset)))
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> amount u0) ERR_ZERO_AMOUNT)
      (asserts! (is-asset-supported asset-principal) ERR_INVALID_ASSET)
      
      ;; Update interest before supply
      (unwrap! (contract-call? .interest-rate-model accrue-interest asset-principal) ERR_INVALID_ASSET)
      
      ;; Transfer tokens from user
      (unwrap! (contract-call? asset transfer amount user (as-contract tx-sender) none) ERR_TRANSFER_FAILED)
      
      ;; Get current supply index
      (let ((market-info (unwrap! (contract-call? .interest-rate-model get-market-info asset-principal) ERR_INVALID_ASSET))
            (current-supply-index (get supply-index market-info))
            (current-balance (get-user-supply-balance user asset-principal))
            (new-principal-balance (+ (get principal-balance current-balance) 
                                    (/ (* amount PRECISION) current-supply-index))))
        
        ;; Update user balance
        (map-set user-supply-balances
          { user: user, asset: asset-principal }
          {
            principal-balance: new-principal-balance,
            supply-index: current-supply-index
          })
        
        ;; Update market state
        (unwrap! (contract-call? .interest-rate-model update-market-state 
                                asset-principal 
                                (to-int amount) 
                                0 
                                (to-int amount)) ERR_INVALID_ASSET)
        
        ;; Enable as collateral by default
        (map-set user-collateral-status
          { user: user, asset: asset-principal }
          { is-collateral: true })
        
        (ok amount)))))

(define-public (withdraw (asset <sip10>) (amount uint))
  (let ((user tx-sender)
        (asset-principal (contract-of asset)))
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> amount u0) ERR_ZERO_AMOUNT)
      (asserts! (is-asset-supported asset-principal) ERR_INVALID_ASSET)
      
      ;; Update interest before withdrawal
      (unwrap! (contract-call? .interest-rate-model accrue-interest asset-principal) ERR_INVALID_ASSET)
      
      (let ((current-balance (get-user-supply-balance user asset-principal))
            (current-supply-balance (contract-call? .interest-rate-model calculate-current-supply-balance
                                                   asset-principal 
                                                   (get principal-balance current-balance)
                                                   (get supply-index current-balance))))
        
        (asserts! (>= current-supply-balance amount) ERR_INSUFFICIENT_LIQUIDITY)
        
        ;; Check if withdrawal would make user undercollateralized
        (try! (check-account-liquidity user asset-principal (- (to-int amount))))
        
        ;; Calculate new principal balance
        (let ((market-info (unwrap! (contract-call? .interest-rate-model get-market-info asset-principal) ERR_INVALID_ASSET))
              (current-supply-index (get supply-index market-info))
              (principal-to-remove (/ (* amount PRECISION) current-supply-index))
              (new-principal-balance (- (get principal-balance current-balance) principal-to-remove)))
          
          ;; Update user balance
          (map-set user-supply-balances
            { user: user, asset: asset-principal }
            {
              principal-balance: new-principal-balance,
              supply-index: current-supply-index
            })
          
          ;; Update market state
          (try! (contract-call? .interest-rate-model update-market-state 
                               asset-principal 
                               (- (to-int amount))
                               0 
                               (- (to-int amount))))
          
          ;; Transfer tokens to user
          (try! (as-contract (contract-call? asset transfer amount tx-sender user none)))
          
          (ok amount))))))

;; === BORROW FUNCTIONS ===
(define-public (borrow (asset <sip10>) (amount uint))
  (let ((user tx-sender)
        (asset-principal (contract-of asset)))
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> amount u0) ERR_ZERO_AMOUNT)
      (asserts! (is-asset-supported asset-principal) ERR_INVALID_ASSET)
      
      ;; Update interest before borrow
      (unwrap! (contract-call? .interest-rate-model accrue-interest asset-principal) ERR_INVALID_ASSET)
      
      ;; Check if user has enough collateral
      (try! (check-account-liquidity user asset-principal (to-int amount)))
      
      ;; Check if market has enough liquidity
      (let ((market-info (unwrap! (contract-call? .interest-rate-model get-market-info asset-principal) ERR_INVALID_ASSET))
            (available-cash (get total-cash market-info)))
        (asserts! (>= available-cash amount) ERR_INSUFFICIENT_LIQUIDITY)
        
        (let ((current-borrow-index (get borrow-index market-info))
              (current-balance (get-user-borrow-balance user asset-principal))
              (new-principal-balance (+ (get principal-balance current-balance)
                                      (/ (* amount PRECISION) current-borrow-index))))
          
          ;; Update user balance
          (map-set user-borrow-balances
            { user: user, asset: asset-principal }
            {
              principal-balance: new-principal-balance,
              borrow-index: current-borrow-index
            })
          
          ;; Update market state
          (try! (contract-call? .interest-rate-model update-market-state 
                               asset-principal 
                               (- (to-int amount))
                               (to-int amount) 
                               0))
          
          ;; Transfer tokens to user
          (try! (as-contract (contract-call? asset transfer amount tx-sender user none)))
          
          (ok amount))))))

(define-public (repay (asset <sip10>) (amount uint))
  (let ((user tx-sender)
        (asset-principal (contract-of asset)))
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> amount u0) ERR_ZERO_AMOUNT)
      (asserts! (is-asset-supported asset-principal) ERR_INVALID_ASSET)
      
      ;; Update interest before repay
      (unwrap! (contract-call? .interest-rate-model accrue-interest asset-principal) ERR_INVALID_ASSET)
      
      (let ((current-balance (get-user-borrow-balance user asset-principal))
            (current-borrow-balance (contract-call? .interest-rate-model calculate-current-borrow-balance
                                                   asset-principal 
                                                   (get principal-balance current-balance)
                                                   (get borrow-index current-balance)))
            (actual-repay-amount (min amount current-borrow-balance)))
        
        ;; Transfer tokens from user
        (try! (contract-call? asset transfer actual-repay-amount user (as-contract tx-sender) none))
        
        ;; Calculate new principal balance
        (let ((market-info (unwrap! (contract-call? .interest-rate-model get-market-info asset-principal) ERR_INVALID_ASSET))
              (current-borrow-index (get borrow-index market-info))
              (principal-to-remove (/ (* actual-repay-amount PRECISION) current-borrow-index))
              (new-principal-balance (- (get principal-balance current-balance) principal-to-remove)))
          
          ;; Update user balance
          (map-set user-borrow-balances
            { user: user, asset: asset-principal }
            {
              principal-balance: new-principal-balance,
              borrow-index: current-borrow-index
            })
          
          ;; Update market state
          (try! (contract-call? .interest-rate-model update-market-state 
                               asset-principal 
                               (to-int actual-repay-amount)
                               (- (to-int actual-repay-amount))
                               0))
          
          (ok actual-repay-amount))))))

;; === FLASH LOAN FUNCTIONS ===
(define-public (flash-loan-extended (asset <sip10>) (amount uint) (receiver <flash-loan-receiver>) (data (buff 256)))
  (let ((asset-principal (contract-of asset)))
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> amount u0) ERR_ZERO_AMOUNT)
      (asserts! (is-flash-loan-supported asset-principal) ERR_INVALID_ASSET)
      
      ;; Calculate fee
      (let ((fee (calculate-flash-loan-fee asset-principal amount))
            (market-info (unwrap! (contract-call? .interest-rate-model get-market-info asset-principal) ERR_INVALID_ASSET))
            (available-cash (get total-cash market-info)))
        
        (asserts! (>= available-cash amount) ERR_INSUFFICIENT_LIQUIDITY)
        
        ;; Record balances before
        (let ((balance-before (unwrap! (contract-call? asset get-balance (as-contract tx-sender)) ERR_FLASH_LOAN_FAILED)))
          
          ;; Transfer loan amount to receiver
          (try! (as-contract (contract-call? asset transfer amount tx-sender (contract-of receiver) none)))
          
          ;; Call receiver's flash loan callback
          (try! (contract-call? receiver on-flash-loan tx-sender asset-principal amount fee data))
          
          ;; Check that loan + fee was repaid
          (let ((balance-after (unwrap! (contract-call? asset get-balance (as-contract tx-sender)) ERR_FLASH_LOAN_FAILED)))
            (asserts! (>= balance-after (+ balance-before fee)) ERR_FLASH_LOAN_FAILED)
            
            ;; Distribute fee (could be sent to treasury or used for reserves)
            ;; For now, keep it in the contract as additional liquidity
            
            (ok true)))))))

;; === LIQUIDATION ===
(define-public (liquidate (borrower principal) (asset <sip10>) (repay-amount uint))
  (let ((liquidator tx-sender)
        (asset-principal (contract-of asset)))
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> repay-amount u0) ERR_ZERO_AMOUNT)
      (asserts! (is-asset-supported asset-principal) ERR_INVALID_ASSET)
      
      ;; Update interest before liquidation
      (unwrap! (contract-call? .interest-rate-model accrue-interest asset-principal) ERR_INVALID_ASSET)
      
      ;; Check if borrower is liquidatable
      (let ((health-factor (unwrap-panic (get-health-factor borrower))))
        (asserts! (< health-factor MIN_HEALTH_FACTOR) ERR_POSITION_HEALTHY)
        
        ;; Calculate max liquidatable amount
        (let ((borrow-balance (get-user-borrow-balance borrower asset-principal))
              (current-debt (contract-call? .interest-rate-model calculate-current-borrow-balance
                                           asset-principal 
                                           (get principal-balance borrow-balance)
                                           (get borrow-index borrow-balance)))
              (max-liquidatable (/ (* current-debt CLOSE_FACTOR) PRECISION))
              (actual-repay-amount (min repay-amount max-liquidatable)))
          
          (asserts! (<= actual-repay-amount max-liquidatable) ERR_LIQUIDATION_TOO_MUCH)
          
          ;; Transfer repayment from liquidator
          (try! (contract-call? asset transfer actual-repay-amount liquidator (as-contract tx-sender) none))
          
          ;; Reduce borrower's debt
          (let ((market-info (unwrap! (contract-call? .interest-rate-model get-market-info asset-principal) ERR_INVALID_ASSET))
                (current-borrow-index (get borrow-index market-info))
                (principal-to-remove (/ (* actual-repay-amount PRECISION) current-borrow-index))
                (new-principal-balance (- (get principal-balance borrow-balance) principal-to-remove)))
            
            (map-set user-borrow-balances
              { user: borrower, asset: asset-principal }
              {
                principal-balance: new-principal-balance,
                borrow-index: current-borrow-index
              })
            
            ;; Calculate collateral to seize (with bonus)
            (let ((asset-price (get-asset-price asset-principal))
                  (collateral-value (/ (* actual-repay-amount asset-price) PRECISION))
                  (liquidation-bonus (get-liquidation-bonus asset-principal))
                  (seize-value (/ (* collateral-value (+ PRECISION liquidation-bonus)) PRECISION)))
              
              ;; TODO: Seize collateral from borrower's supply positions
              ;; This would involve finding the best collateral to seize
              ;; and transferring it to the liquidator
              
              ;; Update market state
              (try! (contract-call? .interest-rate-model update-market-state 
                                   asset-principal 
                                   (to-int actual-repay-amount)
                                   (- (to-int actual-repay-amount))
                                   0))
              
              (ok actual-repay-amount))))))))

;; === HELPER FUNCTIONS ===
(define-private (is-asset-supported (asset-principal principal))
  (default-to false (get is-supported (map-get? supported-assets { asset: asset-principal }))))

(define-private (is-flash-loan-supported (asset-principal principal))
  (default-to false (get flash-loan-enabled (map-get? supported-assets { asset: asset-principal }))))

(define-private (get-user-supply-balance (user principal) (asset-principal principal))
  (default-to 
    { principal-balance: u0, supply-index: PRECISION }
    (map-get? user-supply-balances { user: user, asset: asset-principal })))

(define-private (get-user-borrow-balance (user principal) (asset-principal principal))
  (default-to 
    { principal-balance: u0, borrow-index: PRECISION }
    (map-get? user-borrow-balances { user: user, asset: asset-principal })))

(define-private (get-asset-price (asset-principal principal))
  (default-to u1000000000000000000 ;; Default to $1
              (get price (map-get? asset-prices { asset: asset-principal }))))

(define-private (get-liquidation-bonus (asset-principal principal))
  (default-to LIQUIDATION_BONUS
              (get liquidation-bonus (map-get? supported-assets { asset: asset-principal }))))

(define-private (calculate-flash-loan-fee (asset-principal principal) (amount uint))
  (let ((fee-bps (default-to u30 ;; Default 0.3%
                             (get flash-loan-fee-bps (map-get? supported-assets { asset: asset-principal })))))
    (/ (* amount fee-bps) u10000)))

(define-private (min (a uint) (b uint))
  (if (<= a b) a b))

;; Check if user would remain sufficiently collateralized after a change
(define-private (check-account-liquidity (user principal) (asset-principal principal) (amount-change int))
  (let ((collateral-value (unwrap! (get-collateral-value user) ERR_INSUFFICIENT_COLLATERAL))
        (current-borrow-value (get-total-borrow-value user))
        (asset-price (get-asset-price asset-principal)))
    (let ((value-change (if (>= amount-change 0)
                          (/ (* (to-uint amount-change) asset-price) PRECISION)
                          (/ (* (to-uint (- amount-change)) asset-price) PRECISION)))
          (adjusted-borrow-value (if (>= amount-change 0)
                                   (+ current-borrow-value value-change)
                                   (- current-borrow-value value-change))))
      (let ((collateral-factor (default-to u800000000000000000 ;; 80% default
                                           (get collateral-factor (map-get? supported-assets { asset: asset-principal }))))
            (max-borrow-value (/ (* collateral-value collateral-factor) PRECISION)))
        (asserts! (<= adjusted-borrow-value max-borrow-value) ERR_INSUFFICIENT_COLLATERAL)
        (ok true)))))

(define-private (get-total-borrow-value (user principal))
  (get total-value (fold calculate-user-borrow-value 
        (var-get supported-assets-list)
        { user: user, total-value: u0 })))

(define-private (calculate-user-borrow-value (asset-principal principal) (acc { user: principal, total-value: uint }))
  (let ((user (get user acc))
        (balance (get-user-borrow-balance user asset-principal)))
    (if (> (get principal-balance balance) u0)
      (let ((current-balance (contract-call? .interest-rate-model calculate-current-borrow-balance
                                                         asset-principal
                                                         (get principal-balance balance)
                                                         (get borrow-index balance)))
            (price (get-asset-price asset-principal)))
        (let ((value (/ (* current-balance price) PRECISION)))
          { user: user, total-value: (+ (get total-value acc) value) }))
      acc)))

;; === VIEW FUNCTIONS ===
(define-read-only (get-supply-balance (user principal) (asset <sip10>))
  (let ((asset-principal (contract-of asset))
        (balance (get-user-supply-balance user asset-principal)))
    (ok (contract-call? .interest-rate-model calculate-current-supply-balance
                       asset-principal
                       (get principal-balance balance)
                       (get supply-index balance)))))

(define-read-only (get-borrow-balance (user principal) (asset <sip10>))
  (let ((asset-principal (contract-of asset))
        (balance (get-user-borrow-balance user asset-principal)))
    (ok (contract-call? .interest-rate-model calculate-current-borrow-balance
                       asset-principal
                       (get principal-balance balance)
                       (get borrow-index balance)))))

(define-read-only (get-collateral-value (user principal))
  (ok (get total-value (fold calculate-user-collateral-value
        (var-get supported-assets-list)
        { user: user, total-value: u0 }))))

(define-private (calculate-user-collateral-value (asset-principal principal) (acc { user: principal, total-value: uint }))
  (let ((user (get user acc))
        (is-collateral (default-to false (get is-collateral (map-get? user-collateral-status { user: user, asset: asset-principal })))))
    (if is-collateral
      (let ((balance (get-user-supply-balance user asset-principal)))
        (if (> (get principal-balance balance) u0)
          (let ((current-balance (contract-call? .interest-rate-model calculate-current-supply-balance
                                                             asset-principal
                                                             (get principal-balance balance)
                                                             (get supply-index balance)))
                (price (get-asset-price asset-principal)))
            (let ((value (/ (* current-balance price) PRECISION)))
              { user: user, total-value: (+ (get total-value acc) value) }))
          acc))
      acc)))

(define-read-only (get-health-factor (user principal))
  (let ((collateral-value (unwrap-panic (get-collateral-value user)))
        (borrow-value (get-total-borrow-value user)))
    (if (is-eq borrow-value u0)
      (ok (* u1000 PRECISION)) ;; Very high health factor if no debt
      (ok (/ (* collateral-value PRECISION) borrow-value)))))

(define-read-only (get-supply-apy (asset <sip10>))
  (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.interest-rate-model get-supply-apy (contract-of asset)))

(define-read-only (get-borrow-apy (asset <sip10>))
  (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.interest-rate-model get-borrow-apy (contract-of asset)))

(define-read-only (get-max-flash-loan (asset <sip10>))
  (let ((asset-principal (contract-of asset)))
    (if (is-flash-loan-supported asset-principal)
      (match (contract-call? .interest-rate-model get-market-info asset-principal)
        market-info (ok (get total-cash market-info))
        error (ok u0))
      (ok u0))))

(define-read-only (get-flash-loan-fee (asset <sip10>) (amount uint))
  (ok (calculate-flash-loan-fee (contract-of asset) amount)))

;; === ADMIN INTERFACE IMPLEMENTATION ===
(define-public (set-interest-rate-model (asset <sip10>) (base-rate uint) (multiplier uint) (jump-multiplier uint) (kink uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.interest-rate-model set-interest-rate-model 
                    (contract-of asset) 
                    base-rate 
                    multiplier 
                    jump-multiplier 
                    kink)))

(define-public (set-collateral-factor (asset <sip10>) (factor uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (match (map-get? supported-assets { asset: (contract-of asset) })
      asset-config
        (begin
          (map-set supported-assets
            { asset: (contract-of asset) }
            (merge asset-config { collateral-factor: factor }))
          (ok true))
      ERR_INVALID_ASSET)))

(define-public (set-liquidation-threshold (asset <sip10>) (threshold uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (match (map-get? supported-assets { asset: (contract-of asset) })
      asset-config
        (begin
          (map-set supported-assets
            { asset: (contract-of asset) }
            (merge asset-config { liquidation-threshold: threshold }))
          (ok true))
      ERR_INVALID_ASSET)))
