;; all-traits.clar
;; Conxian Protocol - Centralized Trait Definitions
;; All protocol contracts should reference traits from this file
;; =============================================================================
;; TOKEN STANDARDS (SIPs)
;; =============================================================================

;; SIP-010: Fungible Token Standard
(use-trait sip_010_ft_trait .all-traits.sip-010-ft-trait)
-trait sip-010-ft-trait
  (
    (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))) (response bool uint))
    (get-balance (account principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-decimals () (response uint uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; SIP-009: Non-Fungible Token Standard
(define-trait sip-009-nft-trait
  (
    (get-last-token-id () (response uint uint))
    (get-token-uri (token-id uint) (response (optional (string-ascii 256)) uint))
    (get-owner (token-id uint) (response (optional principal) uint))
    (transfer (token-id uint) (sender principal) (recipient principal) (response bool uint))
  )
)

;; =============================================================================
;; CORE TRAITS
;; =============================================================================

;; Ownable Trait - Basic ownership management
(define-trait ownable-trait
  (
    (get-owner () (response principal uint))
    (transfer-ownership (new-owner principal) (response bool uint))
    (renounce-ownership () (response bool uint))
  )
)

;; =============================================================================
;; SECURITY TRAITS
;; =============================================================================

;; Access Control Trait - Role-based access control
(define-trait access-control-trait
  (
    (has-role (account principal) (role uint) (response bool uint))
    (get-admin () (response principal uint))
    (set-admin (new-admin principal) (response bool uint))
    (grant-role (role uint) (account principal) (response bool uint))
    (revoke-role (role uint) (account principal) (response bool uint))
    (renounce-role (role uint) (response bool uint))
    (get-role-name (role uint) (response (string-ascii 64) uint))
    (is-admin (caller principal) (response bool uint))
  )
)

;; Circuit Breaker Trait - Enhanced circuit breaker controls
(define-trait circuit-breaker-trait
  (
    (is-circuit-open () (response bool uint))
    (check-circuit-state (operation (string-ascii 64)) (response bool uint))
    (record-success (operation (string-ascii 64)) (response bool uint))
    (record-failure (operation (string-ascii 64)) (response bool uint))
    (get-failure-rate (operation (string-ascii 64)) (response uint uint))
    (get-circuit-state (operation (string-ascii 64))
      (response
        (tuple
          (state uint)
          (last-checked uint)
          (failure-rate uint)
          (failure-count uint)
          (success-count uint)
        )
        uint
      )
    )
    (set-circuit-state (operation (string-ascii 64)) (state bool) (response bool uint))
    (set-failure-threshold (threshold uint) (response bool uint))
    (set-reset-timeout (timeout uint) (response bool uint))
    (get-admin () (response principal uint))
    (set-admin (new-admin principal) (response bool uint))
    (set-rate-limit (operation (string-ascii 64)) (limit uint) (window uint) (response bool uint))
    (get-rate-limit (operation (string-ascii 64))
      (response
        (tuple
          (limit uint)
          (window uint)
          (current uint)
          (reset-time uint)
        )
        uint
      )
    )
    (batch-record-success (operations (list 20 (string-ascii 64))) (response bool uint))
    (batch-record-failure (operations (list 20 (string-ascii 64))) (response bool uint))
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
        uint
      )
    )
    (set-circuit-mode (mode (optional bool)) (response bool uint))
    (get-circuit-mode () (response (optional bool) uint))
    (emergency-shutdown () (response bool uint))
    (recover-from-shutdown () (response bool uint))
  )
)

;; Monitoring Trait - System monitoring and alerting
(define-trait monitoring-trait
  (
    (log-event (component (string-ascii 32)) (event-type (string-ascii 32)) (severity uint) (message (string-ascii 256)) (data (optional (buff 256))) (response bool uint))
    (get-events (component (string-ascii 32)) (limit uint) (offset uint)
      (response (list 100 (tuple (id uint) (event-type (string-ascii 32)) (severity uint) (message (string-ascii 256)) (block-height uint) (data (optional (buff 256))))) uint))
    (get-event (event-id uint)
      (response (tuple (id uint) (component (string-ascii 32)) (event-type (string-ascii 32)) (severity uint) (message (string-ascii 256)) (block-height uint) (data (optional (buff 256)))) uint))
    (get-health-status (component (string-ascii 32))
      (response (tuple (status uint) (last-updated uint) (uptime uint) (error-count uint) (warning-count uint)) uint))
    (set-alert-threshold (component (string-ascii 32)) (alert-type (string-ascii 32)) (threshold uint) (response bool uint))
    (get-admin () (response principal uint))
    (set-admin (new-admin principal) (response bool uint))
  )
)

;; Pausable Trait - Standard pause controls
(define-trait pausable-trait
  (
    (pause () (response bool uint))
    (unpause () (response bool uint))
    (is-paused () (response bool uint))
    (when-not-paused () (response bool uint))
    (when-paused () (response bool uint))
  )
)

;; Compliance Hooks Trait - Pre/post transfer hooks
(define-trait compliance-hooks-trait
  (
    (before-transfer (sender principal) (recipient principal) (amount uint) (memo (optional (buff 34))) (response bool uint))
    (after-transfer (sender principal) (recipient principal) (amount uint) (memo (optional (buff 34))) (response bool uint))
  )
)

;; MEV Protector Trait - Front-running protection
(define-trait mev-protector-trait
  (
    (check-front-running (tx-hash (buff 32)) (block-height uint) (response bool uint))
    (record-transaction (tx-hash (buff 32)) (block-height uint) (amount uint) (response bool uint))
    (is-protected (user principal) (response bool uint))
  )
)

;; =============================================================================
;; DEFI TRAITS
;; =============================================================================

;; Pool Trait - AMM Pool Interface
(define-trait pool-trait
  (
    (add-liquidity (amount-a uint) (amount-b uint) (recipient principal) (response (tuple (tokens-minted uint) (token-a-used uint) (token-b-used uint)) uint))
    (remove-liquidity (amount uint) (recipient principal) (response (tuple (token-a-returned uint) (token-b-returned uint)) uint))
    (swap (token-in principal) (amount-in uint) (recipient principal) (response uint uint))
    (get-reserves () (response (tuple (reserve-a uint) (reserve-b uint)) uint))
    (get-total-supply () (response uint uint))
  )
)

;; Factory Trait - Pool Factory Interface
(define-trait factory-trait
  (
    (create-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint) (pool-type (string-ascii 64)) (response principal uint))
    (get-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint) (response (optional principal) uint))
    (get-pool-count () (response uint uint))
    (register-pool-implementation (pool-type (string-ascii 64)) (implementation-contract principal) (response bool uint))
  )
)

