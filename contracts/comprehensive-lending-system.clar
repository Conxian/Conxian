;; comprehensive-lending-system.clar
;; Full-featured lending and borrowing system with flash loans
;; Supports multiple assets, collateralization, and liquidations

(impl-trait .lending-system-trait.lending-system-trait)

(use-trait sip10 .sip-010-trait.sip-010-trait)
(use-trait flash-loan-receiver .flash-loan-receiver-trait.flash-loan-receiver-trait)

;; Oracle contract
(define-constant ORACLE_CONTRACT_PRINCIPAL 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-constant ORACLE_CONTRACT (contract-of ORACLE_CONTRACT_PRINCIPAL))

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
(define-constant ERR_INTEREST_ACCRUAL_FAILED (err u5011))

(define-constant PRECISION u1000000000000000000) ;; 18 decimals
(define-constant LIQUIDATION_BONUS u50000000000000000) ;; 5% liquidation bonus
(define-constant CLOSE_FACTOR u500000000000000000) ;; 50% max liquidation per tx
(define-constant MIN_HEALTH_FACTOR u1000000000000000000) ;; 1.0 minimum health factor

;; === ADMIN ===
(define-data-var admin principal tx-sender)
(define-data-var total-borrows uint u0)
(define-data-var paused bool false)

(define-map total-supply { asset: principal } { amount: uint })

(define-private (decrease-total-supply (asset principal) (amount uint))
  (let ((current (default-to { amount: u0 } (map-get? total-supply { asset: asset }))))
    (asserts! (>= (get amount current) amount) ERR_INSUFFICIENT_LIQUIDITY)
    (map-set total-supply { asset: asset } { amount: (- (get amount current) amount) })
    (ok amount)))

(define-private (increase-total-supply (asset principal) (amount uint))
  (let ((current (default-to { amount: u0 } (map-get? total-supply { asset: asset }))))
    (map-set total-supply { asset: asset } { amount: (+ (get amount current) amount) })
    (ok amount)))

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

(define-read-only (is-asset-supported (asset principal))
  (is-some (map-get? supported-assets { asset: asset })))

(define-read-only (get-user-supply-balance (user principal) (asset principal))
  (default-to 
    { principal-balance: u0, supply-index: u1000000000000000 } 
    (map-get? user-supply-balances { user: user, asset: asset })))

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

;; === UTILITY FUNCTIONS ===
;; Calculate the total collateral value for a user
(define-read-only (get-collateral-value (user principal))
  (let ((collateral-value u0)
        (supply-balances (filter (lambda (entry) 
          (let ((asset (get asset entry)))
            (default-to false (get is-collateral (map-get? user-collateral-status { user: user, asset: asset }))))
          ) (map-get? user-supply-balances { user: user }))))
    (fold (lambda (acc entry)
      (let* ((asset (get asset entry))
             (balance (get balance entry))
             (amount (get principal-balance balance))
             (asset-info (unwrap! (map-get? supported-assets { asset: asset }) (err ERR_INVALID_ASSET)))
             (price (unwrap-panic (get-asset-price asset)))
             (collateral-factor (get collateral-factor asset-info)))
        (+ acc (/ (* amount price collateral-factor) PRECISION))
      ))
      collateral-value
      supply-balances
    )
  )
)

(define-read-only (get-total-borrow-value (user principal))
  (let ((borrow-value u0)
        (user-borrows (default-to (list) (map-get? user-borrow-balances { user: user }))))
    (fold (lambda (acc entry)
      (let* ((asset (get asset entry))
             (amount (get principal-balance (get balance entry)))
             (price (unwrap-panic (get-asset-price asset)))
             (borrow-info (unwrap! (map-get? supported-assets { asset: asset }) (err ERR_INVALID_ASSET))))
        (+ acc (/ (* amount price) PRECISION))
      ))
      borrow-value
      user-borrows
    )
  )
)

;; Get the price of an asset from the oracle
(define-read-only (get-asset-price (asset principal))
  (match (contract-call? ORACLE_CONTRACT get-price asset none)
    (ok price) (ok price)
    (err error) (err ERR_PRICE_UNAVAILABLE)
  )
)

