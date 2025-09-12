;; loan-liquidation-manager.clar
;; Advanced liquidation system for undercollateralized positions
;; Supports multiple liquidation strategies and automated liquidations

(use-trait sip10 .sip-010-trait.sip-010-trait)

;; Oracle contract
(define-constant ORACLE_CONTRACT 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.oracle)

(define-private (min (a uint) (b uint))
  (if (<= a b) a b))

(define-private (max (a uint) (b uint))
  (if (>= a b) a b))

(define-constant ERR_UNAUTHORIZED (err u7001))
(define-constant ERR_POSITION_HEALTHY (err u7002))
(define-constant ERR_LIQUIDATION_TOO_LARGE (err u7003))
(define-constant ERR_INSUFFICIENT_BALANCE (err u7004))
(define-constant ERR_INVALID_COLLATERAL (err u7005))
(define-constant ERR_PRICE_TOO_OLD (err u7006))
(define-constant ERR_LIQUIDATION_PAUSED (err u7007))
(define-constant ERR_POSITION_NOT_FOUND (err u7008))
(define-constant ERR_ASSET_NOT_WHITELISTED (err u7009))
(define-constant ERR_POSITION_NOT_UNDERWATER (err u7010))

(define-constant PRECISION u1000000000000000000) ;; 18 decimals
(define-constant MAX_LIQUIDATION_INCENTIVE u200000000000000000) ;; 20% max bonus
(define-constant MAX_CLOSE_FACTOR u500000000000000000) ;; 50% max liquidation per tx
(define-constant LIQUIDATION_THRESHOLD u833333333333333333) ;; 83.33% (1/1.2)
(define-constant LENDING_SYSTEM_CONTRACT 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.comprehensive-lending-system)

;; Dynamic contract reference for lending system
(define-data-var lending-system (optional principal) (some LENDING_SYSTEM_CONTRACT))

;; Set the lending system contract (admin only)
(define-public (set-lending-system-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set lending-system (some contract))
    (ok true)))

;; Admin
(define-data-var admin principal tx-sender)
(define-data-var liquidation-paused bool false)
(define-data-var keeper-incentive-bps uint u100) ;; 1% keeper incentive

;; Liquidation parameters per asset
(define-map liquidation-params
  { asset: principal }
  {
    liquidation-threshold: uint,    ;; Collateral ratio below which liquidation is allowed
    liquidation-incentive: uint,    ;; Bonus percentage for liquidators
    close-factor: uint,             ;; Maximum portion that can be liquidated
    min-liquidation-amount: uint,   ;; Minimum amount to liquidate
    max-liquidation-amount: uint    ;; Maximum amount in single tx
  })

;; Liquidation history
(define-map liquidation-history
  uint ;; liquidation-id
  {
    liquidator: principal,
    borrower: principal,
    collateral-asset: principal,
    debt-asset: principal,
    debt-repaid: uint,
    collateral-seized: uint,
    liquidation-incentive: uint,
    block-height: uint,
    timestamp: uint
  })

;; Liquidation statistics
(define-data-var total-liquidations uint u0)
(define-data-var total-debt-liquidated uint u0)
(define-data-var total-collateral-seized uint u0)

;; Automated liquidation settings
(define-data-var auto-liquidation-enabled bool false)
(define-map authorized-keepers principal bool)

;; Price feed integration (simplified)
(define-map asset-prices
  { asset: principal }
  { price: uint, last-update-block: uint, max-age-blocks: uint })

;; === ADMIN FUNCTIONS ===
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)))

(define-public (set-liquidation-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set liquidation-paused paused)
    (ok true)))

(define-public (set-liquidation-params 
  (asset principal)
  (threshold uint)
  (incentive uint)
  (close-factor uint)
  (min-amount uint)
  (max-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (<= threshold PRECISION) ERR_UNAUTHORIZED)
    (asserts! (<= incentive MAX_LIQUIDATION_INCENTIVE) ERR_UNAUTHORIZED)
    (asserts! (<= close-factor MAX_CLOSE_FACTOR) ERR_UNAUTHORIZED)
    
    (map-set liquidation-params
      { asset: asset }
      {
        liquidation-threshold: threshold,
        liquidation-incentive: incentive,
        close-factor: close-factor,
        min-liquidation-amount: min-amount,
        max-liquidation-amount: max-amount
      })
    (ok true)))

