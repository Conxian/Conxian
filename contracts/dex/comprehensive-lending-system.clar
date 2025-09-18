;; comprehensive-lending-system.clar
;; Refactored for clarity, security, and correctness.

;; --- Traits ---
(use-trait oracle-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.oracle-trait)
(use-trait lending-system-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.lending-system-trait)
(use-trait access-control-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.access-control-trait)
(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.sip-010-ft-trait)
(use-trait pool-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.pool-trait)
(use-trait flash-loan-receiver-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.flash-loan-receiver-trait)

(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.lending-system-trait)

(define-trait circuit-breaker-trait
  (
    (check-circuit-state (string-ascii 64) (response uint uint))
    (record-success (string-ascii 64) (response uint uint))
    (record-failure (string-ascii 64) (response uint uint))
  )
)

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

(define-constant PRECISION u1000000000000000000) ;; 1e18

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var paused bool false)

;; Contract Dependencies (set by owner)
(define-constant oracle .oracle)
(define-constant interest-rate-model .interest-rate-model)
(define-constant loan-liquidation-manager .loan-liquidation-manager)
(define-constant access-control .access-control)
(define-data-var oracle-contract principal oracle)
(define-data-var interest-rate-model-contract principal interest-rate-model)
(define-data-var loan-liquidation-manager-contract principal loan-liquidation-manager)
(define-data-var access-control-contract principal access-control)
(define-data-var circuit-breaker-contract (optional principal) none)

;; --- Maps ---
(define-map supported-assets { asset: principal } { collateral-factor: uint, liquidation-threshold: uint, liquidation-bonus: uint })
(define-map user-supply-balances { user: principal, asset: principal } { balance: uint })
(define-map user-borrow-balances { user: principal, asset: principal } { balance: uint })
(define-map user-collateral-assets { user: principal, asset: principal } bool)

;; --- Private Functions ---
(define-private (check-is-owner) (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)))
(define-private (check-not-paused) (ok (asserts! (not (var-get paused)) ERR_PAUSED)))

(define-private (get-asset-price (asset principal))
  (contract-call? (var-get oracle-contract) get-price-fresh asset)
)

(define-private (accrue-interest (asset principal))
  (contract-call? (var-get interest-rate-model-contract) accrue-interest asset)
)

;; Calculates the total value of a user's collateral, adjusted by collateral factors.
(define-private (get-total-collateral-value-in-usd (user principal))
  (let ((supported-assets (map-keys user-collateral-assets)))
    (fold
      (lambda (asset-tuple total-value)
        (let ((asset (get-in-tuple? asset-tuple { asset: principal })))
          (if (default-to false (map-get? user-collateral-assets { user: user, asset: asset }))
            (let ((asset-info (unwrap! (map-get? supported-assets { asset: asset }) (err u0)))
                  (balance (default-to u0 (map-get? user-supply-balances { user: user, asset: asset })))
                  (price (unwrap! (get-asset-price asset) (err u0))))
              (+ total-value (/ (* balance (get collateral-factor asset-info) price) (* PRECISION PRECISION)))
            )
            total-value
          )
        )
      )
      supported-assets
      u0
    )
  )
)

;; Calculates the total value of a user's borrows.
(define-private (get-total-borrow-value-in-usd (user principal))
  (let ((borrowed-assets (map-keys user-borrow-balances)))
     (fold
      (lambda (asset-tuple total-value)
        (let ((asset (get-in-tuple? asset-tuple { asset: principal })))
          (let ((balance (default-to u0 (map-get? user-borrow-balances { user: user, asset: asset })))
                (price (unwrap! (get-asset-price asset) (err u0))))
            (+ total-value (/ (* balance price) PRECISION))
          )
        )
      )
      borrowed-assets
      u0
    )
  )
)

;; --- Health Factor Calculation ---
(define-read-only (get-health-factor (user principal))
  (let ((collateral-value (get-total-collateral-value-in-usd user))
        (borrow-value (get-total-borrow-value-in-usd user)))
    (if (> borrow-value u0)
      (ok (/ (* collateral-value PRECISION) borrow-value))
      (ok u18446744073709551615) ;; max-uint (2^64 - 1)
    )
  )
)

;; --- Core Functions ---

(define-private (call-circuit-breaker-success)
  (match (var-get circuit-breaker-contract)
    breaker (try! (contract-call? breaker record-success LENDING_SERVICE))
    none    true
  )
)

(define-private (call-circuit-breaker-failure)
  (match (var-get circuit-breaker-contract)
    breaker (try! (contract-call? breaker record-failure LENDING_SERVICE))
    none    true
  )
)

(define-public (supply (asset principal) (amount uint))
  (match (supply-internal asset amount)
    (ok result)
      (begin
        (try! (call-circuit-breaker-success))
        (ok result)
      )
    (err error-code)
      (begin
        (try! (call-circuit-breaker-failure))
        (err error-code)
      )
  )
)

