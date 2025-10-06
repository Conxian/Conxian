;; all-traits.clar
;; Conxian Protocol - Centralized Trait Definitions
;; All protocol contracts should reference traits from this file
;; Version: 1.0.0

;; =============================================================================
;; TOKEN STANDARDS (SIPs)
;; =============================================================================

;; SIP-010: Fungible Token Standard
(define-trait sip-010-ft-trait
  (
    (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))) (response bool (err uint)))
    (get-balance (account principal) (response uint (err uint)))
    (get-total-supply () (response uint (err uint)))
    (get-decimals () (response uint (err uint)))
    (get-name () (response (string-ascii 32) (err uint)))
    (get-symbol () (response (string-ascii 10) (err uint)))
    (get-token-uri () (response (optional (string-utf8 256)) (err uint)))
  )
)

;; SIP-009: NFT Standard
(define-trait sip-009-nft-trait
  (
    (get-last-token-id () (response uint (err uint)))
    (get-token-uri (token-id uint) (response (optional (string-utf8 256)) (err uint)))
    (get-owner (token-id uint) (response (optional principal) (err uint)))
    (transfer (token-id uint) (sender principal) (recipient principal) (response bool (err uint)))
  )
)

;; =============================================================================
;; CORE TRAITS
;; =============================================================================

;; Ownable Trait - Basic ownership management
(define-trait ownable-trait
  (
    (get-owner () (response principal (err uint)))
    (transfer-ownership (new-owner principal) (response bool (err uint)))
    (renounce-ownership () (response bool (err uint)))
  )
)

;; =============================================================================
;; SECURITY TRAITS
;; =============================================================================

;; Access Control Trait - Role-based access control
(define-trait access-control-trait
  (
    (has-role (account principal) (role uint) (response bool (err uint)))
    (get-admin () (response principal (err uint)))
    (set-admin (new-admin principal) (response bool (err uint)))
    (grant-role (role uint) (account principal) (response bool (err uint)))
    (revoke-role (role uint) (account principal) (response bool (err uint)))
    (renounce-role (role uint) (response bool (err uint)))
    (get-role-name (role uint) (response (string-ascii 64) (err uint)))
    (is-admin (caller principal) (response bool (err uint)))
  )
)

;; Circuit Breaker Trait - Enhanced circuit breaker controls
(define-trait circuit-breaker-trait
  (
    (is-circuit-open () (response bool (err uint)))
    (check-circuit-state (operation (string-ascii 64)) (response bool (err uint)))
    (record-success (operation (string-ascii 64)) (response bool (err uint)))
    (record-failure (operation (string-ascii 64)) (response bool (err uint)))
    (get-failure-rate (operation (string-ascii 64)) (response uint (err uint)))
    (get-circuit-state (operation (string-ascii 64))
      (response
        (tuple
          (state uint)
          (last-checked uint)
          (failure-rate uint)
          (failure-count uint)
          (success-count uint)
        )
        (err uint)
      )
    )
    (set-circuit-state (operation (string-ascii 64)) (state bool) (response bool (err uint)))
    (set-failure-threshold (threshold uint) (response bool (err uint)))
    (set-reset-timeout (timeout uint) (response bool (err uint)))
    (get-admin () (response principal (err uint)))
    (set-admin (new-admin principal) (response bool (err uint)))
    (set-rate-limit (operation (string-ascii 64)) (limit uint) (window uint) (response bool (err uint)))
    (get-rate-limit (operation (string-ascii 64))
      (response
        (tuple
          (limit uint)
          (window uint)
          (current uint)
          (reset-time uint)
        )
        (err uint)
      )
    )
    (batch-record-success (operations (list 20 (string-ascii 64))) (response bool (err uint)))
    (batch-record-failure (operations (list 20 (string-ascii 64))) (response bool (err uint)))
    (get-health-status ()
      (response
        (tuple
          (is_operational bool)
          (total_failure_rate uint)
          (last_checked uint)
          (uptime uint)
          (total_operations uint)
          (failed_operations uint)
        )
        (err uint)
      )
    )
    (set-circuit-mode (mode (optional bool)) (response bool (err uint)))
    (get-circuit-mode () (response (optional bool) (err uint)))
    (emergency-shutdown () (response bool (err uint)))
    (recover-from-shutdown () (response bool (err uint)))
  )
)