;; Vault Trait - Yield Vault Interface
(define-trait vault-trait
  (
    (deposit (token-contract <sip-010-ft-trait>) (amount uint) (response uint uint))
    (withdraw (token-contract <sip-010-ft-trait>) (amount uint) (response uint uint))
    (get-total-shares (token-contract <sip-010-ft-trait>) (response uint uint))
    (get-amount-out-from-shares (token-contract <sip-010-ft-trait>) (shares uint) (response uint uint))
    (get-shares-from-amount-in (token-contract <sip-010-ft-trait>) (amount uint) (response uint uint))
    (harvest (token-contract <sip-010-ft-trait>) (response bool uint))
    (set-strategy (token-contract <sip-010-ft-trait>) (strategy-contract principal) (response bool uint))
    (get-strategy (token-contract <sip-010-ft-trait>) (response (optional principal) uint))
    (get-apy (token-contract <sip-010-ft-trait>) (response uint uint))
    (get-tvl (token-contract <sip-010-ft-trait>) (response uint uint))
  )
)

;; Strategy Trait - Yield Strategy Interface
(define-trait strategy-trait
  (
    (deposit (token-contract <sip-010-ft-trait>) (amount uint) (response uint uint))
    (withdraw (token-contract <sip-010-ft-trait>) (amount uint) (response uint uint))
    (harvest () (response bool uint))
    (rebalance () (response bool uint))
    (get-apy () (response uint uint))
    (get-tvl () (response uint uint))
    (get-underlying-token () (response principal uint))
    (get-vault () (response principal uint))
  )
)