(define-private (supply-internal (asset-principal principal) (amount uint))
  (begin
    (try! (check-not-paused))
    (match (var-get circuit-breaker-contract)
      breaker (try! (contract-call? breaker check-circuit-state LENDING_SERVICE))
      none    true
    )
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (asserts! (is-some (map-get? supported-assets { asset: asset-principal })) ERR_INVALID_ASSET)
    (try! (accrue-interest asset-principal))

    ;; Transfer asset from user to this contract
    (let ((asset-trait (contract-of asset-principal)))
        (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))
    )

    ;; Update user's supply balance
    (let ((current-balance (default-to u0 (map-get? user-supply-balances { user: tx-sender, asset: asset-principal }))))
      (map-set user-supply-balances { user: tx-sender, asset: asset-principal } { balance: (+ current-balance amount) })
    )

    ;; By default, new supply is used as collateral
    (map-set user-collateral-assets { user: tx-sender, asset: asset-principal } true)

    (ok true)
  )
)

(define-public (set-circuit-breaker-contract (breaker principal))
  (begin
    (try! (check-is-owner))
    (var-set circuit-breaker-contract (some breaker))
    (ok true)
  )
)

(define-public (withdraw (asset principal) (amount uint))
  (match (withdraw-internal asset amount)
    (ok result)
      (begin
        (try! (call-circuit-breaker-success))
        (ok result)
      )
    (err error-code)
      (begin
        (try! (call-circuit-breaker-failure))
        (err error-code)
      )
  )
)

(define-private (withdraw-internal (asset-principal principal) (amount uint))
  (begin
    (try! (check-not-paused))
    (match (var-get circuit-breaker-contract)
      breaker (try! (contract-call? breaker check-circuit-state LENDING_SERVICE))
      none    true
    )
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (try! (accrue-interest asset-principal))
    (let ((current-balance (default-to u0 (map-get? user-supply-balances { user: tx-sender, asset: asset-principal }))))
      (asserts! (>= current-balance amount) ERR_INSUFFICIENT_LIQUIDITY)
      (map-set user-supply-balances { user: tx-sender, asset: asset-principal } { balance: (- current-balance amount) })
      (let ((health (unwrap! (get-health-factor tx-sender) ERR_HEALTH_CHECK_FAILED)))
        (asserts! (>= health PRECISION) ERR_INSUFFICIENT_COLLATERAL)
      )
      (let ((asset-trait (contract-of asset-principal)))
        (try! (as-contract (contract-call? asset-trait transfer amount (as-contract tx-sender) tx-sender none)))
      )
      (ok true)
    )
  )
)

(define-public (borrow (asset principal) (amount uint))
  (match (borrow-internal asset amount)
    (ok result)
      (begin
        (try! (call-circuit-breaker-success))
        (ok result)
      )
    (err error-code)
      (begin
        (try! (call-circuit-breaker-failure))
        (err error-code)
      )
  )
)

(define-private (borrow-internal (asset-principal principal) (amount uint))
  (begin
    (try! (check-not-paused))
    (match (var-get circuit-breaker-contract)
      breaker (try! (contract-call? breaker check-circuit-state LENDING_SERVICE))
      none    true
    )
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (try! (accrue-interest asset-principal))
    (let ((current-borrow-value (get-total-borrow-value-in-usd tx-sender))
          (price (unwrap! (get-asset-price asset-principal) (err u0)))
          (additional-borrow-value (/ (* amount price) PRECISION)))
      (let ((new-borrow-value (+ current-borrow-value additional-borrow-value))
            (collateral-value (get-total-collateral-value-in-usd tx-sender)))
        (asserts! (>= collateral-value new-borrow-value) ERR_INSUFFICIENT_COLLATERAL)
      )
    )
    (let ((current-borrow (default-to u0 (map-get? user-borrow-balances { user: tx-sender, asset: asset-principal }))))
      (map-set user-borrow-balances { user: tx-sender, asset: asset-principal } { balance: (+ current-borrow amount) })
    )
    (let ((asset-trait (contract-of asset-principal)))
      (try! (as-contract (contract-call? asset-trait transfer amount (as-contract tx-sender) tx-sender none)))
    )
    (ok true)
  )
)

(define-public (repay (asset principal) (amount uint))
  (match (repay-internal asset amount)
    (ok result)
      (begin
        (try! (call-circuit-breaker-success))
        (ok result)
      )
    (err error-code)
      (begin
        (try! (call-circuit-breaker-failure))
        (err error-code)
      )
  )
)

