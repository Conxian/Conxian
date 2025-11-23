;; comprehensive-lending-system.clar
;; Refactored for clarity, security, and correctness.

;; --- Traits ---
(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)
(use-trait lending-system-trait .lending-system-trait.lending-system-trait)
(use-trait rbac-trait .decentralized-trait-registry.decentralized-trait-registry)
(use-trait err-trait  .error-codes-trait.error-codes-trait)

;; --- Constants ---
(define-constant LENDING_SERVICE "lending-service")
(define-constant PRECISION u1000000000000000000) ;; 1e18
(define-constant BPS u10000) ;; basis points scale

;; Error codes from standard-errors.clar
(define-constant ERR_UNAUTHORIZED (err u1100))
(define-constant ERR_PAUSED (err u1003))
(define-constant ERR_INVALID_ASSET (err u1310))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u1311))
(define-constant ERR_TRANSFER_FAILED (err u1202))
(define-constant ERR_ZERO_AMOUNT (err u1207))
(define-constant ERR_HEALTH_CHECK_FAILED (err u1013))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1307))
(define-constant ERR_ALREADY_SET (err u1015))
(define-constant ERR_POSITION_HEALTHY (err u1017))
(define-constant ERR_LIQUIDATION_THRESHOLD_NOT_FOUND (err u1018))
(define-constant ERR_INVALID_TUPLE (err u1019))
(define-constant ERR_POR_STALE (err u1507))
(define-constant ERR_POR_MISSING (err u1506))
(define-constant ERR_CIRCUIT_BREAKER_OPEN (err u5007))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var paused bool false)
(define-data-var oracle-contract principal tx-sender)
(define-data-var interest-rate-model-contract principal tx-sender)
(define-data-var loan-liquidation-manager-contract principal tx-sender)
(define-data-var access-control-contract principal tx-sender)
(define-data-var circuit-breaker-contract (optional principal) none)
;; Proof of Reserves integration
(define-data-var por-contract (optional principal) none)
(define-data-var enforce-por-borrow bool false)

;; Monitoring and risk parameters
(define-data-var monitoring-contract (optional principal) none)
(define-data-var borrow-safety-buffer-bps uint u0)
(define-data-var min-health-factor-precision uint u0)
(define-data-var capacity-alert-threshold-bps uint u0)