;; Monitoring Trait - System monitoring and alerting
(define-trait monitoring-trait
  (
    (log-event (component (string-ascii 32)) (event-type (string-ascii 32)) (severity uint) (message (string-ascii 256)) (data (optional (tuple))) (response bool (err uint)))
    (get-events (component (string-ascii 32)) (limit uint) (offset uint)
      (response (list 100 (tuple (id uint) (event-type (string-ascii 32)) (severity uint) (message (string-ascii 256)) (block-height uint) (data (optional (tuple))))) (err uint)))
    (get-event (event-id uint)
      (response (tuple (id uint) (component (string-ascii 32)) (event-type (string-ascii 32)) (severity uint) (message (string-ascii 256)) (block-height uint) (data (optional (tuple)))) (err uint)))
    (get-health-status (component (string-ascii 32))
      (response (tuple (status uint) (last-updated uint) (uptime uint) (error-count uint) (warning-count uint)) (err uint)))
    (set-alert-threshold (component (string-ascii 32)) (alert-type (string-ascii 32)) (threshold uint) (response bool (err uint)))
    (get-admin () (response principal (err uint)))
    (set-admin (new-admin principal) (response bool (err uint)))
  )
)

;; Pausable Trait - Standard pause controls
(define-trait pausable-trait
  (
    (pause () (response bool (err uint)))
    (unpause () (response bool (err uint)))
    (is-paused () (response bool (err uint)))
    (when-not-paused () (response bool (err uint)))
    (when-paused () (response bool (err uint)))
  )
)

;; Compliance Hooks Trait - Pre/post transfer hooks
(define-trait compliance-hooks-trait
  (
    (before-transfer (sender principal) (recipient principal) (amount uint) (memo (optional (buff 34))) (response bool (err uint)))
    (after-transfer (sender principal) (recipient principal) (amount uint) (memo (optional (buff 34))) (response bool (err uint)))
  )
)

;; MEV Protector Trait - Front-running protection
(define-trait mev-protector-trait
  (
    (check-front-running (tx-hash (buff 32)) (block-height uint) (response bool (err uint)))
    (record-transaction (tx-hash (buff 32)) (block-height uint) (amount uint) (response bool (err uint)))
    (is-protected (user principal) (response bool (err uint)))
  )
)

;; =============================================================================
;; DEFI TRAITS
;; =============================================================================

;; Pool Trait - AMM Pool Interface
(define-trait pool-trait
  (
    (add-liquidity (amount-a uint) (amount-b uint) (recipient principal) (response (tuple (tokens-minted uint) (token-a-used uint) (token-b-used uint)) (err uint)))
    (remove-liquidity (amount uint) (recipient principal) (response (tuple (token-a-returned uint) (token-b-returned uint)) (err uint)))
    (swap (token-in principal) (amount-in uint) (recipient principal) (response uint (err uint)))
    (get-reserves () (response (tuple (reserve-a uint) (reserve-b uint)) (err uint)))
    (get-total-supply () (response uint (err uint)))
  )
)

;; Factory Trait - Pool Factory Interface
(define-trait factory-trait
  (
    (create-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint) (pool-type (string-ascii 64)) (response principal (err uint)))
    (get-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint) (response (optional principal) (err uint)))
    (get-pool-count () (response uint (err uint)))
    (register-pool-implementation (pool-type (string-ascii 64)) (implementation-contract principal) (response bool (err uint)))
  )
)

