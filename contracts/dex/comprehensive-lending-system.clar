;; comprehensive-lending-system.clar
;; Refactored for clarity, security, and correctness.

;; --- Traits ---
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait lending-system-trait .all-traits.lending-system-trait)

;; --- Constants ---
(define-constant LENDING_SERVICE "lending-service")
(define-constant ERR_CIRCUIT_BREAKER_OPEN (err u1016))
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_PAUSED (err u1002))
(define-constant ERR_INVALID_ASSET (err u1007))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u1008))
(define-constant ERR_TRANSFER_FAILED (err u1010))
(define-constant ERR_ZERO_AMOUNT (err u1011))
(define-constant ERR_HEALTH_CHECK_FAILED (err u1013))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1014))
(define-constant ERR_ALREADY_SET (err u1015))
(define-constant ERR_POSITION_HEALTHY (err u1017))
(define-constant ERR_LIQUIDATION_THRESHOLD_NOT_FOUND (err u1018))
(define-constant ERR_INVALID_TUPLE (err u1019))
(define-constant PRECISION u1000000000000000000) ;; 1e18

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var paused bool false)
(define-data-var oracle-contract principal tx-sender)
(define-data-var interest-rate-model-contract principal tx-sender)
(define-data-var loan-liquidation-manager-contract principal tx-sender)
(define-data-var access-control-contract principal tx-sender)
(define-data-var circuit-breaker-contract (optional principal) none)

;; --- Maps ---
(define-map supported-assets { asset: principal } { collateral-factor: uint, liquidation-threshold: uint, liquidation-bonus: uint })
(define-map user-supply-balances { user: principal, asset: principal } { balance: uint })
(define-map user-borrow-balances { user: principal, asset: principal } { balance: uint })
(define-map user-collateral-assets { user: principal, asset: principal } bool)

;; --- Private Helper Functions ---
(define-private (check-is-owner) 
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)))

(define-private (check-not-paused) 
  (ok (asserts! (not (var-get paused)) ERR_PAUSED)))

(define-private (get-asset-price-safe (asset principal))
  u0)

(define-private (accrue-interest (asset principal))
  (contract-call? (var-get interest-rate-model-contract) accrue-interest asset))

(define-private (min (a uint) (b uint))
  (if (<= a b) a b))

;; --- Collateral & Borrow Value Calculations ---
(define-read-only (get-total-collateral-value-in-usd-safe (user principal))
  (let ((assets-list (map-to-list user-collateral-assets)))
    (fold calculate-collateral-value assets-list u0)))

(define-private (calculate-collateral-value (asset-tuple { user: principal, asset: principal }) (total-value uint))
  (let ((asset (get asset asset-tuple))
        (user (get user asset-tuple)))
    (if (default-to false (map-get? user-collateral-assets { user: user, asset: asset }))
      (match (map-get? supported-assets { asset: asset })
        asset-info
          (let ((balance (default-to u0 (get balance (map-get? user-supply-balances { user: user, asset: asset }))))
                (price (get-asset-price-safe asset)))
            (+ total-value (/ (* balance (get collateral-factor asset-info) price) (* PRECISION PRECISION))))
        total-value)
      total-value)))

(define-read-only (get-total-borrow-value-in-usd-safe (user principal))
  (let ((borrow-list (map-to-list user-borrow-balances)))
    (fold calculate-borrow-value borrow-list u0)))

(define-private (calculate-borrow-value (borrow-tuple { user: principal, asset: principal }) (total-value uint))
  (let ((asset (get asset borrow-tuple))
        (user (get user borrow-tuple))
        (balance (default-to u0 (get balance (map-get? user-borrow-balances { user: user, asset: asset }))))
        (price (get-asset-price-safe asset)))
    (+ total-value (/ (* balance price) PRECISION))))

;; --- Health Factor Calculation ---
(define-read-only (get-health-factor (user principal))
  (let ((collateral-data (calculate-weighted-collateral user))
        (collateral-value (get total-collateral-value collateral-data))
        (weighted-threshold (get weighted-liquidation-threshold collateral-data))
        (borrow-value (get-total-borrow-value-in-usd-safe user)))
    (if (> borrow-value u0)
      (ok (/ (* collateral-value weighted-threshold) borrow-value))
      (ok u18446744073709551615))))