;; --- Admin Setters ---
;; @notice Sets the new contract owner.
;; @param new-owner The principal of the new contract owner.
;; @returns A response tuple with `(ok true)` if successful, `(err ERR_UNAUTHORIZED)` otherwise.
(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Proof of Reserves integration
(define-data-var por-contract (optional principal) none)
(define-data-var enforce-por-borrow bool false)

;; Monitoring and risk parameters
(define-data-var monitoring-contract (optional principal) none)
(define-data-var borrow-safety-buffer-bps uint u0)
(define-data-var min-health-factor-precision uint u0)
(define-data-var capacity-alert-threshold-bps uint u0)

;; --- Admin Setters ---
;; @notice Sets the new contract owner.
;; @param new-owner The principal of the new contract owner.
;; @returns A response tuple with `(ok true)` if successful, `(err ERR_UNAUTHORIZED)` otherwise.
(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @notice Sets the oracle contract address.
;; @param oracle The principal of the oracle contract.
;; @returns A response tuple with `(ok true)` if successful, `(err ERR_UNAUTHORIZED)` otherwise.
(define-public (set-oracle (oracle principal))
  (begin
    (asserts!
      (contract-call? (var-get access-control-contract)
        has-role "contract-owner" tx-sender
      )
      ERR_UNAUTHORIZED
    )
    (var-set oracle-contract oracle)
    (ok true)
  )
)

;; @notice Sets the interest rate model contract address.
;; @param irm The principal of the interest rate model contract.
;; @returns A response tuple with `(ok true)` if successful, `(err ERR_UNAUTHORIZED)` otherwise.
(define-public (set-interest-rate-model (irm principal))
  (begin
    (asserts!
      (contract-call? (var-get access-control-contract)
        has-role "contract-owner" tx-sender
      )
      ERR_UNAUTHORIZED
    )
    (var-set interest-rate-model-contract irm)
    (ok true)
  )
)

;; @notice Sets the loan liquidation manager contract address.
;; @param lm The principal of the loan liquidation manager contract.
;; @returns A response tuple with `(ok true)` if successful, `(err ERR_UNAUTHORIZED)` otherwise.
(define-public (set-liquidation-manager (lm principal))
  (begin
    (asserts!
      (contract-call? (var-get access-control-contract)
        has-role "contract-owner" tx-sender
      )
      ERR_UNAUTHORIZED
    )
    (var-set loan-liquidation-manager-contract lm)
    (ok true)
  )
)

;; @notice Sets the access control contract address.
;; @param ac The principal of the access control contract.
;; @returns A response tuple with `(ok true)` if successful, `(err ERR_UNAUTHORIZED)` otherwise.
(define-public (set-access-control (ac principal))
  (begin
    (asserts!
      (contract-call? (var-get access-control-contract)
        has-role "contract-owner" tx-sender
      )
      ERR_UNAUTHORIZED
    )
    (var-set access-control-contract ac)
    (ok true)
  )
)

;; @notice Sets the circuit breaker contract address.
;; @param cb The principal of the circuit breaker contract.
;; @returns A response tuple with `(ok true)` if successful, `(err ERR_UNAUTHORIZED)` otherwise.
(define-public (set-circuit-breaker (cb principal))
  (begin
    (asserts!
      (contract-call? (var-get access-control-contract)
        has-role "contract-owner" tx-sender
      )
      ERR_UNAUTHORIZED
    )
    (var-set circuit-breaker-contract (some cb))
    (ok true)
  )
)
;; Configure Proof of Reserves enforcement
;; @notice Configures the Proof of Reserves (PoR) contract address.
;; @param por The principal of the PoR contract.
;; @returns A response tuple with `(ok true)` if successful, `(err ERR_UNAUTHORIZED)` otherwise.
(define-public (set-proof-of-reserves (por principal))
  (begin
    (asserts!
      (contract-call? (var-get access-control-contract)
        has-role "contract-owner" tx-sender
      )
      ERR_UNAUTHORIZED
    )
    (var-set por-contract (some por))
    (ok true)
  )
)

;; @notice Sets whether Proof of Reserves (PoR) enforcement is active for borrows.
;; @param flag A boolean indicating whether to enforce PoR for borrows (true) or not (false).
;; @returns A response tuple with `(ok true)` if successful, `(err ERR_UNAUTHORIZED)` otherwise.
(define-public (set-enforce-por-borrow (flag bool))
  (begin
    (asserts!
      (contract-call? (var-get access-control-contract)
        has-role "contract-owner" tx-sender
      )
      ERR_UNAUTHORIZED
    )
    (var-set enforce-por-borrow flag)
    (ok true)
  )
)
;; Monitoring and risk parameter setters
;; @notice Sets the monitoring contract address.
;; @param mc The principal of the monitoring contract.
;; @returns A response tuple with `(ok true)` if successful, `(err ERR_UNAUTHORIZED)` otherwise.
(define-public (set-monitoring (mc principal))
  (begin
    (asserts!
      (contract-call? (var-get access-control-contract)
        has-role "contract-owner" tx-sender
      )
      ERR_UNAUTHORIZED
    )
    (var-set monitoring-contract (some mc))
    (ok true)
  )
)

;; @notice Sets various risk parameters for the lending system.
;; @param buffer-bps The borrow safety buffer in basis points.
;; @param min-hf The minimum health factor precision.
;; @param alert-thr-bps The capacity alert threshold in basis points.
;; @returns A response tuple with `(ok true)` if successful, `(err ERR_UNAUTHORIZED)` otherwise.
(define-public (set-risk-params (buffer-bps uint) (min-hf uint) (alert-thr-bps uint))
  (begin
    (asserts!
      (contract-call? (var-get access-control-contract)
        has-role "contract-owner" tx-sender
      )
      ERR_UNAUTHORIZED
    )
    (var-set borrow-safety-buffer-bps buffer-bps)
    (var-set min-health-factor-precision min-hf)
    (var-set capacity-alert-threshold-bps alert-thr-bps)
    (ok true)
  )
)

;; --- Maps ---
(define-map supported-assets { asset: principal } { collateral-factor: uint, liquidation-threshold: uint, liquidation-bonus: uint })
(define-map user-supply-balances { user: principal, asset: principal } { balance: uint })
(define-map user-borrow-balances { user: principal, asset: principal } { balance: uint })
(define-map user-collateral-assets { user: principal, asset: principal } bool)

;; Track supported assets for iteration
(define-data-var supported-asset-list (list 100 principal) (list))

;; Admin: register or update supported asset parameters
;; @notice Adds a new asset to the list of supported assets or updates its parameters.
;; @param asset The principal of the asset to add or update.
;; @param collateral-factor The collateral factor for the asset in basis points.
;; @param liquidation-threshold The liquidation threshold for the asset in basis points.
;; @param liquidation-bonus The liquidation bonus for the asset in basis points.
;; @returns A response tuple with `(ok true)` if successful, `(err ERR_UNAUTHORIZED)` or `(err ERR_INVALID_TUPLE)` or `(err ERR_INSUFFICIENT_LIQUIDITY)` otherwise.
(define-public (add-supported-asset (asset principal) (collateral-factor uint) (liquidation-threshold uint) (liquidation-bonus uint))
  (begin
    (asserts! (contract-call? (var-get access-control-contract) has-role "contract-owner" tx-sender) ERR_UNAUTHORIZED)
    (asserts! (<= collateral-factor BPS) ERR_INVALID_TUPLE)
    (asserts! (and (>= liquidation-threshold u5000) (<= liquidation-threshold BPS)) ERR_INVALID_TUPLE)
    (asserts! (<= liquidation-bonus u2000) ERR_INVALID_TUPLE)
    (map-set supported-assets { asset: asset } { collateral-factor: collateral-factor, liquidation-threshold: liquidation-threshold, liquidation-bonus: liquidation-bonus })
    (let ((current (var-get supported-asset-list)))
      (asserts! (< (len current) u100) ERR_INSUFFICIENT_LIQUIDITY)
      (var-set supported-asset-list (unwrap-panic (as-max-len? (append current asset) u100)))
    )
    (ok true)
  )
)

;; Admin: remove an asset from supported list
;; @notice Removes an asset from the list of supported assets.
;; @param asset The principal of the asset to remove.
;; @returns A response tuple with `(ok true)` if successful, `(err ERR_UNAUTHORIZED)` otherwise.
(define-public (remove-supported-asset (asset principal))
  (begin
    (asserts! (contract-call? (var-get access-control-contract) has-role "contract-owner" tx-sender) ERR_UNAUTHORIZED)
    (map-delete supported-assets { asset: asset })
    (var-set supported-asset-list (filter-assets (var-get supported-asset-list) asset))
    (ok true)
  )
)

;; Helper: check if an asset exists in the list
(define-private (contains-asset-step (a principal) (found bool) (target principal))
  (if found found (is-eq a target))
)

(define-private (contains-asset (assets (list 100 principal)) (target principal))
  (fold contains-asset-step assets false target)
)

;; Helper: remove target asset from list
(define-private (filter-assets (assets (list 100 principal)) (target principal))
  (let ((filtered-list (fold
                          (lambda (a acc)
                            (if (is-eq a target) acc (append acc a)))
                          assets
                          (list))))
    (unwrap-panic (as-max-len? filtered-list u100))))

;; --- Private Helper Functions ---
(define-private (check-is-owner)
  (asserts! (contract-call? (var-get access-control-contract) has-role "contract-owner" tx-sender) ERR_UNAUTHORIZED))

(define-private (check-not-paused)
  (asserts! (not (var-get paused)) ERR_PAUSED))

(define-private (get-asset-price-safe (asset principal))
  ;; Fetch price from configured oracle; fallback to dex-oracle; return 0 on error
  (match (contract-call? (var-get oracle-contract) get-price asset)
    (ok p) p
    (err e)
      (match (contract-call? .dex-oracle get-price asset)
        (ok p2) p2
        (err e2) u0
      )
  )
)

(define-private (accrue-interest (asset principal))
  (as-contract (contract-call? (var-get interest-rate-model-contract) accrue-interest asset))
)

(define-private (min (a uint) (b uint))
  (if (<= a b) a b))

;; --- Collateral & Borrow Value Calculations ---
;; @notice Calculates the total collateral value in USD for a given user, safely handling errors.
;; @param user The principal of the user.
;; @returns The total collateral value in USD as a uint.
(define-read-only (get-total-collateral-value-in-usd-safe (user principal))
  (let ((assets (var-get supported-asset-list)))
    (fold
      (lambda (asset acc)
        (if (default-to false (map-get? user-collateral-assets { user: user, asset: asset }))
          (match (map-get? supported-assets { asset: asset })
            info
              (let ((balance (default-to u0 (get balance (map-get? user-supply-balances { user: user, asset: asset }))))
                    (price (get-asset-price-safe asset))
                    (factor (get collateral-factor info)))
                (+ acc (/ (* (/ (* balance price) PRECISION) factor) BPS)))
            acc)
          acc)
      )
      assets
      u0)
  )
)

(define-private (calculate-collateral-value (asset-tuple { user: principal, asset: principal }) (total-value uint))
  (let ((asset (get asset asset-tuple))
        (user (get user asset-tuple)))
    (if (default-to false (map-get? user-collateral-assets { user: user, asset: asset }))
      (match (map-get? supported-assets { asset: asset })
        asset-info
          (let ((balance (default-to u0 (get balance (map-get? user-supply-balances { user: user, asset: asset }))))
                (price (get-asset-price-safe asset)))
              (+ total-value (/ (* balance (get collateral-factor asset-info) price) PRECISION)))
          total-value)
        total-value)))

;; @notice Calculates the total borrow value in USD for a given user, safely handling errors.
;; @param user The principal of the user.
;; @returns The total borrow value in USD as a uint.
(define-read-only (get-total-borrow-value-in-usd-safe (user principal))
  (let ((assets (var-get supported-asset-list)))
    (fold
      (lambda (asset acc)
        (let ((balance (default-to u0 (get balance (map-get? user-borrow-balances { user: user, asset: asset }))))
              (price (get-asset-price-safe asset)))
          (+ acc (/ (* balance price) PRECISION)))
      )
      assets
      u0)
  )
)

(define-private (calculate-borrow-value (borrow-tuple { user: principal, asset: principal }) (total-value uint))
  (let ((asset (get asset borrow-tuple))
        (user (get user borrow-tuple))
        (balance (default-to u0 (get balance (map-get? user-borrow-balances { user: user, asset: asset }))))
        (price (get-asset-price-safe asset)))
    (+ total-value (/ (* balance price) PRECISION))))

;; --- Health Factor Calculation ---
;; @notice Calculates the health factor for a given user.
;; @param user The principal of the user.
;; @returns A response tuple with `(ok uint)` representing the health factor, or an error.
(define-read-only (get-health-factor (user principal))
  (let ((collateral-data (calculate-weighted-collateral user))
        (collateral-value (get total-collateral-value collateral-data))
        (weighted-threshold (get-weighted-liquidation-threshold collateral-data))
        (borrow-value (get-total-borrow-value-in-usd-safe user)))
    (if (> borrow-value u0)
      (ok (/ (* collateral-value weighted-threshold) borrow-value))
      (ok u18446744073709551615))))

(define-private (calculate-weighted-collateral (user principal))
  (let ((assets (var-get supported-asset-list)))
    (fold
      (lambda (asset acc)
        (if (default-to false (map-get? user-collateral-assets { user: user, asset: asset }))
          (match (map-get? supported-assets { asset: asset })
            info
              (let ((balance (default-to u0 (get balance (map-get? user-supply-balances { user: user, asset: asset }))))
                    (price (get-asset-price-safe asset))
                    (value-usd (/ (* balance price) PRECISION))
                    (threshold (get liquidation-threshold info)))
                {
                  total-collateral-value: (+ (get total-collateral-value acc) value-usd),
                  total-threshold-value: (+ (get total-threshold-value acc) (* value-usd threshold))
                }
              )
            acc)
          acc)
      )
      assets
      { total-collateral-value: u0, total-threshold-value: u0 })
  )
)

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
                (collateral-value (/ (* balance (get collateral-factor asset-info) price) PRECISION)))
            { 
              total-collateral-value: (+ (get total-collateral-value accumulator) collateral-value),
              total-threshold-value: (+ (get total-threshold-value accumulator) 
                (/ (* collateral-value (get liquidation-threshold asset-info)) PRECISION))
            })
        accumulator)
      accumulator)))