;; Check if a position is liquidatable
(define-read-only (is-position-liquidatable (user principal))
  (let ((collateral-value (unwrap! (get-collateral-value user) ERR_INSUFFICIENT_COLLATERAL))
        (borrow-value (get-total-borrow-value user)))
    (>= borrow-value collateral-value)
  )
)

;; === SUPPLY FUNCTIONS ===
(define-private (check-account-liquidity (user principal) (asset principal) (amount int))
  (let ((collateral-value (unwrap! (get-collateral-value user) ERR_INSUFFICIENT_COLLATERAL))
        (current-borrow-value (get-total-borrow-value user))
        (asset-price (get-asset-price asset)))
    
    (let ((value-change (if (< amount 0) 
                          (/ (* (- amount) asset-price) PRECISION)
                          u0))
          (adjusted-borrow-value (if (> amount 0)
                                  (+ current-borrow-value amount)
                                  current-borrow-value)))
      
      (let ((collateral-factor (default-to u800000000000000000 ;; 80% default
                                         (get collateral-factor (map-get? supported-assets { asset: asset }))))
            (max-borrow-value (/ (* collateral-value collateral-factor) PRECISION)))
        
        (asserts! (<= adjusted-borrow-value max-borrow-value) ERR_INSUFFICIENT_COLLATERAL)
        (ok true)
      )
    )
  ))

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
      
      ;; Accrue interest to ensure up-to-date calculations
      (unwrap-panic (contract-call? .interest-rate-model accrue-interest asset-principal))
      
      (let ((current-balance (get-user-supply-balance user asset-principal))
            (current-supply-balance (get principal-balance current-balance)))
        
        (asserts! (>= current-supply-balance amount) ERR_INSUFFICIENT_LIQUIDITY)
        
        ;; Check if withdrawal would make user undercollateralized
        (try! (check-account-liquidity user asset-principal (- amount)))
        
        (let ((market-info (unwrap! (contract-call? .interest-rate-model get-market-info asset-principal) ERR_INVALID_ASSET))
              (current-supply-index (get supply-index market-info))
              (principal-to-remove (/ (* amount PRECISION) current-supply-index))
              (new-principal-balance (- (get principal-balance current-balance) principal-to-remove)))
          
          (match (as-contract (contract-call? asset transfer amount tx-sender user none))
            (ok true) 
            (match (contract-call? .interest-rate-model update-market-state 
                    asset-principal 
                    (- (to-int amount))
                    0 
                    (- (to-int amount)))
              (ok update-ok) 
              (begin
                (map-set user-supply-balances
                  { user: user, asset: asset-principal }
                  {
                    principal-balance: new-principal-balance,
                    supply-index: current-supply-index
                  })
                (decrease-total-supply asset-principal principal-to-remove)
                (ok amount))
              (err update-error))
            (err transfer-error))
          )
        )
      )
    )
  )

;; === BORROW FUNCTIONS ===
(define-public (borrow (asset <sip10>) (amount uint))
  (let ((user tx-sender)
        (asset-principal (contract-of asset)))
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> amount u0) ERR_ZERO_AMOUNT)
      (asserts! (is-asset-supported asset-principal) ERR_INVALID_ASSET)
      
      ;; Update interest before borrowing
      (unwrap-panic (contract-call? .interest-rate-model accrue-interest asset-principal))
      
      ;; Check if user has enough collateral
      (try! (check-account-liquidity user asset-principal amount))
      
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
      (match (contract-call? .interest-rate-model accrue-interest asset-principal)
        (ok result) 
        (let ((current-balance (get-user-borrow-balance user asset-principal)))
          (match (contract-call? .interest-rate-model calculate-current-borrow-balance 
                               asset-principal 
                               (get principal-balance current-balance)
                               (get borrow-index current-balance))
            (ok current-borrow-balance)
            (let ((actual-repay-amount (min amount current-borrow-balance)))
              ;; Transfer tokens from user
              (try! (contract-call? asset transfer actual-repay-amount user (as-contract tx-sender) none))
              
              ;; Calculate new principal balance
              (match (contract-call? .interest-rate-model get-market-info asset-principal)
                (ok market-info)
                (let ((current-borrow-index (get borrow-index market-info))
                      (principal-to-remove (/ (* actual-repay-amount PRECISION) current-borrow-index))
                      (new-principal-balance (- (get principal-balance current-balance) principal-to-remove)))
                  (if (<= new-principal-balance u0)
                      (map-delete user-borrow-balances { user: user, asset: asset-principal })
                      (map-set user-borrow-balances 
                              { user: user, asset: asset-principal }
                              { 
                                principal-balance: new-principal-balance,
                                borrow-index: current-borrow-index
                              }))
                  
                  ;; Update market state
                  (match (contract-call? .interest-rate-model update-market-state 
                                      asset-principal 
                                      (to-int actual-repay-amount)
                                      0 
                                      (- (to-int actual-repay-amount)))
                    (ok result) (ok actual-repay-amount)
                    (err error) (err error)))
                error (err error)))
            error (err error)))
        error (err error)))))

