;; liquidation-manager.clar
;; Centralized liquidation manager for the Conxian protocol

(use-trait standard-constants .traits.standard-constants-trait.standard-constants-trait)
(use-trait liquidation-interface .liquidation-trait.liquidation-trait)
(impl-trait .liquidation-trait.liquidation-trait)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_POSITIONS_PER_BATCH u10)

;; Data variables
(define-data-var admin principal CONTRACT_OWNER)
(define-data-var liquidation-paused bool false)
(define-data-var liquidation-incentive-bps u200)  ;; 2% default incentive
(define-data-var close-factor-bps u5000)          ;; 50% default close factor

;; Contract references
(define-data-var lending-system (optional principal) none)

;; Whitelisted assets for liquidation
(define-map whitelisted-assets { asset: principal } { is-whitelisted: bool })

;; ==================== ADMIN FUNCTIONS ====================

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002))  ;; ERR_UNAUTHORIZED
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-lending-system (system principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002))  ;; ERR_UNAUTHORIZED
    (var-set lending-system (some system))
    (ok true)
  )
)

(define-public (set-liquidation-incentive (incentive-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002))  ;; ERR_UNAUTHORIZED
    (asserts! (<= incentive-bps u1000) (err u1003))  ;; Max 10% incentive
    (var-set liquidation-incentive-bps incentive-bps)
    (ok true)
  )
)

(define-public (set-close-factor (factor-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002))  ;; ERR_UNAUTHORIZED
    (asserts! (<= factor-bps u10000) (err u1003))  ;; Max 100%
    (var-set close-factor-bps factor-bps)
    (ok true)
  )
)

(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002))  ;; ERR_UNAUTHORIZED
    (var-set liquidation-paused paused)
    (ok true)
  )
)

(define-public (whitelist-asset (asset principal) (whitelisted bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002))  ;; ERR_UNAUTHORIZED
    (map-set whitelisted-assets { asset: asset } { is-whitelisted: whitelisted })
    (ok true)
  )
)

;; ==================== LIQUIDATION FUNCTIONS ====================

(define-read-only (can-liquidate-position 
  (borrower principal) 
  (debt-asset principal) 
  (collateral-asset principal)
)
  (let (
      (lending-system (unwrap! (var-get lending-system) (err u1008)))  ;; ERR_ASSET_NOT_WHITELISTED
      (debt-whitelisted (default-to false (get is-whitelisted (map-get? whitelisted-assets { asset: debt-asset }))))
      (collateral-whitelisted (default-to false (get is-whitelisted (map-get? whitelisted-assets { asset: collateral-asset }))))
    )
    (asserts! debt-whitelisted (err u1008))  ;; ERR_ASSET_NOT_WHITELISTED
    (asserts! collateral-whitelisted (err u1008))  ;; ERR_ASSET_NOT_WHITELISTED
    
    ;; Delegate to lending system to check if position is underwater
    (match (contract-call? lending-system is-position-underwater borrower debt-asset collateral-asset)
      result (ok result)
      error error
    )
  )
)

(define-public (liquidate-position
  (borrower principal)
  (debt-asset principal)
  (collateral-asset principal)
  (debt-amount uint)
  (max-collateral-amount uint)
)
  (let (
      (lending-system (unwrap! (var-get lending-system) (err u1008)))  ;; ERR_ASSET_NOT_WHITELISTED
      (debt-whitelisted (default-to false (get is-whitelisted (map-get? whitelisted-assets { asset: debt-asset }))))
      (collateral-whitelisted (default-to false (get is-whitelisted (map-get? whitelisted-assets { asset: collateral-asset }))))
    )
    (asserts! (not (var-get liquidation-paused)) (err u1001))  ;; ERR_LIQUIDATION_PAUSED
    (asserts! debt-whitelisted (err u1008))  ;; ERR_ASSET_NOT_WHITELISTED
    (asserts! collateral-whitelisted (err u1008))  ;; ERR_ASSET_NOT_WHITELISTED
    
    ;; Calculate liquidation amounts
    (match (calculate-liquidation-amounts borrower debt-asset collateral-asset debt-amount)
      (ok amounts)
        (let (
            (collateral-to-seize (get collateral-to-seize amounts))
          )
          (asserts! (<= collateral-to-seize max-collateral-amount) (err u1005))  ;; ERR_SLIPPAGE_TOO_HIGH
          
          ;; Execute liquidation through lending system
          (match (contract-call? lending-system liquidate borrower debt-asset collateral-asset debt-amount collateral-to-seize)
            (ok result) (ok result)
            error error
          )
        )
      error error
    )
  )
)

(define-public (liquidate-multiple-positions
  (positions (list 10 (tuple 
    (borrower principal) 
    (debt-asset principal) 
    (collateral-asset principal) 
    (debt-amount uint)
  )))
)
  (let (
      (lending-system (unwrap! (var-get lending-system) (err u1008)))  ;; ERR_ASSET_NOT_WHITELISTED
      (positions-count (len positions))
    )
    (asserts! (not (var-get liquidation-paused)) (err u1001))  ;; ERR_LIQUIDATION_PAUSED
    (asserts! (<= positions-count MAX_POSITIONS_PER_BATCH) (err u1007))  ;; ERR_MAX_POSITIONS_EXCEEDED
    
    (fold liquidate-single-position 
      positions 
      { success-count: u0, total-debt-repaid: u0, total-collateral-seized: u0 }
    )
  )
)

(define-private (liquidate-single-position
  (position (tuple (borrower principal) (debt-asset principal) (collateral-asset principal) (debt-amount uint)))
  (acc (tuple (success-count uint) (total-debt-repaid uint) (total-collateral-seized uint)))
)
  (let (
      (borrower (get borrower position))
      (debt-asset (get debt-asset position))
      (collateral-asset (get collateral-asset position))
      (debt-amount (get debt-amount position))
    )
    (match (liquidate-position borrower debt-asset collateral-asset debt-amount u115792089237316195423570985008687907853269984665640564039457584007913129639935)  ;; Max uint256
      (ok result)
        (merge acc {
          success-count: (+ (get success-count acc) u1),
          total-debt-repaid: (+ (get total-debt-repaid acc) (get debt-repaid result)),
          total-collateral-seized: (+ (get total-collateral-seized acc) (get collateral-seized result))
        })
      (err error) acc  ;; Skip failed liquidations but continue with others
    )
  )
)

(define-read-only (calculate-liquidation-amounts
  (borrower principal)
  (debt-asset principal)
  (collateral-asset principal)
  (debt-amount uint)
)
  (let (
      (lending-system (unwrap! (var-get lending-system) (err u1008)))  ;; ERR_ASSET_NOT_WHITELISTED
    )
    (match (contract-call? lending-system get-liquidation-amounts borrower debt-asset collateral-asset debt-amount)
      (ok amounts) 
        (ok {
          max-debt-repayable: (get max-debt-repayable amounts),
          collateral-to-seize: (get collateral-to-seize amounts),
          liquidation-incentive: (get liquidation-incentive amounts),
          debt-value: (get debt-value amounts),
          collateral-value: (get collateral-value amounts)
        })
      error error
    )
  )
)

(define-public (emergency-liquidate
  (borrower principal)
  (debt-asset principal)
  (collateral-asset principal)
)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002))  ;; ERR_UNAUTHORIZED
    (let (
        (lending-system (unwrap! (var-get lending-system) (err u1008)))  ;; ERR_ASSET_NOT_WHITELISTED
      )
      (contract-call? lending-system emergency-liquidate borrower debt-asset collateral-asset)
    )
  )
)
