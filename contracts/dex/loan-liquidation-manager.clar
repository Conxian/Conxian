;; loan-liquidation-manager.clar
;; Advanced liquidation system for undercollateralized positions
;; Supports multiple liquidation strategies and automated liquidations

(use-trait std-constants traits.standard-constants-trait)
(use-trait liquidation liquidation-trait)
(impl-trait liquidation-trait)

;; Oracle contract
(define-constant ORACLE_CONTRACT ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.oracle)

;; Contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Data variables
(define-data-var admin principal CONTRACT_OWNER)
(define-data-var liquidation-paused bool false)
(define-data-var keeper-incentive-bps uint u100) ;; 1% keeper incentive
(define-data-var lending-system (optional principal) none)

;; Set the lending system contract (admin only)
(define-public (set-lending-system-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002)) ;; ERR_UNAUTHORIZED
    (var-set lending-system (some contract))
    (ok true)))

;; Liquidation parameters per asset
(define-map liquidation-params
  { asset: principal }
  {
    liquidation-threshold: uint,    ;; Collateral ratio below which liquidation is allowed (in bps, e.g. 8333 for 83.33%)
    liquidation-incentive: uint,    ;; Bonus percentage for liquidators (in bps, e.g. 200 for 2%)
    close-factor: uint,             ;; Maximum portion that can be liquidated (in bps, e.g. 5000 for 50%)
    min-liquidation-amount: uint,   ;; Minimum amount to liquidate (in assets base units)
    max-liquidation-amount: uint    ;; Maximum amount in single tx (in assets base units)
  })

;; Default liquidation parameters (in basis points)
(define-constant DEFAULT_LIQUIDATION_THRESHOLD u8333)     ;; 83.33%
(define-constant DEFAULT_LIQUIDATION_INCENTIVE u200)      ;; 2%
(define-constant DEFAULT_CLOSE_FACTOR u5000)              ;; 50%
(define-constant DEFAULT_MIN_LIQUIDATION_AMOUNT u1000)    ;; 1000 base units
(define-constant DEFAULT_MAX_LIQUIDATION_AMOUNT u1000000000000000000)  ;; 1e18 base units

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

;; Keeper whitelist
(define-map keepers { keeper: principal } { is-keeper: bool })

;; Initialize liquidation parameters for an asset
(define-public (init-liquidation-params 
  (asset principal)
  (liquidation-threshold uint)
  (liquidation-incentive uint)
  (close-factor uint)
  (min-amount uint)
  (max-amount uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002)) ;; ERR_UNAUTHORIZED
    (asserts! (<= liquidation-threshold u10000) (err u1003))  ;; ERR_INVALID_AMOUNT
    (asserts! (<= liquidation-incentive u1000) (err u1003))   ;; Max 10% incentive
    (asserts! (<= close-factor u10000) (err u1003))          ;; Max 100%
    (asserts! (<= min-amount max-amount) (err u1003))        ;; Min <= Max
    
    (map-set liquidation-params 
      { asset: asset }
      {
        liquidation-threshold: (default-to DEFAULT_LIQUIDATION_THRESHOLD liquidation-threshold),
        liquidation-incentive: (default-to DEFAULT_LIQUIDATION_INCENTIVE liquidation-incentive),
        close-factor: (default-to DEFAULT_CLOSE_FACTOR close-factor),
        min-liquidation-amount: (default-to DEFAULT_MIN_LIQUIDATION_AMOUNT min-amount),
        max-liquidation-amount: (default-to DEFAULT_MAX_LIQUIDATION_AMOUNT max-amount)
      }
    )
    (ok true)
  )
)