;; === LIQUIDATION ===
(define-public (liquidate (borrower principal) (asset <sip10>) (repay-amount uint))
  (let ((liquidator tx-sender)
        (asset-principal (contract-of asset)))
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> repay-amount u0) ERR_ZERO_AMOUNT)
      (asserts! (is-asset-supported asset-principal) ERR_INVALID_ASSET)
      
      ;; Update interest before liquidation
      (let ((interest-result (unwrap! (contract-call? .interest-rate-model accrue-interest asset-principal) (err u1003))))
        (asserts! (is-ok interest-result) (err (unwrap-err! interest-result u1003))))
      
      ;; Check if borrower is liquidatable
      (let ((health-factor (unwrap! (get-health-factor borrower) (err u5009))))
        (asserts! (< health-factor MIN_HEALTH_FACTOR) (err u5009))
        
        ;; Calculate max liquidatable amount
        (let ((borrow-balance (get-user-borrow-balance borrower asset-principal))
              (current-debt (unwrap! 
                (contract-call? .interest-rate-model calculate-current-borrow-balance 
                  asset-principal 
                  (get principal-balance borrow-balance)
                  (get borrow-index borrow-balance))
                (err u1004))
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
              
              ;; Convert seize-value to amount of collateral asset
              (let ((collateral-asset (unwrap! (get-collateral-asset borrower) (err u1005)))
                    (collateral-price (get-asset-price collateral-asset))
                    (amount-to-seize (/ (* seize-value PRECISION) collateral-price))
                    (borrower-balance (get-user-supply-balance borrower collateral-asset))
                    (borrower-amount (get principal-balance borrower-balance)))
                
                ;; Verify borrower has sufficient collateral
                (asserts! (>= borrower-amount amount-to-seize) ERR_INSUFFICIENT_COLLATERAL)
                
                ;; Update borrower's balance
                (map-set user-supply-balances
                         { user: borrower, asset: collateral-asset }
                         { principal-balance: (- borrower-amount amount-to-seize), 
                           supply-index: (get supply-index borrower-balance) })
                
                ;; Update liquidator's balance
                (let ((liquidator-balance (get-user-supply-balance tx-sender collateral-asset)))
                  (map-set user-supply-balances
                           { user: tx-sender, asset: collateral-asset }
                           { principal-balance: (+ (get principal-balance liquidator-balance) amount-to-seize), 
                             supply-index: (get supply-index liquidator-balance) }))
                
                (print (tuple 
                  (event "collateral-seized")
                  (borrower borrower)
                  (liquidator tx-sender)
                  (asset collateral-asset)
                  (amount amount-to-seize)
                ))
              
              ;; Update market state
              ;; Update market state
              (try! (contract-call? .interest-rate-model update-market-state 
                                   asset-principal 
                                   (to-int actual-repay-amount)
                                   (- (to-int actual-repay-amount))
                                   0))
              
              (ok actual-repay-amount)
            )
          )
        )
      )
    )
  )
)

;; === HELPER FUNCTIONS ===
(define-private (is-asset-supported (asset-principal principal))
  (default-to false (get is-supported (map-get? supported-assets { asset: asset-principal }))))

(define-private (max (a uint) (b uint))
  (if (>= a b) a b))