;; Vault Trait - Yield Vault Interface
(define-trait vault-trait
  (
    (deposit (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))
    (withdraw (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))
    (get-total-shares (token-contract <sip-010-ft-trait>) (response uint (err uint)))
    (get-amount-out-from-shares (token-contract <sip-010-ft-trait>) (shares uint) (response uint (err uint)))
    (get-shares-from-amount-in (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))
    (harvest (token-contract <sip-010-ft-trait>) (response bool (err uint)))
    (set-strategy (token-contract <sip-010-ft-trait>) (strategy-contract principal) (response bool (err uint)))
    (get-strategy (token-contract <sip-010-ft-trait>) (response (optional principal) (err uint)))
    (get-apy (token-contract <sip-010-ft-trait>) (response uint (err uint)))
    (get-tvl (token-contract <sip-010-ft-trait>) (response uint (err uint)))
  )
)

;; Strategy Trait - Yield Strategy Interface
(define-trait strategy-trait
  (
    (deposit (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))
    (withdraw (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))
    (harvest () (response bool (err uint)))
    (rebalance () (response bool (err uint)))
    (get-apy () (response uint (err uint)))
    (get-tvl () (response uint (err uint)))
    (get-underlying-token () (response principal (err uint)))
    (get-vault () (response principal (err uint)))
  )
)

;; Staking Trait - Staking Interface
(define-trait staking-trait
  (
    (stake (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))
    (unstake (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))
    (claim-rewards (token-contract <sip-010-ft-trait>) (response uint (err uint)))
    (get-staked-balance (token-contract <sip-010-ft-trait>) (user principal) (response uint (err uint)))
    (get-available-rewards (token-contract <sip-010-ft-trait>) (user principal) (response uint (err uint)))
    (get-total-staked (token-contract <sip-010-ft-trait>) (response uint (err uint)))
    (set-reward-rate (token-contract <sip-010-ft-trait>) (rate uint) (response bool (err uint)))
    (get-reward-rate (token-contract <sip-010-ft-trait>) (response uint (err uint)))
  )
)

;; Lending System Trait - Lending Protocol Interface
(define-trait lending-system-trait
  (
    (deposit (asset principal) (amount uint) (response bool (err uint)))
    (withdraw (asset principal) (amount uint) (response bool (err uint)))
    (borrow (asset principal) (amount uint) (response bool (err uint)))
    (repay (asset principal) (amount uint) (response bool (err uint)))
    (liquidate (liquidator principal) (borrower principal) (repay-asset principal) (collateral-asset principal) (repay-amount uint) (response bool (err uint)))
    (get-account-liquidity (user principal) (response (tuple (liquidity uint) (shortfall uint)) (err uint)))
    (get-asset-price (asset principal) (response uint (err uint)))
    (get-borrow-rate (asset principal) (response uint (err uint)))
    (get-supply-rate (asset principal) (response uint (err uint)))
  )
)

;; =============================================================================
;; MATH TRAITS
;; =============================================================================

;; Math Trait - Mathematical Operations
(define-trait math-trait
  (
    ;; Basic arithmetic
    (add (a uint) (b uint) (response uint (err uint)))
    (sub (a uint) (b uint) (response uint (err uint)))
    (mul (a uint) (b uint) (response uint (err uint)))
    (div (a uint) (b uint) (response uint (err uint)))
    (pow (base uint) (exp uint) (response uint (err uint)))
    (sqrt (a uint) (response uint (err uint)))
    
    ;; Percentages and ratios
    (get-percentage (value uint) (percentage uint) (response uint (err uint)))
    (get-ratio (numerator uint) (denominator uint) (response uint (err uint)))
    
    ;; Min/Max
    (min (a uint) (b uint) (response uint (err uint)))
    (max (a uint) (b uint) (response uint (err uint)))
    
    ;; Absolute value
    (abs (a int) (response uint (err uint)))
    
    ;; Rounding
    (ceil (a uint) (b uint) (response uint (err uint)))
    (floor (a uint) (b uint) (response uint (err uint)))
    
    ;; Logarithms
    (log2 (a uint) (response uint (err uint)))
    (log10 (a uint) (response uint (err uint)))
    (ln (a uint) (response uint (err uint)))
    
    ;; Exponentials
    (exp (a uint) (response uint (err uint)))
    
    ;; Statistical functions
    (average (a uint) (b uint) (response uint (err uint)))
    (weighted-average (value1 uint) (weight1 uint) (value2 uint) (weight2 uint) (response uint (err uint)))
    (geometric-mean (a uint) (b uint) (response uint (err uint)))
    (std-dev (values (list 100 uint)) (response uint (err uint)))
    
    ;; Interpolation
    (linear-interpolate (x uint) (x0 uint) (y0 uint) (x1 uint) (y1 uint) (response uint (err uint)))
    
    ;; Fixed-point arithmetic
    (fpow (base uint) (exp uint) (precision uint) (response uint (err uint)))
    (fsqrt (a uint) (precision uint) (response uint (err uint)))
    (fmul (a uint) (b uint) (precision uint) (response uint (err uint)))
    (fdiv (a uint) (b uint) (precision uint) (response uint (err uint)))
  )
)