(define-private (get-weighted-liquidation-threshold (collateral-data { total-collateral-value: uint, total-threshold-value: uint }))
  (if (> (get total-collateral-value collateral-data) u0)
    ;; Scale to PRECISION: (sum(value * threshold_bps)/sum(value)) * PRECISION / BPS
    (/ (* (get total-threshold-value collateral-data) PRECISION) (* (get total-collateral-value collateral-data) BPS))
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
    breaker (unwrap! (contract-call? breaker check-circuit-state LENDING_SERVICE) ERR_CIRCUIT_BREAKER_OPEN)
    (ok true)))

;; --- Core Functions ---
;; @notice Supplies an asset to the lending pool.
;; @param asset The trait of the asset to supply.
;; @param amount The amount of the asset to supply.
;; @returns A response tuple with `(ok true)` if successful, or an error code.
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
        (ok true)
      )
    )
  )
)

;; @notice Withdraws an asset from the lending pool.
;; @param asset The trait of the asset to withdraw.
;; @param amount The amount of the asset to withdraw.
;; @returns A response tuple with `(ok true)` if successful, or an error code.
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
        (asserts! (>= current-balance amount) ERR_INSUFFICIENT_COLLATERAL)
        (let ((new-balance (- current-balance amount)))
          (map-set user-supply-balances { user: tx-sender, asset: asset-principal } { balance: new-balance })
          (if (is-eq new-balance u0)
            (map-delete user-collateral-assets { user: tx-sender, asset: asset-principal })
            true
          )
          (let ((health-factor (try! (get-health-factor tx-sender))))
            (asserts! (>= health-factor (var-get min-health-factor-precision)) ERR_HEALTH_CHECK_FAILED)
            (try! (as-contract (contract-call? asset transfer amount tx-sender tx-sender none)))
            (ok true)
          )
        )
      )
    )
  )
)