(define-private (get-user-supply-balance (user principal) (asset principal))
  (default-to 
    { principal-balance: u0, supply-index: u1000000000000000 } 
    (map-get? user-supply-balances { user: user, asset: asset })))

;; Get a user's borrow balance for a specific asset
(define-private (get-user-borrow-balance (user principal) (asset principal))
  (default-to 
    {
      principal-balance: u0,
      borrow-index: u1000000000000000000  ;; 1.0 in 18 decimals
    }
    (map-get? user-borrow-balances { user: user, asset: asset })))

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

;; === VIEW FUNCTIONS ===
(define-read-only (get-supply-balance (user principal) (asset <sip10>))
  (let ((asset-principal (contract-of asset))
        (balance (get-user-supply-balance user asset-principal)))
    (ok (unwrap! (contract-call? .interest-rate-model calculate-current-supply-balance 
                       asset-principal 
                       (get principal-balance balance)
                       (get supply-index balance)) u5006))))

(define-read-only (get-borrow-balance (user principal) (asset <sip10>))
  (let ((asset-principal (contract-of asset))
        (balance (get-user-borrow-balance user asset-principal)))
    (ok (unwrap! (contract-call? .interest-rate-model calculate-current-borrow-balance 
                       asset-principal 
                       (get principal-balance balance)
                       (get borrow-index balance)) u5006))))

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
          (let ((current-balance (get principal-balance balance))
                (asset-price (get-asset-price asset-principal))
                (value (/ (* current-balance asset-price) PRECISION)))
            { user: user, total-value: (+ (get total-value acc) value) })
          acc))
      acc)))

(define-read-only (get-health-factor (user principal))
  (let ((collateral-result (get-collateral-value user))
        (borrow-value (get-total-borrow-value user)))
    (if (is-eq borrow-value u0)
      (ok (* u1000 PRECISION)) ;; Very high health factor if no debt
      (ok (/ (* (get total-value collateral-result) PRECISION) borrow-value)))))

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
      error (err error))))

(define-private (get-collateral-asset (user principal))
  (let ((collateral-assets (filter is-collateral (map-keys user-collateral-status))))
    (if (is-none collateral-assets)
      (err u1005) ;; No collateral assets
      (unwrap! (get-asset-with-highest-value user (unwrap-panic collateral-assets)) u1005))))

(define-private (get-asset-with-highest-value (user principal) (assets (list principal)))
  (let ((asset-values (map get-asset-value assets)))
    (let ((max-value (fold max u0 asset-values))
          (max-asset (find max-value asset-values)))
      (if (is-none max-asset)
        (err u1005) ;; No assets with value
        (unwrap! max-asset u1005)))))

(define-private (get-asset-value (asset principal))
  (let ((balance (get-user-supply-balance tx-sender asset))
        (price (get-asset-price asset)))
    (/ (* (get principal-balance balance) price) PRECISION)))

(define-private (get-total-borrow-value (user principal))
  (get total-value (fold calculate-user-borrow-value 
        (var-get supported-assets-list)
        { user: user, total-value: u0 })))

(define-private (calculate-user-borrow-value (asset-principal principal) (acc { user: principal, total-value: uint }))
  (let ((user (get user acc))
        (balance (get-user-borrow-balance user asset-principal)))
    (if (> (get principal-balance balance) u0)
      (let ((current-balance (get principal-balance balance))
            (asset-price (get-asset-price asset-principal))
            (value (/ (* current-balance asset-price) PRECISION)))
        { user: user, total-value: (+ (get total-value acc) value) })
      acc)))

;; Removed duplicate check-account-liquidity function

(define-private (calculate-user-collateral-value (asset-principal principal) (acc { user: principal, total-value: uint }))
  (let ((user (get user acc))
        (is-collateral (default-to false (get is-collateral (map-get? user-collateral-status { user: user, asset: asset-principal })))))
    (if is-collateral
      (let ((balance (get-user-supply-balance user asset-principal)))
        (if (> (get principal-balance balance) u0)
          (let ((current-balance (get principal-balance balance))
                (asset-price (get-asset-price asset-principal))
                (value (/ (* current-balance asset-price) PRECISION)))
            { user: user, total-value: (+ (get total-value acc) value) })
          acc))
      acc)))))