;; =============================================================================
;; ADDITIONAL TRAITS
;; =============================================================================

;; Governance Traits
(define-trait dao-trait
  (
    (has-voting-power (voter principal) (response bool (err uint)))
    (get-voting-power (voter principal) (response uint (err uint)))
    (get-total-voting-power () (response uint (err uint)))
    (delegate (delegatee principal) (response bool (err uint)))
    (undelegate () (response bool (err uint)))
    (execute-proposal (proposal-id uint) (response bool (err uint)))
    (vote (proposal-id uint) (support bool) (response bool (err uint)))
    (get-proposal (proposal-id uint)
      (response (tuple (proposer principal) (start-block uint) (end-block uint) (votes-for uint) (votes-against uint) (executed bool) (canceled bool)) (err uint))
    )
  )
)

(define-trait governance-token-trait
  (
    (delegate (delegatee principal) (response bool (err uint)))
    (get-voting-power (account principal) (response uint (err uint)))
    (get-prior-votes (account principal) (block-height uint) (response uint (err uint)))
  )
)

;; DeFi Traits (additional)
(define-trait bond-trait
  (
    (issue-bond (name (string-ascii 32)) (symbol (string-ascii 10)) (decimals uint) (initial-supply uint) (maturity-in-blocks uint) (coupon-rate-scaled uint) (frequency-in-blocks uint) (bond-face-value uint) (payment-token-address principal) (response bool (err uint)))
    (claim-coupons (payment-token principal) (response uint (err uint)))
    (redeem-at-maturity (payment-token principal) (response (tuple (principal uint) (coupon uint)) (err uint)))
    (get-payment-token-contract () (response (optional principal) (err uint)))
  )
)

(define-trait router-trait
  (
    (swap-exact-tokens-for-tokens (amount-in uint) (path (list 10 principal)) (recipient principal) (deadline uint) (response (list 10 uint) (err uint)))
    (swap-tokens-for-exact-tokens (amount-out uint) (path (list 10 principal)) (recipient principal) (deadline uint) (response (list 10 uint) (err uint)))
    (get-amounts-out (amount-in uint) (path (list 10 principal)) (response (list 10 uint) (err uint)))
    (get-amounts-in (amount-out uint) (path (list 10 principal)) (response (list 10 uint) (err uint)))
  )
)

(define-trait pool-creation-trait
  (
    (create-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint) (pool-type (string-ascii 64)) (response principal (err uint)))
    (get-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint) (response (optional principal) (err uint)))
    (get-all-pools () (response (list 100 (tuple (token-a principal) (token-b principal) (fee-bps uint) (pool-address principal) (pool-type (string-ascii 64)))) (err uint)))
    (set-pool-implementation (pool-type (string-ascii 64)) (implementation-contract principal) (response bool (err uint)))
    (get-pool-implementation (pool-type (string-ascii 64)) (response (optional principal) (err uint)))
  )
)