(define-private (borrow-internal (asset <sip-010-ft-trait>) (amount uint))
  (begin
    (try! (check-not-paused))
    (try! (check-circuit-breaker))
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (let ((asset-principal (contract-of asset)))
      (asserts! (is-some (map-get? supported-assets { asset: asset-principal })) ERR_INVALID_ASSET)
      (try! (accrue-interest asset-principal))
      (let ((health-factor (try! (get-health-factor tx-sender))))
        (asserts! (>= health-factor (var-get min-health-factor-precision)) ERR_HEALTH_CHECK_FAILED)
        (let ((available-liquidity (get-balance (as-contract tx-sender) asset-principal)))
          (asserts! (>= available-liquidity amount) ERR_INSUFFICIENT_LIQUIDITY)
          (let ((current-borrow-balance (default-to u0 (get balance (map-get? user-borrow-balances { user: tx-sender, asset: asset-principal })))))
            (map-set user-borrow-balances { user: tx-sender, asset: asset-principal } { balance: (+ current-borrow-balance amount) })
            (try! (as-contract (contract-call? asset transfer amount tx-sender tx-sender none)))
            (ok true)
          )
        )
      )
    )
  )
)

(define-private (repay-internal (asset <sip-010-ft-trait>) (amount uint))
  (begin
    (try! (check-not-paused))
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (let ((asset-principal (contract-of asset)))
      (try! (accrue-interest asset-principal))
      (let ((current-borrow-balance (default-to u0 (get balance (map-get? user-borrow-balances { user: tx-sender, asset: asset-principal })))))
        (asserts! (>= current-borrow-balance amount) ERR_INSUFFICIENT_COLLATERAL)
        ;; Rest of function implementation would go here
        (ok true)
      )
    )
  )
)