(define-public (set-asset-price (asset principal) (price uint) (max-age-blocks uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set asset-prices
      { asset: asset }
      {
        price: price,
        last-update-block: block-height,
        max-age-blocks: max-age-blocks
      })
    (ok true)))

(define-public (authorize-keeper (keeper principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set authorized-keepers keeper authorized)
    (ok true)))

;; === LIQUIDATION FUNCTIONS ===
;; Main liquidation function
;; Helper function to check if a position is liquidatable
(define-private (verify-liquidatable-position 
  (borrower principal)
  (debt-asset principal)
  (collateral-asset principal))
  (let ((params (unwrap! (map-get? liquidation-params { asset: debt-asset }) 
                        ERR_UNAUTHORIZED))
        (lending-system (unwrap-panic (var-get lending-system))))
    (match (contract-call? lending-system get-health-factor borrower) result
      (ok health-factor) 
        (if (<= health-factor (get liquidation-threshold params))
          (ok true)
          (err ERR_POSITION_NOT_UNDERWATER))
      (err e) (err e))))

(define-public (liquidate-position 
  (borrower principal)
  (debt-asset <sip10>)
  (collateral-asset <sip10>)
  (debt-to-repay uint)
  (max-collateral-to-seize uint)
)
  (let (
      (liquidator tx-sender)
      (debt-asset-principal (contract-of debt-asset))
      (collateral-asset-principal (contract-of collateral-asset))
      (lending-system (unwrap-panic (var-get lending-system)))
      (liquidation-id (+ (var-get total-liquidations) u1))
    )
    (begin
      (asserts! (not (var-get liquidation-paused)) ERR_LIQUIDATION_PAUSED)
      (asserts! (> debt-to-repay u0) ERR_INSUFFICIENT_BALANCE)
      
      ;; Check if position is liquidatable
      (try! (verify-liquidatable-position borrower debt-asset-principal collateral-asset-principal))
      
      ;; Get liquidation parameters
      (let (
          (params (unwrap! (map-get? liquidation-params { asset: debt-asset-principal }) ERR_UNAUTHORIZED))
          (debt-price (get-asset-price-safe debt-asset-principal))
          (collateral-price (get-asset-price-safe collateral-asset-principal))
        )
        ;; Get borrower's debt from lending system
        (match (contract-call? lending-system get-borrow-balance borrower debt-asset)
          result (ok borrower-debt)
          err (err err)
        )
        (let (
            (max-repayable (/ (* borrower-debt (get close-factor params)) PRECISION))
            (actual-debt-to-repay (min debt-to-repay max-repayable))
          )
          (asserts! (<= actual-debt-to-repay (get max-liquidation-amount params)) ERR_LIQUIDATION_TOO_LARGE)
          (asserts! (>= actual-debt-to-repay (get min-liquidation-amount params)) ERR_LIQUIDATION_TOO_LARGE)
          
          ;; Calculate collateral to seize
          (let (
              (debt-value (/ (* actual-debt-to-repay debt-price) PRECISION))
              (liquidation-incentive (get liquidation-incentive params))
              (incentive-value (/ (* debt-value liquidation-incentive) PRECISION))
              (total-collateral-value (+ debt-value incentive-value))
              (collateral-to-seize (/ (* total-collateral-value PRECISION) collateral-price))
            )
            (asserts! (<= collateral-to-seize max-collateral-to-seize) ERR_LIQUIDATION_TOO_LARGE)
            
            (match (contract-call? debt-asset transfer actual-debt-to-repay liquidator (as-contract tx-sender) none)
              (ok transfer-ok)
              (match (contract-call? lending-system repay-for-user borrower debt-asset actual-debt-to-repay)
                (ok repay-ok)
                (match (contract-call? lending-system seize-collateral borrower liquidator collateral-asset collateral-to-seize)
                  (ok seize-ok)
                  (begin
                    ;; Update liquidation stats
                    (var-set total-liquidations (+ (var-get total-liquidations) u1))
                    (var-set total-debt-liquidated (+ (var-get total-debt-liquidated) actual-debt-to-repay))
                    (var-set total-collateral-seized (+ (var-get total-collateral-seized) collateral-to-seize))
                    
                    ;; Log the liquidation event
                    (print (tuple 
                      (event "liquidation-executed")
                      (liquidation-id liquidation-id)
                      (liquidator liquidator)
                      (borrower borrower)
                      (debt-asset debt-asset-principal)
                      (debt-repaid actual-debt-to-repay)
                      (collateral-seized collateral-to-seize)
                    ))
                    
                    (ok true)
                  )
                  (err e) (err e)
                )
                (err e) (err e)
              )
              (err e) (err e)
            )
          )
        )
      )
    )
  )
)