(define-trait yield-optimizer-trait
  (
    (deposit (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))
    (withdraw (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))
    (get-total-shares (token-contract <sip-010-ft-trait>) (response uint (err uint)))
    (get-amount-out-from-shares (token-contract <sip-010-ft-trait>) (shares uint) (response uint (err uint)))
    (get-shares-from-amount-in (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))
    (rebalance-strategy (token-contract <sip-010-ft-trait>) (response bool (err uint)))
    (set-strategy (token-contract <sip-010-ft-trait>) (strategy-contract principal) (response bool (err uint)))
    (get-strategy (token-contract <sip-010-ft-trait>) (response (optional principal) (err uint)))
    (get-apy (token-contract <sip-010-ft-trait>) (response uint (err uint)))
    (get-tvl (token-contract <sip-010-ft-trait>) (response uint (err uint)))
  )
)

(define-trait vault-admin-trait
  (
    (set-deposit-fee (fee-bps uint) (response bool (err uint)))
    (set-withdrawal-fee (fee-bps uint) (response bool (err uint)))
    (set-vault-cap (token-contract principal) (cap uint) (response bool (err uint)))
    (set-paused (paused-status bool) (response bool (err uint)))
    (emergency-withdraw (token-contract principal) (amount uint) (recipient principal) (response uint (err uint)))
    (rebalance-vault (token-contract principal) (response bool (err uint)))
    (set-revenue-share (share-bps uint) (response bool (err uint)))
    (update-integration-settings (settings (tuple (monitor-enabled bool) (emission-enabled bool))) (response bool (err uint)))
    (transfer-admin (new-admin principal) (response bool (err uint)))
    (get-admin () (response principal (err uint)))
  )
)

(define-trait asset-vault-trait
  (
    (deposit (token <sip-010-ft-trait>) (amount uint) (response uint (err uint)))
    (withdraw (token <sip-010-ft-trait>) (amount uint) (response uint (err uint)))
    (get-balance (token <sip-010-ft-trait>) (user principal) (response uint (err uint)))
    (get-total-assets (token <sip-010-ft-trait>) (response uint (err uint)))
  )
)

(define-trait fee-manager-trait
  (
    (get-fee-rate (pool principal) (tier uint) (response uint (err uint)))
    (set-fee-rate (pool principal) (tier uint) (rate uint) (response bool (err uint)))
    (collect-fees (pool principal) (response uint (err uint)))
    (distribute-fees (pool principal) (amount uint) (response bool (err uint)))
  )
)

(define-trait flash-loan-receiver-trait
  (
    (execute-flash-loan (token-contract <sip-010-ft-trait>) (amount uint) (initiator principal) (data (optional (buff 256))) (response bool (err uint)))
  )
)

(define-trait liquidation-trait
  (
    (is-liquidatable (user principal) (debt-asset principal) (collateral-asset principal) (response bool (err uint)))
    (liquidate-position (borrower principal) (debt-asset principal) (collateral-asset principal) (debt-amount uint) (max-collateral-amount uint) (response (tuple (debt-repaid uint) (collateral-seized uint)) (err uint)))
    (liquidate-multiple-positions (positions (list 10 (tuple (borrower principal) (debt-asset principal) (collateral-asset principal) (debt-amount uint)))) (response (tuple (success-count uint) (total-debt-repaid uint) (total-collateral-seized uint)) (err uint)))
    (calculate-liquidation-amounts (borrower principal) (debt-asset principal) (collateral-asset principal) (response (tuple (debt-value uint) (collateral-value uint)) (err uint)))
    (emergency-liquidate (borrower principal) (debt-asset principal) (collateral-asset principal) (response bool (err uint)))
  )
)

(define-trait liquidity-manager-trait
  (
    (get-utilization () (response uint (err uint)))
    (get-yield-rate () (response uint (err uint)))
    (get-risk-score () (response uint (err uint)))
    (get-performance-score () (response uint (err uint)))
    (rebalance-liquidity (threshold uint) (response bool (err uint)))
    (trigger-emergency-rebalance () (response bool (err uint)))
  )
)