;; Staking Trait - Staking Interface
(define-trait staking-trait
  (
    (stake (token-contract <sip-010-ft-trait>) (amount uint) (response uint uint))
    (unstake (token-contract <sip-010-ft-trait>) (amount uint) (response uint uint))
    (claim-rewards (token-contract <sip-010-ft-trait>) (response uint uint))
    (get-staked-balance (token-contract <sip-010-ft-trait>) (user principal) (response uint uint))
    (get-available-rewards (token-contract <sip-010-ft-trait>) (user principal) (response uint uint))
    (get-total-staked (token-contract <sip-010-ft-trait>) (response uint uint))
    (set-reward-rate (token-contract <sip-010-ft-trait>) (rate uint) (response bool uint))
    (get-reward-rate (token-contract <sip-010-ft-trait>) (response uint uint))
  )
)

;; Lending System Trait - Lending Protocol Interface
(define-trait lending-system-trait
  (
    (deposit (asset principal) (amount uint) (response bool uint))
    (withdraw (asset principal) (amount uint) (response bool uint))
    (borrow (asset principal) (amount uint) (response bool uint))
    (repay (asset principal) (amount uint) (response bool uint))
    (liquidate (liquidator principal) (borrower principal) (repay-asset principal) (collateral-asset principal) (repay-amount uint) (response bool uint))
    (get-account-liquidity (user principal) (response (tuple (liquidity uint) (shortfall uint)) uint))
    (get-asset-price (asset principal) (response uint uint))
    (get-borrow-rate (asset principal) (response uint uint))
    (get-supply-rate (asset principal) (response uint uint))
  )
)

;; =============================================================================
;; MATH TRAITS
;; =============================================================================

;; Math Trait - Mathematical Operations
(define-trait math-trait
  (
    ;; Basic arithmetic
    (add (a uint) (b uint) (response uint uint))
    (sub (a uint) (b uint) (response uint uint))
    (mul (a uint) (b uint) (response uint uint))
    (div (a uint) (b uint) (response uint uint))
    (pow (base uint) (exp uint) (response uint uint))
    (sqrt (a uint) (response uint uint))
    
    ;; Percentages and ratios
    (get-percentage (value uint) (percentage uint) (response uint uint))
    (get-ratio (numerator uint) (denominator uint) (response uint uint))
    
    ;; Min/Max
    (min (a uint) (b uint) (response uint uint))
    (max (a uint) (b uint) (response uint uint))
    
    ;; Absolute value
    (abs (a int) (response uint uint))
    
    ;; Rounding
    (ceil (a uint) (b uint) (response uint uint))
    (floor (a uint) (b uint) (response uint uint))
    
    ;; Logarithms
    (log2 (a uint) (response uint uint))
    (log10 (a uint) (response uint uint))
    (ln (a uint) (response uint uint))
    
    ;; Exponentials
    (exp (a uint) (response uint uint))
    
    ;; Statistical functions
    (average (a uint) (b uint) (response uint uint))
    (weighted-average (value1 uint) (weight1 uint) (value2 uint) (weight2 uint) (response uint uint))
    (geometric-mean (a uint) (b uint) (response uint uint))
    (std-dev (values (list 100 uint)) (response uint uint))
    
    ;; Interpolation
    (linear-interpolate (x uint) (x0 uint) (y0 uint) (x1 uint) (y1 uint) (response uint uint))
    
    ;; Fixed-point arithmetic
    (fpow (base uint) (exp uint) (precision uint) (response uint uint))
    (fsqrt (a uint) (precision uint) (response uint uint))
    (fmul (a uint) (b uint) (precision uint) (response uint uint))
    (fdiv (a uint) (b uint) (precision uint) (response uint uint))
  )
)