;; Get liquidation parameters with defaults
(define-read-only (get-liquidation-params (asset principal))
  (let ((params (map-get? liquidation-params { asset: asset })))
    (if (is-none params)
      {
        liquidation-threshold: DEFAULT_LIQUIDATION_THRESHOLD,
        liquidation-incentive: DEFAULT_LIQUIDATION_INCENTIVE,
        close-factor: DEFAULT_CLOSE_FACTOR,
        min-liquidation-amount: DEFAULT_MIN_LIQUIDATION_AMOUNT,
        max-liquidation-amount: DEFAULT_MAX_LIQUIDATION_AMOUNT
      }
      (unwrap! params (err u1008))  ;; ERR_ASSET_NOT_WHITELISTED
    )
  )
)

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
;; Helper function to check if a position is liquidatable
(define-private (verify-liquidatable-position 
  (borrower principal)
  (debt-asset principal)
  (collateral-asset principal))
  (let ((params (unwrap! (map-get? liquidation-params { asset: debt-asset }) 
                        (err u1008)))  ;; ERR_ASSET_NOT_WHITELISTED
        (lending-system (unwrap! (var-get lending-system) (err u1008)))
    (contract-call? lending-system is-position-liquidatable borrower debt-asset collateral-asset)
  )
)

;; Main liquidation function
(define-public (liquidate-position 
  (borrower principal)
  (debt-asset <sip10>)
  (collateral-asset <sip10>)
  (debt-amount uint)
  (max-collateral-amount uint)
)
  (let (
      (liquidator tx-sender)
      (debt-asset-principal (contract-of debt-asset))
      (collateral-asset-principal (contract-of collateral-asset))
      (lending-system (unwrap! (var-get lending-system) (err u1008)))  ;; ERR_ASSET_NOT_WHITELISTED
      
      ;; Get position data
      (position (unwrap! (contract-call? lending-system get-position borrower debt-asset collateral-asset) 
                (err u1009)))  ;; ERR_INSUFFICIENT_COLLATERAL
      
      ;; Get liquidation parameters with defaults
      (params (get-liquidation-params debt-asset-principal))
      
      ;; Check if liquidation is allowed
      (is-liquidatable (unwrap! (contract-call? lending-system 
                                is-position-liquidatable borrower debt-asset collateral-asset) 
                      (err u1004)))  ;; ERR_POSITION_NOT_UNDERWATER
      
      ;; Calculate liquidation amounts
      (liquidation-amounts (calculate-liquidation-amounts borrower debt-asset collateral-asset debt-amount))
      
      (debt-to-repay (get debt-to-repay liquidation-amounts))
      (collateral-to-seize (get collateral-to-seize liquidation-amounts))
      
      ;; Check slippage and min/max amounts
      (slippage-ok? (<= collateral-to-seize max-collateral-amount))
      (amount-valid? (and 
                      (>= debt-to-repay (get min-liquidation-amount params))
                      (<= debt-to-repay (get max-liquidation-amount params))))
    )
    
    (asserts! (not (var-get liquidation-paused)) (err u1001))  ;; ERR_LIQUIDATION_PAUSED
    (asserts! is-liquidatable (err u1004))  ;; ERR_POSITION_NOT_UNDERWATER
    (asserts! slippage-ok? (err u1005))    ;; ERR_SLIPPAGE_TOO_HIGH
    (asserts! amount-valid? (err u1003))   ;; ERR_INVALID_AMOUNT
    
    ;; Execute liquidation through lending system
    (match (contract-call? lending-system 
            execute-liquidation 
            borrower 
            liquidator 
            debt-asset-principal 
            collateral-asset-principal 
            debt-to-repay 
            collateral-to-seize)
      (ok result) 
        (begin
          ;; Emit liquidation event
          (print (tuple 
            (event "liquidation-executed")
            (borrower borrower)
            (liquidator liquidator)
            (debt-asset debt-asset-principal)
            (collateral-asset collateral-asset-principal)
            (debt-repaid debt-to-repay)
            (collateral-seized collateral-to-seize)
            (incentive (get liquidation-incentive params))
          ))
          
          ;; Update statistics
          (unwrap! (update-liquidation-stats debt-to-repay collateral-to-seize) (err u1000))
          
          (ok result)
        )
      error error
    )
  )
)

;; Update liquidation stats
(define-private (update-liquidation-stats 
  (debt-repaid uint) 
  (collateral-seized uint)
)
  (begin
    (var-set total-liquidations (+ (var-get total-liquidations) u1))
    (var-set total-debt-liquidated (+ (var-get total-debt-liquidated) debt-repaid))
    (var-set total-collateral-seized (+ (var-get total-collateral-seized) collateral-seized))
    (ok true)
  )
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
    (ok (get success-count result)))
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
  (let ((lending-system ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.comprehensive-lending-system))
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
  (let (
      (debt-asset-principal (contract-of debt-asset))
      (collateral-asset-principal (contract-of collateral-asset))
      (lending-system (unwrap! (var-get lending-system) (err u1008)))  ;; ERR_ASSET_NOT_WHITELISTED
      
      ;; Get position data
      (position (unwrap! (contract-call? lending-system get-position borrower debt-asset collateral-asset) 
                (err u1009)))  ;; ERR_INSUFFICIENT_COLLATERAL
      
      ;; Get liquidation parameters with defaults
      (params (get-liquidation-params debt-asset-principal))
      
      ;; Get asset prices from oracle
      (debt-price (unwrap! (contract-call? ORACLE_CONTRACT get-price debt-asset-principal none) 
                  (err u4000)))  ;; ERR_PRICE_STALE
      (collateral-price (unwrap! (contract-call? ORACLE_CONTRACT get-price collateral-asset-principal none) 
                        (err u4000)))  ;; ERR_PRICE_STALE
      
      ;; Calculate maximum debt that can be liquidated (close factor)
      (max-debt-to-liquidate (/
        (* (get total-borrowed position) (get close-factor params))
        u10000  ;; 100% in basis points
      ))
      
      ;; Calculate actual debt to be repaid (min of requested and max allowed)
      (debt-to-repay (if (> debt-amount max-debt-to-liquidate) 
                        max-debt-to-liquidate 
                        debt-amount))
      
      ;; Calculate collateral to seize based on debt value and liquidation incentive
      (debt-value (* debt-to-repay debt-price))
      (liquidation-incentive (/ (* debt-value (get liquidation-incentive params)) u10000))  ;; Convert from bps
      (total-collateral-value (+ debt-value liquidation-incentive))
      (collateral-to-seize (/ total-collateral-value collateral-price))
    )
    
    ;; Return the calculated amounts
    (ok {
      debt-to-repay: debt-to-repay,
      collateral-to-seize: collateral-to-seize,
      liquidation-incentive: (get liquidation-incentive params),
      debt-value: debt-value,
      collateral-value: total-collateral-value
    })
  )
)
    
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
  (let (
      (liquidator tx-sender)
      (debt-asset-principal (contract-of debt-asset))
      (collateral-asset-principal (contract-of collateral-asset))
      (lending-system (unwrap! (var-get lending-system) (err u1008)))  ;; ERR_ASSET_NOT_WHITELISTED
    )
    
    ;; Only admin can call emergency liquidate
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002))  ;; ERR_UNAUTHORIZED
    
    ;; Get full position data
    (let (
        (position (unwrap! (contract-call? lending-system get-position borrower debt-asset collateral-asset) 
                  (err u1009)))  ;; ERR_INSUFFICIENT_COLLATERAL
        
        (debt-amount (get total-borrowed position))
        
        ;; Calculate liquidation amounts with 100% close factor
        (liquidation-amounts (calculate-liquidation-amounts 
                              borrower 
                              debt-asset 
                              collateral-asset 
                              debt-amount))
        
        (debt-to-repay (get debt-to-repay liquidation-amounts))
        (collateral-to-seize (get collateral-to-seize liquidation-amounts))
      )
      
      ;; Execute liquidation through lending system
      (match (contract-call? lending-system 
              execute-liquidation 
              borrower 
              liquidator 
              debt-asset-principal 
              collateral-asset-principal 
              debt-to-repay 
              collateral-to-seize)
        (ok result) 
          (begin
            ;; Emit emergency liquidation event
            (print (tuple 
              (event "emergency-liquidation-executed")
              (admin tx-sender)
              (borrower borrower)
              (debt-asset debt-asset-principal)
              (collateral-asset collateral-asset-principal)
              (debt-repaid debt-to-repay)
              (collateral-seized collateral-to-seize)
            ))
            (ok result)
          )
        error error
      )
    )
  )
)

(define-public (set-auto-liquidation-enabled (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002))  ;; ERR_UNAUTHORIZED
    (var-set auto-liquidation-enabled enabled)
    (ok true)