(define-private (repay-internal (asset-principal principal) (amount uint))
  (begin
    (try! (check-not-paused))
    (match (var-get circuit-breaker-contract)
      breaker (try! (contract-call? breaker check-circuit-state LENDING_SERVICE))
      none    true
    )
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (try! (accrue-interest asset-principal))
    (let ((current-borrow (default-to u0 (map-get? user-borrow-balances { user: tx-sender, asset: asset-principal }))))
      (let ((repay-amount (min amount current-borrow)))
        (let ((asset-trait (contract-of asset-principal)))
          (try! (contract-call? asset-trait transfer repay-amount tx-sender (as-contract tx-sender) none))
        )
        (map-set user-borrow-balances { user: tx-sender, asset: asset-principal } { balance: (- current-borrow repay-amount) })
        (ok true)
      )
    )
  )
)

;; --- Liquidation ---
;; This function can only be called by the authorized loan-liquidation-manager contract.
(define-public (liquidate (liquidator principal) (borrower principal) (repay-asset principal) (collateral-asset principal) (repay-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get loan-liquidation-manager-contract)) ERR_UNAUTHORIZED)
    (try! (check-not-paused))

    (let ((repay-asset-principal (contract-of repay-asset))
          (collateral-asset-principal (contract-of collateral-asset)))
      
      ;; Accrue interest for both assets
      (try! (accrue-interest repay-asset-principal))
      (try! (accrue-interest collateral-asset-principal))

      ;; Check health factor
      (let ((health (unwrap! (get-health-factor borrower) ERR_HEALTH_CHECK_FAILED)))
        (asserts! (< health PRECISION) ERR_POSITION_HEALTHY)
      )

      ;; Determine amount to repay
      (let ((borrow-balance (default-to u0 (map-get? user-borrow-balances { user: borrower, asset: repay-asset-principal })))
            (close-factor u500000000000000000) ;; 50%
            (max-repayable (/ (* borrow-balance close-factor) PRECISION)))
        (let ((actual-repay-amount (min repay-amount max-repayable)))
          
          ;; Calculate collateral to seize
          (let ((repay-price (unwrap! (get-asset-price repay-asset-principal) (err u0)))
                (collateral-price (unwrap! (get-asset-price collateral-asset-principal) (err u0)))
                (liquidation-bonus (get liquidation-bonus (unwrap! (map-get? supported-assets { asset: collateral-asset-principal }) (err u0)))))
            (let ((repay-value-in-usd (/ (* actual-repay-amount repay-price) PRECISION))
                  (bonus-value (/ (* repay-value-in-usd liquidation-bonus) PRECISION))
                  (seize-value-in-usd (+ repay-value-in-usd bonus-value)))
              (let ((collateral-to-seize (/ (* seize-value-in-usd PRECISION) collateral-price)))

                (let ((borrower-collateral (default-to u0 (map-get? user-supply-balances { user: borrower, asset: collateral-asset-principal }))))
                  (asserts! (>= borrower-collateral collateral-to-seize) ERR_INSUFFICIENT_COLLATERAL)

                  ;; --- EFFECTS ---
                  ;; 1. Liquidator repays borrower's debt
                  (try! (contract-call? repay-asset transfer actual-repay-amount liquidator (as-contract tx-sender) none))
                  (map-set user-borrow-balances { user: borrower, asset: repay-asset-principal } { balance: (- borrow-balance actual-repay-amount) })
                  
                  ;; 2. Liquidator receives borrower's collateral
                  (map-set user-supply-balances { user: borrower, asset: collateral-asset-principal } { balance: (- borrower-collateral collateral-to-seize) })

                  ;; --- INTERACTION ---
                  (try! (as-contract (contract-call? collateral-asset transfer collateral-to-seize (as-contract tx-sender) liquidator none)))

                  (print {
                    event: "liquidation",
                    liquidator: liquidator,
                    borrower: borrower,
                    repay-asset: repay-asset-principal,
                    collateral-asset: collateral-asset-principal,
                    debt-repaid: actual-repay-amount,
                    collateral-seized: collateral-to-seize
                  })
                  (ok true)
                )
              )
            )
          )
        )
      )
    )
  )
)

;; --- Admin Functions ---
(define-public (set-paused (new-paused bool))
  (begin
    (try! (check-is-owner))
    (var-set paused new-paused)
    (ok true)
  )
)

(define-public (add-asset (asset principal) (collateral-factor uint) (liquidation-threshold uint) (liquidation-bonus uint))
  (begin
    (try! (check-is-owner))
    (asserts! (is-none (map-get? supported-assets { asset: asset })) ERR_ALREADY_SET)
    (map-set supported-assets { asset: asset }
      {
        collateral-factor: collateral-factor,
        liquidation-threshold: liquidation-threshold,
        liquidation-bonus: liquidation-bonus
      }
    )
    (ok true)
  )
)

(define-public (set-loan-liquidation-manager (manager principal))
  (begin
    (try! (check-is-owner))
    (var-set loan-liquidation-manager-contract manager)
    (ok true)
  )
)