(define-trait performance-optimizer-trait
  (
    (optimize-strategy (strategy principal) (response bool (err uint)))
    (get-performance-metrics (strategy principal) (response (tuple (apy uint) (tvl uint) (efficiency uint)) (err uint)))
    (rebalance (strategy principal) (response bool (err uint)))
  )
)

;; Protocol Traits
(define-trait oracle-trait
  (
    (get-price (asset principal) (response uint (err uint)))
  )
)

(define-trait oracle-aggregator-trait
  (
    (add-oracle-feed (token principal) (feed principal) (response bool (err uint)))
    (remove-oracle-feed (token principal) (feed principal) (response bool (err uint)))
    (get-aggregated-price (token principal) (response uint (err uint)))
    (get-feed-count (token principal) (response uint (err uint)))
  )
)

(define-trait btc-adapter-trait
  (
    (wrap-btc (amount uint) (btc-tx-id (buff 32)) (response uint (err uint)))
    (unwrap-btc (amount uint) (btc-address (buff 64)) (response bool (err uint)))
    (get-wrapped-balance (user principal) (response uint (err uint)))
  )
)

(define-trait cross-protocol-trait
  (
    (bridge-assets (from-token <sip-010-ft-trait>) (to-protocol (string-ascii 64)) (amount uint) (response uint (err uint)))
    (get-bridge-status (tx-id (buff 32)) (response (tuple (status (string-ascii 32)) (amount uint)) (err uint)))
  )
)

(define-trait cxlp-migration-queue-trait
  (
    (enqueue-migration (user principal) (amount uint) (response uint (err uint)))
    (process-migration (queue-id uint) (response bool (err uint)))
    (get-queue-position (queue-id uint) (response uint (err uint)))
    (cancel-migration (queue-id uint) (response bool (err uint)))
  )
)

(define-trait legacy-adapter-trait
  (
    (migrate-from-legacy (legacy-contract principal) (amount uint) (response bool (err uint)))
    (get-legacy-balance (user principal) (legacy-contract principal) (response uint (err uint)))
  )
)

;; Dimensional Traits
(define-trait position-nft-trait
  (
    (mint (recipient principal) (liquidity uint) (tick-lower int) (tick-upper int) (response uint (err uint)))
    (burn (token-id uint) (response bool (err uint)))
    (get-position (token-id uint) (response (tuple (owner principal) (liquidity uint) (tick-lower int) (tick-upper int)) (err uint)))
    (trigger-emergency-rebalance () (response bool (err uint)))
    (rebalance-liquidity (threshold uint) (response bool (err uint)))
  )
)

(define-trait dim-registry-trait
  (
    (register-dimension (name (string-ascii 64)) (description (string-utf8 256)) (response uint (err uint)))
    (get-dimension (dim-id uint) (response (tuple (name (string-ascii 64)) (description (string-utf8 256)) (active bool)) (err uint)))
    (update-dimension-status (dim-id uint) (active bool) (response bool (err uint)))
    (get-dimension-count () (response uint (err uint)))
  )
)

(define-trait dimensional-oracle-trait
  (
    (get-price (asset principal) (response uint (err uint)))
    (update-price (asset principal) (price uint) (response bool (err uint)))
    (add-price-feed (asset principal) (source principal) (response bool (err uint)))
    (remove-price-feed (asset principal) (response bool (err uint)))
  )
)

;; Additional SIP Traits
(define-trait sip-018-trait
  (
    (transfer (token-id uint) (amount uint) (sender principal) (recipient principal) (response bool (err uint)))
    (transfer-memo (token-id uint) (amount uint) (sender principal) (recipient principal) (memo (buff 34)) (response bool (err uint)))
    (get-balance (token-id uint) (user principal) (response uint (err uint)))
    (get-overall-balance (user principal) (response uint (err uint)))
    (get-total-supply (token-id uint) (response uint (err uint)))
    (get-overall-supply () (response uint (err uint)))
    (get-decimals (token-id uint) (response uint (err uint)))
    (get-token-uri (token-id uint) (response (optional (string-utf8 256)) (err uint)))
  )
)