;; Batch liquidation for multiple positions
(define-public (liquidate-multiple-positions
  (positions (list 10 (tuple (borrower principal) (debt-asset principal) (collateral-asset principal) (debt-amount uint)))))
  (begin
    (asserts! (not (var-get liquidation-paused)) ERR_LIQUIDATION_PAUSED)
    (asserts! (or (is-eq tx-sender (var-get admin)) (is-keeper tx-sender)) ERR_UNAUTHORIZED)
    
    (let ((result (fold 
      (lambda (position acc)
        (let ((borrower (get borrower position))
              (debt-asset (get debt-asset position))
              (collateral-asset (get collateral-asset position))
              (debt-amount (get debt-amount position)))
          (match (contract-call? (unwrap-panic (var-get lending-system)) liquidate borrower debt-asset collateral-asset debt-amount)
            (ok result) (merge acc { success-count: (+ (get success-count acc) 1) })
            (err error) (begin 
                         (print (tuple (event "liquidation-failed") (error error))) 
                         acc
                       )
          ))
        )
      )
      { success-count: 0 }
      positions
    )))
    (ok (get success-count result))
  )
)
;; Automated liquidation by authorized keepers
(define-public (auto-liquidate 
  (borrower principal)
  (debt-asset <sip10>)
  (collateral-asset <sip10>))
  (begin
    (asserts! (var-get auto-liquidation-enabled) ERR_UNAUTHORIZED)
    (asserts! (is-keeper tx-sender) ERR_UNAUTHORIZED)
    
    ;; Get maximum safe liquidation amount
    (let ((debt-asset-principal (contract-of debt-asset))
          (collateral-asset-principal (contract-of collateral-asset))
          (max-debt (calculate-max-liquidation-amount borrower debt-asset-principal)))
      (liquidate-position borrower debt-asset collateral-asset max-debt u0))))

;; === LIQUIDATION VERIFICATION ===
(define-private (verify-liquidatable-position 
  (borrower principal) 
  (debt-asset principal) 
  (collateral-asset principal))
  (let ((lending-system 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.comprehensive-lending-system))
    (match (contract-call? lending-system get-health-factor borrower) result
      (ok health-factor) (ok (<= health-factor LIQUIDATION_THRESHOLD))
      (err e) (err e))))

(define-private (calculate-max-liquidation-amount (borrower principal) (debt-asset-principal principal))
  ;; TODO: Replace placeholder with actual comprehensive-lending-system integration
  (let ((debt-balance u1000000)) ;; Placeholder
    (match (map-get? liquidation-params { asset: debt-asset-principal })
      (some params)
        (min 
          (/ (* debt-balance (get close-factor params)) PRECISION)
          (get max-liquidation-amount params))
      none u0)))

;; === PRICE FEED HELPERS ===
(define-private (get-asset-price-safe (asset principal))
  (match (map-get? asset-prices { asset: asset })
    price-info
      (let ((price (get price price-info))
            (last-update (get last-update-block price-info))
            (max-age (get max-age-blocks price-info)))
        (asserts! (<= (- block-height last-update) max-age) ERR_PRICE_TOO_OLD)
        price)
    PRECISION)) ;; Default to $1 if no price set

;; === KEEPER FUNCTIONS ===
(define-private (is-keeper (user principal))
  (default-to false (map-get? authorized-keepers user)))

(define-private (pay-keeper-incentive (keeper principal) (incentive-value uint))
  (let ((keeper-payment (/ (* incentive-value (var-get keeper-incentive-bps)) u10000))
        (debt-token (unwrap-panic (var-get default-debt-token)))) ;; Get default debt token
    (match (as-contract (contract-call? debt-token transfer keeper-payment tx-sender keeper none))
      (ok true) (ok true)
      (err e) (begin 
        (print (tuple (event "keeper-payment-failed") (error e) (keeper keeper) (amount keeper-payment)))
        (err e)))))

