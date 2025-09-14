;; loan-liquidation-manager.clar
;; Advanced liquidation system for undercollateralized positions
;; Supports multiple liquidation strategies and automated liquidations

;; Use canonical liquidation trait from traits/ and implement
(use-trait liquidation-trait .liquidation-trait)
(impl-trait liquidation-trait)

;; Oracle contract (will be set by admin)
(define-data-var oracle-contract (optional principal) none)

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
    (ok true)
  )
)

;; Liquidation parameters per asset
(define-map liquidation-params
  { asset: principal }
  {
    liquidation-threshold: uint,    ;; Collateral ratio below which liquidation is allowed (in bps, e.g. 8333 for 83.33%)
    liquidation-incentive: uint,    ;; Bonus percentage for liquidators (in bps, e.g. 200 for 2%)
    close-factor: uint,             ;; Maximum portion that can be liquidated (in bps, e.g. 5000 for 50%)
    min-liquidation-amount: uint,   ;; Minimum amount to liquidate (in assets base units)
    max-liquidation-amount: uint    ;; Maximum amount in single tx (in assets base units)
  }
)

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
  }
)

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
(define-public (init-liquidation-params (asset principal) (liquidation-threshold uint) (liquidation-incentive uint) (close-factor uint) (min-amount uint) (max-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002)) ;; ERR_UNAUTHORIZED
    (asserts! (<= liquidation-threshold u10000) (err u1003))  ;; ERR_INVALID_AMOUNT
    (asserts! (<= liquidation-incentive u1000) (err u1003))   ;; Max 10% incentive
    (asserts! (<= close-factor u10000) (err u1003))           ;; Max 100%
    (asserts! (<= min-amount max-amount) (err u1003))        ;; Min <= Max
    (map-set liquidation-params
      { asset: asset }
      {
        liquidation-threshold: (default-to DEFAULT_LIQUIDATION_THRESHOLD liquidation-threshold),
        liquidation-incentive: (default-to DEFAULT_LIQUIDATION_INCENTIVE liquidation-incentive),
        close-factor: (default-to DEFAULT_CLOSE_FACTOR close-factor),
        min-liquidation-amount: (default-to DEFAULT_MIN_LIQUIDATION_AMOUNT min-amount),
        max-liquidation-amount: (default-to DEFAULT_MAX_LIQUIDATION_AMOUNT max-amount)
      })
    (ok true)))

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
    )))

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

(define-public (set-liquidation-params (asset principal) (threshold uint) (incentive uint) (close-factor uint) (min-amount uint) (max-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (<= threshold PRECISION) ERR_UNAUTHORIZED)
    (asserts! (<= incentive MAX_LIQUIDATION_INCENTIVE) ERR_UNAUTHORIZED)
    (asserts! (<= close-factor MAX_CLOSE_FACTOR) ERR_UNAUTHORIZED)
    (map-set liquidation-params { asset: asset } { liquidation-threshold: threshold, liquidation-incentive: incentive, close-factor: close-factor, min-liquidation-amount: min-amount, max-liquidation-amount: max-amount })
    (ok true)))

(define-public (set-asset-price (asset principal) (price uint) (max-age-blocks uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set asset-prices { asset: asset } { price: price, last-update-block: block-height, max-age-blocks: max-age-blocks })
    (ok true)))

(define-public (authorize-keeper (keeper principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set authorized-keepers keeper authorized)
    (ok true)))

;; === LIQUIDATION FUNCTIONS ===