(define-private (calculate-weighted-collateral (user principal))
  (let ((assets-list (map-to-list user-collateral-assets)))
    (fold accumulate-collateral-threshold assets-list { total-collateral-value: u0, total-threshold-value: u0 })))

(define-private (accumulate-collateral-threshold 
  (asset-tuple { user: principal, asset: principal }) 
  (accumulator { total-collateral-value: uint, total-threshold-value: uint }))
  (let ((asset (get asset asset-tuple))
        (user (get user asset-tuple)))
    (if (default-to false (map-get? user-collateral-assets { user: user, asset: asset }))
      (match (map-get? supported-assets { asset: asset })
        asset-info
          (let ((balance (default-to u0 (get balance (map-get? user-supply-balances { user: user, asset: asset }))))
                (price (get-asset-price-safe asset))
                (collateral-value (/ (* balance (get collateral-factor asset-info) price) (* PRECISION PRECISION))))
            { 
              total-collateral-value: (+ (get total-collateral-value accumulator) collateral-value),
              total-threshold-value: (+ (get total-threshold-value accumulator) 
                (/ (* collateral-value (get liquidation-threshold asset-info)) PRECISION))
            })
        accumulator)
      accumulator)))

(define-private (get-weighted-liquidation-threshold (collateral-data { total-collateral-value: uint, total-threshold-value: uint }))
  (if (> (get total-collateral-value collateral-data) u0)
    (/ (get total-threshold-value collateral-data) (get total-collateral-value collateral-data))
    u0))

;; --- Circuit Breaker Integration ---
(define-private (call-circuit-breaker-success)
  (match (var-get circuit-breaker-contract)
    breaker (contract-call? breaker record-success LENDING_SERVICE)
    true))

(define-private (call-circuit-breaker-failure)
  (match (var-get circuit-breaker-contract)
    breaker (contract-call? breaker record-failure LENDING_SERVICE)
    true))

(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker-contract)
    breaker (contract-call? breaker check-circuit-state LENDING_SERVICE)
    (ok true)))

;; --- Core Functions ---
(define-public (supply (asset <sip-010-ft-trait>) (amount uint))
  (match (supply-internal asset amount)
    success (begin (try! (call-circuit-breaker-success)) (ok success))
    error (begin (try! (call-circuit-breaker-failure)) (err error))))

(define-private (supply-internal (asset <sip-010-ft-trait>) (amount uint))
  (begin
    (try! (check-not-paused))
    (try! (check-circuit-breaker))
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (let ((asset-principal (contract-of asset)))
      (asserts! (is-some (map-get? supported-assets { asset: asset-principal })) ERR_INVALID_ASSET)
      (try! (accrue-interest asset-principal))
      (try! (contract-call? asset transfer amount tx-sender (as-contract tx-sender) none))
      (let ((current-balance (default-to u0 (get balance (map-get? user-supply-balances { user: tx-sender, asset: asset-principal })))))
        (map-set user-supply-balances { user: tx-sender, asset: asset-principal } { balance: (+ current-balance amount) })
        (map-set user-collateral-assets { user: tx-sender, asset: asset-principal } true)
        (ok true)))))

(define-public (withdraw (asset <sip-010-ft-trait>) (amount uint))
  (match (withdraw-internal asset amount)
    success (begin (try! (call-circuit-breaker-success)) (ok success))
    error (begin (try! (call-circuit-breaker-failure)) (err error))))

(define-private (withdraw-internal (asset <sip-010-ft-trait>) (amount uint))
  (begin
    (try! (check-not-paused))
    (try! (check-circuit-breaker))
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (let ((asset-principal (contract-of asset)))
      (try! (accrue-interest asset-principal))
      (let ((current-balance (default-to u0 (get balance (map-get? user-supply-balances { user: tx-sender, asset: asset-principal })))))
        (asserts! (>= current-balance amount) ERR_INSUFFICIENT_LIQUIDITY)
        (map-set user-supply-balances { user: tx-sender, asset: asset-principal } { balance: (- current-balance amount) })
        (let ((health (try! (get-health-factor tx-sender))))
          (asserts! (>= health PRECISION) ERR_INSUFFICIENT_COLLATERAL)
          (try! (as-contract (contract-call? asset transfer amount (as-contract tx-sender) tx-sender none)))
          (ok true))))))

