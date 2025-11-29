;; Liquidation Manager Contract
(use-trait liquidation-trait .risk-management.liquidation-trait)
(impl-trait .risk-management.liquidation-trait)
;; Lending system trait for underwater checks
(use-trait lending-system-trait .defi-primitives.pool-trait)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_POSITIONS_PER_BATCH u10)
;; Data variables
(define-data-var admin principal CONTRACT_OWNER)
(define-data-var liquidation-paused bool false)
(define-data-var liquidation-incentive-bps uint u200) ;; 2% default incentive
(define-data-var close-factor-bps uint u5000) ;; 50% default close factor

;; Contract references
(define-data-var lending-system (optional principal) none)

;; Whitelisted assets for liquidation
(define-map whitelisted-assets
  { asset: principal }
  { is-whitelisted: bool }
)

;; ==================== ADMIN FUNCTIONS ====================

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002)) ;; ERR_UNAUTHORIZED
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-lending-system (system principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002)) ;; ERR_UNAUTHORIZED
    (var-set lending-system (some system))
    (ok true)
  )
)

(define-public (set-liquidation-incentive (incentive-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002)) ;; ERR_UNAUTHORIZED
    (asserts! (<= incentive-bps u1000) (err u1003)) ;; Max 10% incentive
    (var-set liquidation-incentive-bps incentive-bps)
    (ok true)
  )
)

(define-public (set-close-factor (factor-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002)) ;; ERR_UNAUTHORIZED
    (asserts! (<= factor-bps u10000) (err u1003)) ;; Max 100%
    (var-set close-factor-bps factor-bps)
    (ok true)
  )
)

(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002)) ;; ERR_UNAUTHORIZED
    (var-set liquidation-paused paused)
    (ok true)
  )
)

(define-public (whitelist-asset
    (asset principal)
    (whitelisted bool)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002)) ;; ERR_UNAUTHORIZED
    (map-set whitelisted-assets { asset: asset } { is-whitelisted: whitelisted })
    (ok true)
  )
)

;; ==================== LIQUIDATION FUNCTIONS ====================

(define-public (can-liquidate-position
    (borrower principal)
    (debt-asset principal)
    (collateral-asset principal)
    (lending-system-ref <lending-system-trait>)
  )
  (let (
      (ls (unwrap! (var-get lending-system) (err u1008))) ;; ERR_ASSET_NOT_WHITELISTED
      (debt-whitelisted (default-to false
        (get is-whitelisted (map-get? whitelisted-assets { asset: debt-asset }))
      ))
      (collateral-whitelisted (default-to false
        (get is-whitelisted
          (map-get? whitelisted-assets { asset: collateral-asset })
        )))
    )
    ;; ERR_ASSET_NOT_WHITELISTED
    (asserts! debt-whitelisted (err u1008))
    ;; ERR_ASSET_NOT_WHITELISTED
    (asserts! collateral-whitelisted (err u1008))
    ;; ERR_ASSET_NOT_WHITELISTED

    ;; Delegate to lending system to check if position is underwater
    (match (contract-call? lending-system-ref
      is-position-underwater borrower debt-asset collateral-asset
    )
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
    (lending-system-ref <lending-system-trait>)
  )
  (let (
      (ls (unwrap! (var-get lending-system) (err u1008))) ;; ERR_ASSET_NOT_WHITELISTED
      (debt-whitelisted (default-to false
        (get is-whitelisted (map-get? whitelisted-assets { asset: debt-asset }))
      ))
      (collateral-whitelisted (default-to false
        (get is-whitelisted
          (map-get? whitelisted-assets { asset: collateral-asset })
        )))
    )
    ;; ERR_ASSET_NOT_WHITELISTED
    (asserts! (not (var-get liquidation-paused)) (err u1001))
    ;; ERR_LIQUIDATION_PAUSED
    (asserts! debt-whitelisted (err u1008))
    ;; ERR_ASSET_NOT_WHITELISTED
    (asserts! collateral-whitelisted (err u1008))
    ;; ERR_ASSET_NOT_WHITELISTED

    ;; Calculate liquidation amounts
    (match (calculate-liquidation-amounts borrower debt-asset collateral-asset
      debt-amount
      lending-system-ref
    )
      (ok amounts)
      (let ((collateral-to-seize (get collateral-to-seize amounts)))
        (asserts! (<= collateral-to-seize max-collateral-amount) (err u1005))
        ;; ERR_SLIPPAGE_TOO_HIGH

        ;; Execute liquidation through lending system
        (match (contract-call? lending-system-ref liquidate borrower debt-asset
          collateral-asset debt-amount collateral-to-seize
        )
          (ok result) (ok result)
          error (err error)
        )
      )
      error (err error)
    )
  )
)

;; (define-public (liquidate-multiple-positions (positions (list 10
;;   {
;;   borrower: principal,
;;   debt-asset: principal,
;;   collateral-asset: principal,
;;   debt-amount: uint,
;;   max-collateral-amount: uint
;;   })))
;;     (ok true) ;; Placeholder
;; )

(define-private (liquidate-single-position
    (position {
      borrower: principal,
      debt-asset: principal,
      collateral-asset: principal,
      debt-amount: uint,
    })
    (acc {
      success-count: uint,
      total-debt-repaid: uint,
      total-collateral-seized: uint,
    })
  )
  acc
)

(define-public (calculate-liquidation-amounts
    (borrower principal)
    (debt-asset principal)
    (collateral-asset principal)
    (debt-amount uint)
    (lending-system-ref <lending-system-trait>)
  )
  (let (
      (lsys (unwrap! (var-get lending-system) (err u1008))) ;; ERR_ASSET_NOT_WHITELISTED
    )
    (asserts! (is-eq (contract-of lending-system-ref) lsys) (err u1002))
    (match (contract-call? lending-system-ref get-liquidation-amounts borrower debt-asset
      collateral-asset debt-amount
    )
      (ok amounts)
      (ok {
        max-debt-repayable: (get max-debt-repayable amounts),
        collateral-to-seize: (get collateral-to-seize amounts),
        liquidation-incentive: (get liquidation-incentive amounts),
        debt-value: (get debt-value amounts),
        collateral-value: (get collateral-value amounts),
      })
      error
      error
    )
  )
)

(define-public (emergency-liquidate
    (borrower principal)
    (debt-asset principal)
    (collateral-asset principal)
    (debt-amount uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1002)) ;; ERR_UNAUTHORIZED
    (let (
        (ls (unwrap! (var-get lending-system) (err u1008))) ;; ERR_ASSET_NOT_WHITELISTED
      )
      (asserts! (is-eq (contract-of lending-system-ref) ls) (err u1002))
      (contract-call? lending-system-ref emergency-liquidate borrower debt-asset
        collateral-asset
      )
    )
  )
)

;; Implements liquidation functionality for the lending protocol