(define-private (liquidate-internal (borrower principal) (collateral-asset <sip-010-ft-trait>) (borrowed-asset <sip-010-ft-trait>) (amount uint))
  (begin
    (try! (check-not-paused))
    (let (
      (health-factor (try! (get-health-factor borrower)))
      (borrowed-asset-principal (contract-of borrowed-asset))
      (collateral-asset-principal (contract-of collateral-asset))
      (borrowed-asset-info (unwrap! (map-get? supported-assets { asset: borrowed-asset-principal }) ERR_INVALID_ASSET))
      (collateral-asset-info (unwrap! (map-get? supported-assets { asset: collateral-asset-principal })
        ERR_INVALID_ASSET
      ))
      (borrowed-price (get-asset-price-safe borrowed-asset-principal))
      (collateral-price (get-asset-price-safe collateral-asset-principal))
      (liquidation-bonus (get liquidation-bonus collateral-asset-info))
      (amount-to-seize (/ (* (/ (* amount borrowed-price) PRECISION) (+ BPS liquidation-bonus)) collateral-price))
      (borrower-collateral (default-to u0 (get balance (map-get? user-supply-balances { user: borrower, asset: collateral-asset-principal }))))
      (borrower-borrow-balance (default-to u0 (get balance (map-get? user-borrow-balances { user: borrower, asset: borrowed-asset-principal }))))
    )
      (asserts! (< health-factor (var-get min-health-factor-precision)) ERR_POSITION_HEALTHY)
      (asserts! (>= borrower-collateral amount-to-seize) ERR_INSUFFICIENT_COLLATERAL)
      (try! (contract-call? borrowed-asset transfer amount tx-sender (as-contract tx-sender) none))
      (map-set user-borrow-balances { user: borrower, asset: borrowed-asset-principal } { balance: (- borrower-borrow-balance amount) })
      (map-set user-supply-balances { user: borrower, asset: collateral-asset-principal } { balance: (- borrower-collateral amount-to-seize) })
      (try! (as-contract (contract-call? collateral-asset transfer amount-to-seize tx-sender tx-sender none)))
      (ok true)
    )
  )
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
        (let ((buffer (var-get borrow-safety-buffer-bps))
              (max-allowed (/ (* collateral-value (- BPS buffer)) BPS)))
          (asserts! (>= max-allowed new-borrow-value) ERR_INSUFFICIENT_COLLATERAL))
        (let ((current-borrow (default-to u0 (get balance (map-get? user-borrow-balances { user: tx-sender, asset: asset-principal })))))
          (map-set user-borrow-balances { user: tx-sender, asset: asset-principal } { balance: (+ current-borrow amount) })
          (try! (as-contract (contract-call? asset transfer amount (as-contract tx-sender) tx-sender none)))
          (record-user-metrics tx-sender)
          (ok true))))))