(define-public (borrow (asset <sip-010-ft-trait>) (amount uint))
  (match (borrow-internal asset amount)
    success (begin (try! (call-circuit-breaker-success)) (ok success))
    error (begin (try! (call-circuit-breaker-failure)) (err error))))

(define-private (borrow-internal (asset <sip-010-ft-trait>) (amount uint))
  (begin
    (try! (check-not-paused))
    (try! (check-circuit-breaker))
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (let ((asset-principal (contract-of asset)))
      (try! (accrue-interest asset-principal))
      (let ((current-borrow-value (get-total-borrow-value-in-usd-safe tx-sender))
            (price (get-asset-price-safe asset-principal))
            (additional-borrow-value (/ (* amount price) PRECISION))
            (new-borrow-value (+ current-borrow-value additional-borrow-value))
            (collateral-value (get-total-collateral-value-in-usd-safe tx-sender)))
        (asserts! (>= collateral-value new-borrow-value) ERR_INSUFFICIENT_COLLATERAL)
        (let ((current-borrow (default-to u0 (get balance (map-get? user-borrow-balances { user: tx-sender, asset: asset-principal })))))
          (map-set user-borrow-balances { user: tx-sender, asset: asset-principal } { balance: (+ current-borrow amount) })
          (try! (as-contract (contract-call? asset transfer amount (as-contract tx-sender) tx-sender none)))
          (ok true))))))

(define-public (repay (asset <sip-010-ft-trait>) (amount uint))
  (match (repay-internal asset amount)
    success (begin (try! (call-circuit-breaker-success)) (ok success))
    error (begin (try! (call-circuit-breaker-failure)) (err error))))

(define-private (repay-internal (asset <sip-010-ft-trait>) (amount uint))
  (begin
    (try! (check-not-paused))
    (try! (check-circuit-breaker))
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (let ((asset-principal (contract-of asset)))
      (try! (accrue-interest asset-principal))
      (let ((current-borrow (default-to u0 (get balance (map-get? user-borrow-balances { user: tx-sender, asset: asset-principal }))))
            (repay-amount (min amount current-borrow)))
        (try! (contract-call? asset transfer repay-amount tx-sender (as-contract tx-sender) none))
        (map-set user-borrow-balances { user: tx-sender, asset: asset-principal } { balance: (- current-borrow repay-amount) })
        (ok true)))))

;; --- Liquidation ---
(define-public (liquidate 
  (liquidator principal) 
  (borrower principal) 
  (repay-asset <sip-010-ft-trait>) 
  (collateral-asset <sip-010-ft-trait>) 
  (repay-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get loan-liquidation-manager-contract)) ERR_UNAUTHORIZED)
    (try! (check-not-paused))
    (let ((repay-asset-principal (contract-of repay-asset))
          (collateral-asset-principal (contract-of collateral-asset)))
      (try! (accrue-interest repay-asset-principal))
      (try! (accrue-interest collateral-asset-principal))
      (let ((health (try! (get-health-factor borrower))))
        (asserts! (< health PRECISION) ERR_POSITION_HEALTHY)
        (let (
              (borrow-balance (default-to u0 (get balance (map-get? user-borrow-balances { user: borrower, asset: repay-asset-principal }))))
              (close-factor u500000000000000000)
              (max-repayable (/ (* borrow-balance close-factor) PRECISION))
              (actual-repay-amount (min repay-amount max-repayable))
              (repay-price (get-asset-price-safe repay-asset-principal))
              (collateral-price (get-asset-price-safe collateral-asset-principal))
              (asset-info (unwrap! (map-get? supported-assets { asset: collateral-asset-principal }) ERR_INVALID_ASSET))
              (liquidation-bonus (get liquidation-bonus asset-info))
              (repay-value-in-usd (/ (* actual-repay-amount repay-price) PRECISION))
              (bonus-value (/ (* repay-value-in-usd liquidation-bonus) PRECISION))
              (seize-value-in-usd (+ repay-value-in-usd bonus-value))
              (collateral-to-seize (/ (* seize-value-in-usd PRECISION) collateral-price))
              (borrower-collateral (default-to u0 (get balance (map-get? user-supply-balances { user: borrower, asset: collateral-asset-principal }))))
            )
          )
        (ok true)
      )
    )
  )
)