(define-trait sip-010-ft-mintable-trait
  (
    (mint (amount uint) (recipient principal) (response bool (err uint)))
    (burn (amount uint) (owner principal) (response bool (err uint)))
    (get-token-uri () (response (optional (string-utf8 256)) (err uint)))
  )
)

;; Core Utilities Traits
(define-trait migration-manager-trait
  (
    (initiate-migration (from-token <sip-010-ft-trait>) (to-token <sip-010-ft-trait>) (amount uint) (response bool (err uint)))
    (complete-migration (migration-id uint) (response bool (err uint)))
    (get-migration-status (migration-id uint) (response (tuple (status (string-ascii 32)) (from-amount uint) (to-amount uint)) (err uint)))
  )
)

(define-trait metrics-trait
  (
    (get-apy (strategy principal) (response uint (err uint)))
    (get-yield-efficiency (strategy principal) (response uint (err uint)))
    (get-vault-performance (strategy principal) (response uint (err uint)))
  )
)

(define-trait error-codes-trait
  (
    (get-error-message (error-code uint) (response (string-ascii 256) (err uint)))
    (is-valid-error (error-code uint) (response bool (err uint)))
  )
)

(define-trait standard-constants-trait
  (
    (get-precision () (response uint (err uint)))
    (get-basis-points () (response uint (err uint)))
    (get-blocks-per-minute () (response uint (err uint)))
    (get-blocks-per-hour () (response uint (err uint)))
    (get-blocks-per-day () (response uint (err uint)))
    (get-blocks-per-week () (response uint (err uint)))
    (get-blocks-per-year () (response uint (err uint)))
    (get-max-bps () (response uint (err uint)))
    (get-one-hundred-percent () (response uint (err uint)))
    (get-fifty-percent () (response uint (err uint)))
    (get-zero () (response uint (err uint)))
    (get-precision-18 () (response uint (err uint)))
    (get-precision-8 () (response uint (err uint)))
    (get-precision-6 () (response uint (err uint)))
  )
)

(define-trait utils-trait
  (
    (principal-to-buff (p principal) (response (buff 32) (err uint)))
  )
)

;; Math (Fixed-Point)
(define-trait fixed-point-math-trait
  (
    (mul-fixed (a uint) (b uint) (precision uint) (response uint (err uint)))
    (div-fixed (a uint) (b uint) (precision uint) (response uint (err uint)))
    (pow-fixed (base uint) (exp uint) (precision uint) (response uint (err uint)))
    (sqrt-fixed (a uint) (precision uint) (response uint (err uint)))
  )
)

;; =============================================================================
;; ERROR CODES
;; =============================================================================

;; Standard error codes for all contracts
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_INVALID_ROLE u101)
(define-constant ERR_ROLE_ALREADY_GRANTED u102)
(define-constant ERR_PAUSED u200)
(define-constant ERR_NOT_PAUSED u201)
(define-constant ERR_INVALID_PARAMS u300)
(define-constant ERR_INSUFFICIENT_BALANCE u301)
(define-constant ERR_SLIPPAGE_TOO_HIGH u302)

;; =============================================================================
;; USAGE NOTES
;; =============================================================================

;; To use traits from this file in your contracts:
;;
;; 1. Import the trait:
;;    (use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
;;
;; 2. Implement the trait:
;;    (impl-trait .all-traits.sip-010-ft-trait)
;;
;; 3. Use trait types in function parameters:
;;    (define-public (my-function (token <sip-010-ft-trait>)) ...)
;;
;; Note: The relative path `.all-traits` assumes the contract is deployed
;; by the same principal. For cross-principal references, use full principal.