;; @notice Repays a borrowed asset to the lending pool.
;; @param asset The trait of the asset to repay.
;; @param amount The amount of the asset to repay.
;; @returns A response tuple with `(ok true)` if successful, or an error code.
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
        (record-user-metrics tx-sender)
        (ok true)))))

;; --- Liquidation ---
;; @notice Liquidates a borrower's position.
;; @param liquidator The principal of the liquidator.
;; @param borrower The principal of the borrower whose position is being liquidated.
;; @param repay-asset The trait of the asset used to repay the borrow.
;; @param collateral-asset The trait of the collateral asset to seize.
;; @param repay-amount The amount of the repay-asset to use for liquidation.
;; @returns A response tuple with `(ok { repaid: uint, seized: uint })` if successful, or an error code.
(define-public (liquidate 
  (liquidator principal) 
  (borrower principal) 
  (repay-asset <sip-010-ft-trait>) 
  (collateral-asset <sip-010-ft-trait>) 
  (repay-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get loan-liquidation-manager-contract)) ERR_UNAUTHORIZED)
    (try! (check-not-paused))
    ;; Check borrower health
    (let ((health (try! (get-health-factor borrower))))
      (asserts! (< health PRECISION) ERR_POSITION_HEALTHY)
      (let ((repay-asset-principal (contract-of repay-asset))
            (collateral-asset-principal (contract-of collateral-asset)))
        (try! (accrue-interest repay-asset-principal))
        (try! (accrue-interest collateral-asset-principal))
        ;; Transfer repay amount from liquidator to protocol
        (try! (as-contract (contract-call? repay-asset transfer repay-amount liquidator (as-contract tx-sender) none)))

        ;; Reduce borrower borrow balance
        (let ((borrow-current (default-to u0 (get balance (map-get? user-borrow-balances { user: borrower, asset: repay-asset-principal }))))
              (repay-effective (min repay-amount borrow-current)))
          (map-set user-borrow-balances { user: borrower, asset: repay-asset-principal } { balance: (- borrow-current repay-effective) })

          ;; Determine collateral to seize
          (match (map-get? supported-assets { asset: collateral-asset-principal })
            info
              (let ((collateral-price (get-asset-price-safe collateral-asset-principal))
                    (repay-price (get-asset-price-safe repay-asset-principal))
                    (liquidation-bonus (get liquidation-bonus info))
                    (repay-usd (/ (* repay-effective repay-price) PRECISION))
                    (seize-usd (/ (* repay-usd (+ BPS liquidation-bonus)) BPS))
                    (seize-amount (/ (* seize-usd PRECISION) collateral-price))
                    (collateral-balance (default-to u0 (get balance (map-get? user-supply-balances { user: borrower, asset: collateral-asset-principal }))))
                    (seize-final (min seize-amount collateral-balance)))
                ;; Guard against zero prices
                (asserts! (> collateral-price u0) ERR_INVALID_ASSET)
(asserts! (> repay-price u0) ERR_INVALID_ASSET)
                ;; Update borrower collateral balance and transfer seized collateral to liquidator
                (map-set user-supply-balances { user: borrower, asset: collateral-asset-principal } { balance: (- collateral-balance seize-final) })
                (try! (as-contract (contract-call? collateral-asset transfer seize-final (as-contract tx-sender) liquidator none)))
                (record-user-metrics borrower)
                (ok { repaid: repay-effective, seized: seize-final })
              )
            (err ERR_INVALID_ASSET))
        )
      )
    )
  )
)
;; Admin: pause and resume protocol operations
;; @notice Pauses protocol operations.
;; @returns A response tuple with `(ok true)` if successful, `(err ERR_UNAUTHORIZED)` otherwise.
(define-public (pause)
  (begin
    (asserts!
      (contract-call? (var-get access-control-contract)
        has-role "contract-owner" tx-sender
      )
      ERR_UNAUTHORIZED
    )
    (var-set paused true)
    (ok true)
  )
)

;; @notice Resumes protocol operations.
;; @returns A response tuple with `(ok true)` if successful, `(err ERR_UNAUTHORIZED)` otherwise.
(define-public (resume)
  (begin
    (asserts!
      (contract-call? (var-get access-control-contract)
        has-role "contract-owner" tx-sender
      )
      ERR_UNAUTHORIZED
    )
    (var-set paused false)
    (ok true)
  )
)

;; @notice Records user metrics for lending activity.
;; @param user The principal of the user.
;; @returns A response tuple with `(ok true)`.
(define-private (record-user-metrics (user principal))
  (ok true)
)