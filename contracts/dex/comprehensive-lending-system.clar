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
;; Proof of Reserves integration errors
(define-constant ERR_POR_STALE (err u1020))
(define-constant ERR_POR_MISSING (err u1021))
(define-constant PRECISION u1000000000000000000) ;; 1e18
(define-constant BPS u10000) ;; basis points scale

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

;; --- Admin Setters ---
(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set oracle-contract oracle)
    (ok true)
  )
)

(define-public (set-interest-rate-model (irm principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set interest-rate-model-contract irm)
    (ok true)
  )
)

(define-public (set-liquidation-manager (lm principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set loan-liquidation-manager-contract lm)
    (ok true)
  )
)

(define-public (set-access-control (ac principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set access-control-contract ac)
    (ok true)
  )
)

(define-public (set-circuit-breaker (cb principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set circuit-breaker-contract (some cb))
    (ok true)
  )
)
;; Configure Proof of Reserves enforcement
(define-public (set-proof-of-reserves (por principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set por-contract (some por))
    (ok true)
  )
)

(define-public (set-enforce-por-borrow (flag bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set enforce-por-borrow flag)
    (ok true)
  )
)
;; Monitoring and risk parameter setters
(define-public (set-monitoring (mc principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set monitoring-contract (some mc))
    (ok true)
  )
)

(define-public (set-risk-params (buffer-bps uint) (min-hf uint) (alert-thr-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
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
(define-public (add-supported-asset (asset principal) (collateral-factor uint) (liquidation-threshold uint) (liquidation-bonus uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (<= collateral-factor BPS) ERR_INVALID_TUPLE)
    (asserts! (and (>= liquidation-threshold u5000) (<= liquidation-threshold BPS)) ERR_INVALID_TUPLE)
    (asserts! (<= liquidation-bonus u2000) ERR_INVALID_TUPLE)
    (map-set supported-assets { asset: asset } { collateral-factor: collateral-factor, liquidation-threshold: liquidation-threshold, liquidation-bonus: liquidation-bonus })
    (let ((current (var-get supported-asset-list)))
      (asserts! (< (len current) u100) ERR_INSUFFICIENT_LIQUIDITY)
      (var-set supported-asset-list (concat current (list asset)))
      (ok true)
    )
  )
)

;; Admin: remove an asset from supported list
(define-public (remove-supported-asset (asset principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
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
  (fold
    (lambda (a acc)
      (if (is-eq a target) acc (concat acc (list a)))
    )
    assets
    (list))
)

;; --- Private Helper Functions ---
(define-private (check-is-owner) 
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)))

(define-private (check-not-paused) 
  (ok (asserts! (not (var-get paused)) ERR_PAUSED)))

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
            (+ total-value (/ (* balance (get collateral-factor asset-info) price) (* PRECISION PRECISION))))
        total-value)
      total-value)))

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
      ;; Optional PoR enforcement: require attestation exists and is not stale
      (match (var-get por-contract)
        por-addr (if (var-get enforce-por-borrow)
                      (begin
                        (asserts! (is-some (contract-call? por-addr get-attestation asset-principal)) ERR_POR_MISSING)
                        (asserts! (not (contract-call? por-addr is-stale asset-principal)) ERR_POR_STALE)
                        true)
                      true)
        true)
      (try! (accrue-interest asset-principal))
      (let ((current-balance (default-to u0 (get balance (map-get? user-supply-balances { user: tx-sender, asset: asset-principal })))))
        (asserts! (>= current-balance amount) ERR_INSUFFICIENT_LIQUIDITY)
        (map-set user-supply-balances { user: tx-sender, asset: asset-principal } { balance: (- current-balance amount) })
        (let ((health (try! (get-health-factor tx-sender))))
          (asserts! (>= health (var-get min-health-factor-precision)) ERR_INSUFFICIENT_COLLATERAL)
          (try! (as-contract (contract-call? asset transfer amount (as-contract tx-sender) tx-sender none)))
          (record-user-metrics tx-sender)
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
        (let ((buffer (var-get borrow-safety-buffer-bps))
              (max-allowed (/ (* collateral-value (- BPS buffer)) BPS)))
          (asserts! (>= max-allowed new-borrow-value) ERR_INSUFFICIENT_COLLATERAL))
        (let ((current-borrow (default-to u0 (get balance (map-get? user-borrow-balances { user: tx-sender, asset: asset-principal })))))
          (map-set user-borrow-balances { user: tx-sender, asset: asset-principal } { balance: (+ current-borrow amount) })
          (try! (as-contract (contract-call? asset transfer amount (as-contract tx-sender) tx-sender none)))
          (record-user-metrics tx-sender)
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
        (record-user-metrics tx-sender)
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
                (asserts! (> collateral-price u0) ERR_INVALID_TUPLE)
                (asserts! (> repay-price u0) ERR_INVALID_TUPLE)
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
(define-public (pause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set paused true)
    (ok true)
  )
)

(define-public (resume)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set paused false)
    (ok true)
  )
)