;; =============================================================================
;; ADDITIONAL TRAITS
;; =============================================================================

;; Governance Traits
(define-trait dao-trait
  (
    (has-voting-power (voter principal) (response bool uint))
    (get-voting-power (voter principal) (response uint uint))
    (get-total-voting-power () (response uint uint))
    (delegate (delegatee principal) (response bool uint))
    (undelegate () (response bool uint))
    (execute-proposal (proposal-id uint) (response bool uint))
    (vote (proposal-id uint) (support bool) (response bool uint))
    (get-proposal (proposal-id uint)
      (response (tuple (proposer principal) (start-block uint) (end-block uint) (votes-for uint) (votes-against uint) (executed bool) (canceled bool)) uint)
    )
  )
)

(use-trait governance-token-trait .governance.governance-token-trait)

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
    (get-balance (token-id uint) (user principal) (response uint uint))
    (get-overall-balance (user principal) (response uint uint))
    (get-total-supply (token-id uint) (response uint uint))
    (get-overall-supply () (response uint uint))
    (get-decimals (token-id uint) (response uint uint))
    (get-token-uri (token-id uint) (response (optional (string-ascii 256)) uint))
    (transfer (token-id uint) (amount uint) (sender principal) (recipient principal) (response bool uint))
    (transfer-memo (token-id uint) (amount uint) (sender principal) (recipient principal) (memo (buff 34)) (response bool uint))
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
;; CENTRALIZATION ADDITIONS (missing traits discovered by fixer)
;; =============================================================================

;; Batch Auction Trait (centralized)
(define-trait batch-auction-trait
  (
    (create-auction (token-sell <sip-010-ft-trait>) (token-buy <sip-010-ft-trait>) (amount uint) (duration uint) (response uint (err uint)))
    (place-bid (auction-id uint) (amount uint) (response bool (err uint)))
    (settle-auction (auction-id uint) (response bool (err uint)))
    (get-auction-status (auction-id uint) (response (tuple (status (string-ascii 32)) (total-bids uint)) (err uint)))
  )
)

;; Keeper Coordinator Trait (centralized)
(define-trait keeper-coordinator-trait
  (
    (execute-keeper-tasks () (response (tuple (tasks-attempted uint) (block uint) (keeper principal)) (err uint)))
    (set-keeper-enabled (enabled bool) (response bool (err uint)))
    (is-authorized-keeper (keeper principal) (response bool (err uint)))
    (get-keeper-status ()
      (response (tuple (enabled bool) (last-execution uint) (interval uint) (total-executed uint) (total-failed uint) (success-rate uint)) (err uint)))
  )
)

;; Bond Factory Trait (centralized)
(define-trait bond-factory-trait
  (
    (create-bond (principal-amount uint) (coupon-rate uint) (maturity-blocks uint) (collateral-amount uint) (collateral-token principal) (is-callable bool) (call-premium uint)
      (response (tuple (bond-id uint) (bond-contract principal) (maturity-block uint)) (err uint)))
    (redeem-bond (bond-id uint)
      (response (tuple (principal uint) (interest uint) (total-payout uint)) (err uint)))
    (report-coupon-payment (bond-id uint) (payment-amount uint) (response bool (err uint)))
    (get-bond-status (bond-id uint)
      (response (tuple (bond-id uint) (status (string-ascii 20)) (is-mature bool) (blocks-until-maturity uint) (current-block uint) (maturity-block uint)) (err uint)))
  )
)

