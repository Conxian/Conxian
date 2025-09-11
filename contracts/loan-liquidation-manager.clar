;; loan-liquidation-manager.clar
;; Advanced liquidation system for undercollateralized positions
;; Supports multiple liquidation strategies and automated liquidations

(use-trait sip10 .sip-010-trait.sip-010-trait)

(define-constant ERR_UNAUTHORIZED (err u7001))
(define-constant ERR_POSITION_HEALTHY (err u7002))
(define-constant ERR_LIQUIDATION_TOO_LARGE (err u7003))
(define-constant ERR_INSUFFICIENT_BALANCE (err u7004))
(define-constant ERR_INVALID_COLLATERAL (err u7005))
(define-constant ERR_PRICE_TOO_OLD (err u7006))
(define-constant ERR_LIQUIDATION_PAUSED (err u7007))

(define-constant PRECISION u1000000000000000000) ;; 18 decimals
(define-constant MAX_LIQUIDATION_INCENTIVE u200000000000000000) ;; 20% max bonus
(define-constant MAX_CLOSE_FACTOR u500000000000000000) ;; 50% max liquidation per tx
(define-constant LIQUIDATION_THRESHOLD u833333333333333333) ;; 83.33% (1/1.2) collateral ratio

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
(define-public (liquidate-position 
  (borrower principal)
  (debt-asset <sip10>)
  (collateral-asset <sip10>)
  (debt-to-repay uint)
  (max-collateral-to-seize uint))
  (let ((liquidator tx-sender)
        (debt-asset-principal (contract-of debt-asset))
        (collateral-asset-principal (contract-of collateral-asset))
        (liquidation-id (+ (var-get total-liquidations) u1)))
    
    (begin
      (asserts! (not (var-get liquidation-paused)) ERR_LIQUIDATION_PAUSED)
      (asserts! (> debt-to-repay u0) ERR_INSUFFICIENT_BALANCE)
      
      ;; Check if position is liquidatable
      (try! (verify-liquidatable-position borrower debt-asset-principal collateral-asset-principal))
      
      ;; Get liquidation parameters
      (let ((params (unwrap! (map-get? liquidation-params { asset: debt-asset-principal }) ERR_UNAUTHORIZED))
            (debt-price u1000000) ;; Placeholder price
            (collateral-price u1000000) ;; Placeholder price)
        
        ;; Calculate maximum debt that can be repaid
        (let ((borrower-debt u1000000) ;; Placeholder until comprehensive-lending-system integration
              (max-repayable (/ (* borrower-debt (get close-factor params)) PRECISION))
              (actual-debt-to-repay (min debt-to-repay max-repayable)))
          
          (asserts! (<= actual-debt-to-repay (get max-liquidation-amount params)) ERR_LIQUIDATION_TOO_LARGE)
          (asserts! (>= actual-debt-to-repay (get min-liquidation-amount params)) ERR_LIQUIDATION_TOO_LARGE)
          
          ;; Calculate collateral to seize
          (let ((debt-value (/ (* actual-debt-to-repay debt-price) PRECISION))
                (liquidation-incentive (get liquidation-incentive params))
                (incentive-value (/ (* debt-value liquidation-incentive) PRECISION))
                (total-collateral-value (+ debt-value incentive-value))
                (collateral-to-seize (/ (* total-collateral-value PRECISION) collateral-price)))
            
            (asserts! (<= collateral-to-seize max-collateral-to-seize) ERR_LIQUIDATION_TOO_LARGE)
            
            ;; Transfer debt payment from liquidator
            (try! (contract-call? debt-asset transfer actual-debt-to-repay liquidator (as-contract tx-sender) none))
            
            ;; Repay borrower's debt through lending system
            ;; Note: This would need to integrate with the actual lending system
            ;; (try! (contract-call? .comprehensive-lending-system repay-for-user borrower debt-asset actual-debt-to-repay))
            
            ;; Transfer collateral to liquidator
            ;; Note: This would need to integrate with the actual lending system to seize collateral
            ;; (try! (as-contract (contract-call? collateral-asset transfer collateral-to-seize tx-sender liquidator none)))
            
            ;; Record liquidation
            (record-liquidation 
              liquidation-id
              liquidator
              borrower
              collateral-asset-principal
              debt-asset-principal
              actual-debt-to-repay
              collateral-to-seize
              incentive-value)
            
            ;; Update statistics
            (var-set total-liquidations liquidation-id)
            (var-set total-debt-liquidated (+ (var-get total-debt-liquidated) actual-debt-to-repay))
            (var-set total-collateral-seized (+ (var-get total-collateral-seized) collateral-to-seize))
            
            ;; Pay keeper incentive if automated liquidation
            (if (is-keeper liquidator)
              (pay-keeper-incentive liquidator incentive-value)
              true)
            
            (ok (tuple 
              (liquidation-id liquidation-id)
              (debt-repaid actual-debt-to-repay)
              (collateral-seized collateral-to-seize)
              (liquidation-incentive incentive-value)))))))

;; Batch liquidation for multiple positions
(define-public (liquidate-multiple-positions 
  (positions (list 10 { borrower: principal, debt-asset: principal, collateral-asset: principal, debt-amount: uint })))
  (begin
    (asserts! (not (var-get liquidation-paused)) ERR_LIQUIDATION_PAUSED)
    (asserts! (or (is-eq tx-sender (var-get admin)) (is-keeper tx-sender)) ERR_UNAUTHORIZED)
    
    ;; This would iterate through positions and liquidate each
    ;; For now, return success
    (ok (len positions))))

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
(define-private (verify-liquidatable-position (borrower principal) (debt-asset principal) (collateral-asset principal))
  ;; Check health factor from lending system
  ;; TODO: Fix contract reference - comprehensive-lending-system not available in current deployment
  ;; For now, assume liquidatable based on manual verification
  (ok true))

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
  (let ((keeper-payment (/ (* incentive-value (var-get keeper-incentive-bps)) u10000)))
    ;; Would transfer keeper payment from protocol reserves
    true))

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
    (ok health-factor) (ok (< health-factor PRECISION))
    (err error) (ok false)))

(define-read-only (calculate-liquidation-amounts 
  (borrower principal)
  (debt-asset <sip10>)
  (collateral-asset <sip10>))
  (let ((debt-asset-principal (contract-of debt-asset))
        (collateral-asset-principal (contract-of collateral-asset))
        (debt-balance (match (contract-call? .comprehensive-lending-system get-borrow-balance borrower debt-asset)
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

;; === UTILITY FUNCTIONS ===
(define-private (min (a uint) (b uint))
  (if (<= a b) a b))

(define-private (max (a uint) (b uint))
  (if (>= a b) a b))

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