;; Helper function to check if a position is liquidatable
(define-private (verify-liquidatable-position (borrower principal) (debt-asset principal) (collateral-asset principal))
  (let ((params (unwrap! (map-get? liquidation-params { asset: debt-asset }) (err u1008)))
        (lending-system (unwrap! (var-get lending-system) (err u1008))))
    (contract-call? lending-system is-position-liquidatable borrower debt-asset collateral-asset))

;; Main liquidation function
(define-public (liquidate-position (borrower principal) (debt-asset <sip10>) (collateral-asset <sip10>) (debt-amount uint) (max-collateral-amount uint))
  (let (
    (liquidator tx-sender)
    (debt-asset-principal (contract-of debt-asset))
    (collateral-asset-principal (contract-of collateral-asset))
    (lending-system (unwrap! (var-get lending-system) (err u1008)))
    (position (unwrap! (contract-call? lending-system get-position borrower debt-asset collateral-asset) (err u1009)))
    (params (get-liquidation-params debt-asset-principal))
    (is-liquidatable (unwrap! (contract-call? lending-system is-position-liquidatable borrower debt-asset collateral-asset) (err u1004)))
    (liquidation-amounts (calculate-liquidation-amounts borrower debt-asset collateral-asset debt-amount))
    (debt-to-repay (get debt-to-repay liquidation-amounts))
    (collateral-to-seize (get collateral-to-seize liquidation-amounts))
    (slippage-ok? (<= collateral-to-seize max-collateral-amount))
    (amount-valid? (and (>= debt-to-repay (get min-liquidation-amount params)) (<= debt-to-repay (get max-liquidation-amount params)))))

  (asserts! (not (var-get liquidation-paused)) (err u1001)) ;; ERR_LIQUIDATION_PAUSED
  (asserts! is-liquidatable (err u1004)) ;; ERR_POSITION_NOT_UNDERWATER
  (asserts! slippage-ok? (err u1005)) ;; ERR_SLIPPAGE_TOO_HIGH
  (asserts! amount-valid? (err u1003)) ;; ERR_INVALID_AMOUNT

  (match (contract-call? lending-system execute-liquidation borrower liquidator debt-asset-principal collateral-asset-principal debt-to-repay collateral-to-seize)
    (ok result)
    (begin
      (print (tuple (event "liquidation-executed") (borrower borrower) (liquidator liquidator) (debt-asset debt-asset-principal) (collateral-asset collateral-asset-principal) (debt-repaid debt-to-repay) (collateral-seized collateral-to-seize) (incentive (get liquidation-incentive params))))
      (unwrap! (update-liquidation-stats debt-to-repay collateral-to-seize) (err u1000))
      (ok result))
    error error))

;; Update liquidation stats
(define-private (update-liquidation-stats (debt-repaid uint) (collateral-seized uint))
  (begin
    (var-set total-liquidations (+ (var-get total-liquidations) u1))
    (var-set total-debt-liquidated (+ (var-get total-debt-liquidated) debt-repaid))
    (var-set total-collateral-seized (+ (var-get total-collateral-seized) collateral-seized))
    (ok true)))

;; Batch liquidation for multiple positions
(define-public (liquidate-multiple-positions (positions (list 10 (tuple (borrower principal) (debt-asset principal) (collateral-asset principal) (debt-amount uint)))))
  (begin
    (asserts! (not (var-get liquidation-paused)) ERR_LIQUIDATION_PAUSED)
    (asserts! (or (is-eq tx-sender (var-get admin)) (is-keeper tx-sender)) ERR_UNAUTHORIZED)
    (let ((result (fold (lambda (position acc)
                          (let ((borrower (get borrower position))
                                (debt-asset (get debt-asset position))
                                (collateral-asset (get collateral-asset position))
                                (debt-amount (get debt-amount position)))
                            (match (contract-call? (unwrap-panic (var-get lending-system)) liquidate borrower debt-asset collateral-asset debt-amount)
                              (ok _r) (merge acc { success-count: (+ (get success-count acc) u1) })
                              (err _e) (begin (print (tuple (event "liquidation-failed") (error _e))) acc))))
                        { success-count: u0 }
                        positions)))
      (ok (get success-count result))))

;; Automated liquidation by authorized keepers
(define-public (auto-liquidate (borrower principal) (debt-asset <sip10>) (collateral-asset <sip10>))
  (begin
    (asserts! (var-get auto-liquidation-enabled) ERR_UNAUTHORIZED)
    (asserts! (is-keeper tx-sender) ERR_UNAUTHORIZED)
    (let ((debt-asset-principal (contract-of debt-asset))
          (collateral-asset-principal (contract-of collateral-asset))
          (max-debt (calculate-max-liquidation-amount borrower debt-asset-principal)))
      (liquidate-position borrower debt-asset collateral-asset max-debt u0))))

;; === LIQUIDATION VERIFICATION ===

;; The canonical verification function is defined earlier in the file and
;; should be used. The duplicate implementation that referenced a hard-coded
;; principal was removed to avoid parse errors and duplicate definitions.

(define-private (calculate-max-liquidation-amount (borrower principal) (debt-asset-principal principal))
  ;; TODO: Replace placeholder with actual comprehensive-lending-system integration
  (let ((debt-balance u1000000)) ;; Placeholder
    (match (map-get? liquidation-params { asset: debt-asset-principal })
      (some params)
        (min (/ (* debt-balance (get close-factor params)) PRECISION) (get max-liquidation-amount params))
      none u0)))