;; === RECORD KEEPING ===
(define-private (record-liquidation 
  (liquidation-id uint)
  (liquidator principal)
  (borrower principal)
  (collateral-asset principal)
  (debt-asset principal)
  (debt-repaid uint)
  (collateral-seized uint)
  (incentive uint))
  (begin
    (map-set liquidation-history
      liquidation-id
      {
        liquidator: liquidator,
        borrower: borrower,
        collateral-asset: collateral-asset,
        debt-asset: debt-asset,
        debt-repaid: debt-repaid,
        collateral-seized: collateral-seized,
        liquidation-incentive: incentive,
        block-height: block-height,
        timestamp: (unwrap-panic (get-block-info? time block-height))
      })
    
    ;; Emit liquidation event
    (print (tuple 
      (event "liquidation")
      (liquidation-id liquidation-id)
      (liquidator liquidator)
      (borrower borrower)
      (debt-asset debt-asset)
      (collateral-asset collateral-asset)
      (debt-repaid debt-repaid)
      (collateral-seized collateral-seized)
      (incentive incentive)))))

;; === VIEW FUNCTIONS ===
(define-read-only (get-liquidation-params (asset principal))
  (map-get? liquidation-params { asset: asset }))

;; Safely get asset price with error handling
(define-read-only (get-asset-price (asset principal))
  (match (contract-call? ORACLE_CONTRACT get-price asset)
    (ok price) (ok price)
    (err error) (err ERR_PRICE_UNAVAILABLE)
  )
)

(define-read-only (get-liquidation-history (liquidation-id uint))
  (map-get? liquidation-history liquidation-id))

(define-read-only (get-liquidation-stats)
  (ok (tuple
    (total-liquidations (var-get total-liquidations))
    (total-debt-liquidated (var-get total-debt-liquidated))
    (total-collateral-seized (var-get total-collateral-seized))
    (auto-liquidation-enabled (var-get auto-liquidation-enabled))
    (liquidation-paused (var-get liquidation-paused)))))

(define-read-only (is-position-liquidatable (borrower principal))
  (match (contract-call? .comprehensive-lending-system get-health-factor borrower)
    health-factor (ok (< health-factor u1000000))  ;; PRECISION is 1e6
    error (ok false)))

(define-read-only (calculate-liquidation-amounts 
  (borrower principal)
  (debt-asset <sip10>)
  (collateral-asset <sip10>))
  (let ((debt-asset-principal (contract-of debt-asset))
        (collateral-asset-principal (contract-of collateral-asset))
        (debt-balance (match (contract-call? (unwrap-panic (var-get lending-system)) get-borrow-balance borrower debt-asset)
                          db db
                          err u0))
        (params (default-to { liquidation-threshold: LIQUIDATION_THRESHOLD,
                              liquidation-incentive: u0,
                              close-factor: MAX_CLOSE_FACTOR,
                              min-liquidation-amount: u0,
                              max-liquidation-amount: u0 }
                            (map-get? liquidation-params { asset: debt-asset-principal })))
        (max-repayable (/ (* debt-balance (get close-factor params)) PRECISION))
        (debt-price (get-asset-price-safe debt-asset-principal))
        (collateral-price (get-asset-price-safe collateral-asset-principal))
        (debt-value (/ (* max-repayable debt-price) PRECISION))
        (incentive-rate (get liquidation-incentive params))
        (incentive-value (/ (* debt-value incentive-rate) PRECISION))
        (total-collateral-value (+ debt-value incentive-value))
        (collateral-to-seize (/ (* total-collateral-value PRECISION) collateral-price)))
    
    (ok (tuple
      (max-debt-repayable max-repayable)
      (collateral-to-seize collateral-to-seize)
      (liquidation-incentive incentive-value)
      (debt-value debt-value)
      (collateral-value total-collateral-value)))))

;; === EMERGENCY FUNCTIONS ===
(define-public (emergency-liquidate 
  (borrower principal)
  (debt-asset <sip10>)
  (collateral-asset <sip10>))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    ;; Admin can liquidate any position in emergency
    (liquidate-position borrower debt-asset collateral-asset u1000000000000000000000 u1000000000000000000000))) ;; Large amounts

(define-public (set-auto-liquidation-enabled (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set auto-liquidation-enabled enabled)
    (ok true)))