;; Cross-Protocol Integrator Trait (centralized)
(define-trait cross-protocol-integrator-trait
  (
    (register-protocol (protocol-name (string-ascii 64)) (protocol-contract principal) (response bool (err uint)))
    (remove-protocol (protocol-name (string-ascii 64)) (response bool (err uint)))
    (swap-via-protocol (protocol-name (string-ascii 64)) (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint) (response bool (err uint)))
    (get-protocol-contract (protocol-name (string-ascii 64)) (response (optional principal) (err uint)))
  )
)

;; DEX Factory (internal) Trait used by templates
(define-trait dex-factory-trait
  (
    (create-pool-internal (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (token-a-amount uint) (token-b-amount uint) (response principal (err uint)))
  )
)

;; Advanced Router Dijkstra Trait (centralized)
(define-trait advanced-router-dijkstra-trait
  (
    (find-optimal-path (token-in principal) (token-out principal) (amount-in uint)
      (response (tuple (path (list 20 principal)) (distance uint) (hops uint)) (err uint)))
    (swap-optimal-path (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint)
      (response (tuple (amount-out uint) (path (list 20 principal)) (hops uint) (distance uint)) (err uint)))
    (get-graph-stats () (response (tuple (nodes uint) (edges uint)) (err uint)))
  )
)

;; Budget Manager Trait (centralized)
(define-trait budget-manager-trait
  (
    (create-budget-proposal (amount uint) (token principal) (response uint (err uint)))
    (execute-budget-proposal (budget-id uint) (response bool (err uint)))
    (get-budget-proposal (budget-id uint) (response (optional (tuple (proposer principal) (amount uint) (token principal) (executed bool))) (err uint)))
    (get-contract-owner () (response principal (err uint)))
  )
)

;; Proposal Trait (centralized, minimal)
(define-trait proposal-trait
  (
    (get-contract-owner () (response principal (err uint)))
  )
)

;; =============================================================================
;; TRAIT DISCOVERY AND VERSIONING
;; =============================================================================
(define-read-only (get-all-traits)
  (ok (tuple
    (sips (list 
      "sip-010-ft-trait" 
      "sip-009-nft-trait" 
      "sip-018-trait" 
      "sip-010-ft-mintable-trait"
    ))
    (core (list 
      "ownable-trait" 
      "access-control-trait"
    ))
    (security (list 
      "circuit-breaker-trait" 
      "monitoring-trait" 
      "pausable-trait" 
      "compliance-hooks-trait" 
      "mev-protector-trait"
    ))
    (defi (list 
      "pool-trait" 
      "factory-trait" 
      "vault-trait" 
      "strategy-trait" 
      "staking-trait" 
      "lending-system-trait"
    ))
    (math (list 
      "math-trait" 
      "fixed-point-math-trait"
    ))
    (governance (list 
      "dao-trait" 
      "governance-token-trait"
    ))
    (additional (list 
      "oracle-trait" 
      "oracle-aggregator-trait" 
      "btc-adapter-trait" 
      "cross-protocol-trait"
    ))
    (dimensional (list 
      "position-nft-trait" 
      "dim-registry-trait" 
      "dimensional-oracle-trait"
    ))
    (utilities (list 
      "migration-manager-trait" 
      "metrics-trait" 
      "error-codes-trait" 
      "standard-constants-trait" 
      "utils-trait"
    ))
  ))
)

(define-read-only (get-trait-version (trait-name (string-ascii 64)))
  (ok (match trait-name
    "sip-010-ft-trait" u100
    "sip-009-nft-trait" u100
    "ownable-trait" u100
    "access-control-trait" u100
    "governance-token-trait" u100
    ;; Default version for all traits
    u100
  ))
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
;;    (impl-trait sip_010_ft_trait)
;;
;; 3. Use trait types in function parameters:
;;    (define-public (my-function (token <sip-010-ft-trait>)) ...)
;;
;; Note: The relative path `.all-traits` assumes the contract is deployed
;; by the same principal. For cross-principal references, use full principal.
