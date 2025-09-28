;; ===========================================
;; CONXIAN PROTOCOL - CENTRALIZED TRAIT DEFINITIONS
;; ===========================================
;;
;; This file serves as the single source of truth for all trait definitions
;; in the Conxian protocol. All contracts should reference traits from this file
;; to ensure consistency and avoid duplication.
;;
;; USAGE:
;; (use-trait <trait-name> .all-traits.<trait-name>)
;;
;; ===========================================
;; CORE TRAITS
;; ===========================================

(define-trait utils-trait
  (
    (principal-to-buff (principal) (response (buff 32) (err uint)))
  )
)

(define-trait lending-system-trait
  (
    (deposit (principal uint) (response bool (err uint)))
    (withdraw (principal uint) (response bool (err uint)))
    (borrow (principal uint) (response bool (err uint)))
    (repay (principal uint) (response bool (err uint)))
    (liquidate (principal principal principal principal uint) (response bool (err uint)))
    (get-account-liquidity (principal) (response (tuple (liquidity uint) (shortfall uint)) (err uint)))
    (get-asset-price (principal) (response uint (err uint)))
    (get-borrow-rate (principal) (response uint (err uint)))
    (get-supply-rate (principal) (response uint (err uint)))
  )
)

(define-trait sip-010-ft-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool (err uint)))
    (get-balance (principal) (response uint (err uint)))
    (get-total-supply () (response uint (err uint)))
    (get-decimals () (response uint (err uint)))
    (get-name () (response (string-ascii 32) (err uint)))
    (get-symbol () (response (string-ascii 10) (err uint)))
    (get-token-uri () (response (optional (string-utf8 256)) (err uint)))
  )
)

(define-trait sip-010-ft-mintable-trait
  (
    (mint (uint principal) (response bool (err uint)))
    (burn (uint principal) (response bool (err uint)))
    (get-token-uri () (response (optional (string-utf8 256)) (err uint)))
  )
)


(define-trait bond-trait
  (
    (issue-bond (string-ascii 32) (string-ascii 10) uint uint uint uint uint principal) (response bool (err uint)))
    (claim-coupon () (response uint (err uint)))
    (redeem-at-maturity (principal) (response uint (err uint)))
    (get-maturity-block () (response uint (err uint)))
    (get-coupon-rate () (response uint (err uint)))
    (get-face-value () (response uint (err uint)))
    (get-payment-token () (response principal (err uint)))
    (is-matured () (response bool (err uint)))
    (get-next-coupon-block (principal) (response (optional uint) (err uint)))
  ))


(define-trait dimensional-oracle-trait
  (
    (get-price (principal) (response uint (err uint)))
    (update-price (principal uint) (response bool (err uint)))
    (add-price-feed (principal principal) (response bool (err uint)))
    (remove-price-feed (principal) (response bool (err uint)))
  )
)

(define-trait compliance-hooks-trait
  (
    (before-transfer (principal principal uint (optional (buff 34))) (response bool (err uint)))
    (after-transfer (principal principal uint (optional (buff 34))) (response bool (err uint)))
  )
)

(define-trait pool-trait
  (
    (add-liquidity (uint uint principal) (response (tuple (tokens-minted uint) (token-a-used uint) (token-b-used uint)) (err uint)))
    (remove-liquidity (uint principal) (response (tuple (token-a-returned uint) (token-b-returned uint)) (err uint)))
    (swap (principal uint principal) (response uint (err uint)))
    (get-reserves () (response (tuple (reserve-a uint) (reserve-b uint)) (err uint)))
    (get-total-supply () (response uint (err uint)))
  )
)


(define-trait access-control-trait
  (
    ;; Check if an account has a specific role
    (has-role (account principal) (role uint) (response bool (err uint)))

    ;; Get the admin address
    (get-admin () (response principal (err uint)))

    ;; Transfer admin rights
    (set-admin (new-admin principal) (response bool (err uint)))

    ;; Grant a role to an account
    (grant-role (role uint) (account principal) (response bool (err uint)))

    ;; Revoke a role from an account
    (revoke-role (role uint) (account principal) (response bool (err uint)))

    ;; Renounce a role (callable by role holder only)
    (renounce-role (role uint) (response bool (err uint)))

    ;; Get role name by ID
    (get-role-name (role uint) (response (string-ascii 64) (err uint)))

    ;; Check if caller has admin role (convenience function)
    (is-admin (caller principal) (response bool (err uint)))
  )
)

;; Standard Roles
(define-constant ROLE_ADMIN 0x0000000000000000000000000000000000000000000000000000000000000001)
(define-constant ROLE_PAUSER 0x0000000000000000000000000000000000000000000000000000000000000002)
(define-constant ROLE_ORACLE_UPDATER 0x0000000000000000000000000000000000000000000000000000000000000004)
(define-constant ROLE_LIQUIDATOR 0x0000000000000000000000000000000000000000000000000000000000000008)
(define-constant ROLE_STRATEGIST 0x0000000000000000000000000000000000000000000000000000000000000010)

;; Error Codes
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_ROLE (err u101))
(define-constant ERR_ROLE_ALREADY_GRANTED (err u102))
(define-constant ERR_ROLE_NOT_GRANTED (err u103))
(define-constant ERR_INVALID_ADMIN (err u104))

(define-trait pausable-trait
  (
    ;; Pause the contract (only callable by pauser role)
    (pause () (response bool (err uint)))

    ;; Unpause the contract (only callable by pauser role)
    (unpause () (response bool (err uint)))

    ;; Check if the contract is paused
    (is-paused () (response bool (err uint)))

    ;; Require that the contract is not paused
    (when-not-paused () (response bool (err uint)))

    ;; Require that the contract is paused
    (when-paused () (response bool (err uint)))
  )
)

;; Error Codes
(define-constant ERR_PAUSED (err u200))
(define-constant ERR_NOT_PAUSED (err u201))

(define-trait ownable-trait
  (
    (get-owner () (response principal (err uint)))
    (transfer-ownership (principal) (response bool (err uint)))
    (renounce-ownership () (response bool (err uint)))
  )
)

;; @title Enhanced Circuit Breaker Trait
;; @notice Provides comprehensive circuit breaker functionality to protect against failures and attacks
;; @dev Implements the circuit breaker pattern with operation-specific controls, rate limiting, and monitoring
(define-trait circuit-breaker-trait
  (
    ;; ===== Core Circuit Breaker Functions =====
    
    ;; @notice Check if the circuit is open for any operation
    ;; @return (response bool uint) true if circuit is open, false otherwise
    (is-circuit-open () (response bool (err uint)))
    
    ;; @notice Check if the circuit is open for a specific operation
    ;; @param operation The operation identifier (max 64 chars)
    ;; @return (response bool uint) true if circuit is open for this operation
    (check-circuit-state (operation (string-ascii 64)) (response bool (err uint)))

    ;; @notice Record a successful operation
    (record-success (operation (string-ascii 64)) (response bool (err uint)))

    ;; @notice Record a failed operation
    (record-failure (operation (string-ascii 64)) (response bool (err uint)))

    ;; @notice Get the failure rate for an operation
    (get-failure-rate (operation (string-ascii 64)) (response uint (err uint)))

    ;; @notice Get the current state of the circuit
    (get-circuit-state (operation (string-ascii 64)) 
      (response {
        state: uint, 
        last-checked: uint, 
        failure-rate: uint,
        failure-count: uint,
        success-count: uint
      } (err uint))
    )

    ;; ===== Admin Functions =====
    
    ;; @notice Manually override the circuit state (admin only)
    (set-circuit-state (operation (string-ascii 64)) (state bool) (response bool (err uint)))

    ;; @notice Set the failure threshold (admin only)
    (set-failure-threshold (threshold uint) (response bool (err uint)))

    ;; @notice Set the reset timeout (admin only)
    (set-reset-timeout (timeout uint) (response bool (err uint)))

    ;; @notice Get the admin address
    (get-admin () (response principal (err uint)))

    ;; @notice Transfer admin rights
    (set-admin (new-admin principal) (response bool (err uint)))
    
    ;; ===== Enhanced Features =====
    
    ;; @notice Set rate limit for an operation
    (set-rate-limit (operation (string-ascii 64)) (limit uint) (window uint) (response bool (err uint)))
    
    ;; @notice Get rate limit for an operation
    (get-rate-limit (operation (string-ascii 64)) 
      (response {
        limit: uint, 
        window: uint, 
        current: uint,
        reset-time: uint
      } (err uint))
    )
    
    ;; @notice Batch record successes
    (batch-record-success (operations (list 20 (string-ascii 64))) (response bool (err uint)))
    
    ;; @notice Batch record failures
    (batch-record-failure (operations (list 20 (string-ascii 64))) (response bool (err uint)))
    
    ;; @notice Get health status
    (get-health-status () 
      (response {
        is_operational: bool,
        total_failure_rate: uint,
        last_checked: uint,
        uptime: uint,
        total_operations: uint,
        failed_operations: uint
      } (err uint))
    )
    
    ;; @notice Set circuit breaker mode
    (set-circuit-mode (mode (optional bool)) (response bool (err uint)))
    
    ;; @notice Get circuit breaker mode
    (get-circuit-mode () (response (optional bool) (err uint)))
    
    ;; @notice Emergency shutdown (multi-sig protected)
    (emergency-shutdown () (response bool (err uint)))
    
    ;; @notice Recover from emergency shutdown (multi-sig protected)
    (recover-from-shutdown () (response bool (err uint)))
  )
)

(define-trait standard-constants-trait
  (
    ;; Precision and mathematical constants (18 decimals)
    (get-precision) (response uint (err uint))
    (get-basis-points) (response uint (err uint))

    ;; Common time constants (in blocks, assuming ~1 block per minute)
    (get-blocks-per-minute) (response uint (err uint))
    (get-blocks-per-hour) (response uint (err uint))
    (get-blocks-per-day) (response uint (err uint))
    (get-blocks-per-week) (response uint (err uint))
    (get-blocks-per-year) (response uint (err uint))

    ;; Common percentage values (in basis points)
    (get-max-bps) (response uint (err uint))
    (get-one-hundred-percent) (response uint (err uint))
    (get-fifty-percent) (response uint (err uint))
    (get-zero) (response uint (err uint))

    ;; Common precision values
    (get-precision-18) (response uint (err uint))
    (get-precision-8) (response uint (err uint))
    (get-precision-6) (response uint (err uint))
  )
)

(define-trait vault-trait
  (
    ;; @notice Deposit funds into the vault
    (deposit (token-contract <sip-010-ft-trait>) (amount uint)) (response uint (err uint))

    ;; @notice Withdraw funds from the vault
    (withdraw (token-contract <sip-010-ft-trait>) (amount uint)) (response uint (err uint))

    ;; @notice Get the current total supply of shares for a token
    (get-total-shares (token-contract <sip-010-ft-trait>)) (response uint (err uint))

    ;; @notice Get the amount of underlying tokens for a given amount of shares
    (get-amount-out-from-shares (token-contract <sip-010-ft-trait>) (shares uint)) (response uint (err uint))

    ;; @notice Get the amount of shares for a given amount of underlying tokens
    (get-shares-from-amount-in (token-contract <sip-010-ft-trait>) (amount uint)) (response uint (err uint))

    ;; @notice Harvest rewards (admin only)
    (harvest (token-contract <sip-010-ft-trait>)) (response bool (err uint))

    ;; @notice Set the strategy for a given token (admin only)
    (set-strategy (token-contract <sip-010-ft-trait>) (strategy-contract principal)) (response bool (err uint))

    ;; @notice Get the current strategy for a given token
    (get-strategy (token-contract <sip-010-ft-trait>)) (response (optional principal) (err uint))

    ;; @notice Get the current APY for a given token
    (get-apy (token-contract <sip-010-ft-trait>)) (response uint (err uint))

    ;; @notice Get the total value locked (TVL) for a given token
    (get-tvl (token-contract <sip-010-ft-trait>)) (response uint (err uint))
  )
)

(define-trait vault-admin-trait
  (
    ;; Administrative controls
    (set-deposit-fee (uint) (response bool (err uint)))
    (set-withdrawal-fee (uint) (response bool (err uint)))
    (set-vault-cap (principal uint) (response bool (err uint)))
    (set-paused (bool) (response bool (err uint)))

    ;; Asset management
    (emergency-withdraw (principal uint principal) (response uint (err uint)))
    (rebalance-vault (principal) (response bool (err uint)))

    ;; Enhanced tokenomics integration
    (set-revenue-share (uint) (response bool (err uint)))
    (update-integration-settings ((tuple (monitor-enabled bool) (emission-enabled bool))) (response bool (err uint)))

    ;; Governance
    (transfer-admin (principal) (response bool (err uint)))
    (get-admin () (response principal (err uint)))
  )
)

(define-trait strategy-trait
  (
    ;; @notice Deposit funds into the strategy
    (deposit (token-contract <sip-010-ft-trait>) (amount uint)) (response uint (err uint))

    ;; @notice Withdraw funds from the strategy
    (withdraw (token-contract <sip-010-ft-trait>) (amount uint)) (response uint (err uint))

    ;; @notice Harvest rewards from the strategy
    (harvest ()) (response bool (err uint))

    ;; @notice Rebalance the strategy
    (rebalance ()) (response bool (err uint))

    ;; @notice Get the current APY of the strategy
    (get-apy ()) (response uint (err uint))

    ;; @notice Get the total value locked (TVL) in the strategy
    (get-tvl ()) (response uint (err uint))

    ;; @notice Get the underlying token of the strategy
    (get-underlying-token ()) (response principal (err uint))

    ;; @notice Get the vault associated with this strategy
    (get-vault ()) (response principal (err uint))
  )
)

(define-trait staking-trait
  (
    ;; @notice Stake tokens
    (stake (token-contract <sip-010-ft-trait>) (amount uint)) (response uint (err uint))

    ;; @notice Unstake tokens
    (unstake (token-contract <sip-010-ft-trait>) (amount uint)) (response uint (err uint))

    ;; @notice Claim rewards
    (claim-rewards (token-contract <sip-010-ft-trait>)) (response uint (err uint))

    ;; @notice Get the amount of staked tokens for a user
    (get-staked-balance (token-contract <sip-010-ft-trait>) (user principal)) (response uint (err uint))

    ;; @notice Get the amount of available rewards for a user
    (get-available-rewards (token-contract <sip-010-ft-trait>) (user principal)) (response uint (err uint))

    ;; @notice Get the total staked supply of a token
    (get-total-staked (token-contract <sip-010-ft-trait>)) (response uint (err uint))

    ;; @notice Set the reward rate (admin only)
    (set-reward-rate (token-contract <sip-010-ft-trait>) (rate uint)) (response bool (err uint))

    ;; @notice Get the reward rate
    (get-reward-rate (token-contract <sip-010-ft-trait>)) (response uint (err uint))
  )
)

(define-trait dao-trait
  (
    (has-voting-power (principal) (response bool (err uint)))
    (get-voting-power (principal) (response uint (err uint)))
    (get-total-voting-power () (response uint (err uint)))
    (delegate (delegatee principal) (response bool (err uint)))
    (undelegate () (response bool (err uint)))
    (execute-proposal (proposal-id uint) (response bool (err uint)))
    (vote (proposal-id uint) (support bool) (response bool (err uint)))
    (get-proposal (proposal-id uint)
      (response {
        proposer: principal,
        start-block: uint,
        end-block: uint,
        votes-for: uint,
        votes-against: uint,
        executed: bool,
        canceled: bool
      } (err uint)))
  )
)

(define-trait liquidation-trait
  (
    (is-liquidatable (debt-asset principal) (collateral-asset principal) (response bool (err uint)))
    (liquidate-position
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
      (debt-amount uint)
      (max-collateral-amount uint)
    ) (response (tuple (debt-repaid uint) (collateral-seized uint)) (err uint))
    (liquidate-multiple-positions
      (positions (list 10 (tuple
        (borrower principal)
        (debt-asset principal)
        (collateral-asset principal)
        (debt-amount uint)
      )))
    ) (response (tuple (success-count uint) (total-debt-repaid uint) (total-collateral-seized uint)) (err uint))
    (calculate-liquidation-amounts
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
    ) (response (tuple
        (debt-value uint)
        (collateral-value uint)
      ) (err uint)))
    (emergency-liquidate
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
    ) (response bool (err uint))
  )
)

;; Error codes for liquidation operations
(define-constant ERR_LIQUIDATION_PAUSED (err u1001))
(define-constant ERR_UNAUTHORIZED (err u1002))
(define-constant ERR_INVALID_AMOUNT (err u1003))
(define-constant ERR_POSITION_NOT_UNDERWATER (err u1004))
(define-constant ERR_SLIPPAGE_TOO_HIGH (err u1005))
(define-constant ERR_LIQUIDATION_NOT_PROFITABLE (err u1006))
(define-constant ERR_MAX_POSITIONS_EXCEEDED (err u1007))
(define-constant ERR_ASSET_NOT_WHITELISTED (err u1008))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u1009))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1010))

(define-trait monitoring-trait
  (
    (log-event 
      (component (string-ascii 32))
      (event-type (string-ascii 32))
      (severity uint)
      (message (string-ascii 256))
      (data (optional {}))
    ) (response bool (err uint)))
    (get-events (component (string-ascii 32))
                (limit uint)
                (offset uint)
                (response (list 100 (tuple (id uint)
                                         (event-type (string-ascii 32))
                                         (severity uint)
                                         (message (string-ascii 256))
                                         (block-height uint)
                                         (data (optional {}))))
                          (err uint)))
    (get-event (event-id uint)
               (response (tuple (id uint)
                              (component (string-ascii 32))
                              (event-type (string-ascii 32))
                              (severity uint)
                              (message (string-ascii 256))
                              (block-height uint)
                              (data (optional {})))
                        (err uint)))
    (get-health-status (component (string-ascii 32))
                      (response (tuple (status uint)
                                     (last-updated uint)
                                     (uptime uint)
                                     (error-count uint)
                                     (warning-count uint))
                                (err uint)))
    (set-alert-threshold (component (string-ascii 32))
                         (alert-type (string-ascii 32))
                         (threshold uint)
                         (response bool (err uint)))
    (get-admin () (response principal (err uint)))
    (set-admin (new-admin principal) (response bool (err uint)))
  )
)

;; Remove duplicate oracle-trait definition (keeping the enhanced version)


(define-trait math-trait
  (
    ;; Basic arithmetic operations
    (add (a uint) (b uint)) (response uint (err uint))
    (sub (a uint) (b uint)) (response uint (err uint))
    (mul (a uint) (b uint)) (response uint (err uint))
    (div (a uint) (b uint)) (response uint (err uint))
    (pow (base uint) (exp uint)) (response uint (err uint))
    (sqrt (a uint)) (response uint (err uint))

    ;; Percentage and ratio calculations
    (get-percentage (value uint) (percentage uint)) (response uint (err uint))
    (get-ratio (numerator uint) (denominator uint)) (response uint (err uint))

    ;; Min/Max functions
    (min (a uint) (b uint)) (response uint (err uint))
    (max (a uint) (b uint)) (response uint (err uint))

    ;; Absolute value (for int)
    (abs (a int)) (response uint (err uint))

    ;; Rounding functions
    (ceil (a uint) (b uint)) (response uint (err uint))
    (floor (a uint) (b uint)) (response uint (err uint))

    ;; Logarithms
    (log2 (a uint)) (response uint (err uint))
    (log10 (a uint)) (response uint (err uint))
    (ln (a uint)) (response uint (err uint))

    ;; Exponentials
    (exp (a uint)) (response uint (err uint))

    ;; Average
    (average (a uint) (b uint)) (response uint (err uint))

    ;; Weighted Average
    (weighted-average (value1 uint) (weight1 uint) (value2 uint) (weight2 uint)) (response uint (err uint))

    ;; Geometric Mean
    (geometric-mean (a uint) (b uint)) (response uint (err uint))

    ;; Standard Deviation
    (std-dev (values (list 100 uint))) (response uint (err uint))

    ;; Interpolation
    (linear-interpolate (x uint) (x0 uint) (y0 uint) (x1 uint) (y1 uint)) (response uint (err uint))

    ;; Fixed-point arithmetic (assuming 1e8 or 1e18 precision)
    (fpow (base uint) (exp uint) (precision uint)) (response uint (err uint))
    (fsqrt (a uint) (precision uint)) (response uint (err uint))
    (fmul (a uint) (b uint) (precision uint)) (response uint (err uint))
    (fdiv (a uint) (b uint) (precision uint)) (response uint (err uint))
  )
)

(define-trait flash-loan-receiver-trait
  (
    ;; @notice Execute a flash loan
    (execute-flash-loan (token-contract <sip-010-ft-trait>) (amount uint) (initiator principal) (data (optional (buff 256)))) (response bool (err uint))
  )
)

(define-trait pool-creation-trait
  (
    ;; @notice Create a new pool
    (create-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint) (pool-type (string-ascii 64))) (response principal (err uint))

    ;; @notice Get a pool address by its tokens and fee
    (get-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint)) (response (optional principal) (err uint))

    ;; @notice Get all pools created by the factory
    (get-all-pools () (response (list 100 {token-a: principal, token-b: principal, fee-bps: uint, pool-address: principal, pool-type: (string-ascii 64)}) (err uint)))

    ;; @notice Set a new pool implementation for a given pool type
    (set-pool-implementation (pool-type (string-ascii 64)) (implementation-contract principal)) (response bool (err uint))

    ;; @notice Get the pool implementation for a given pool type
    (get-pool-implementation (pool-type (string-ascii 64))) (response (optional principal) (err uint))
  )
)

(define-trait factory-trait
  (
    (create-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint) (pool-type (string-ascii 64))) (response principal (err uint))
    (get-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>) (fee-bps uint)) (response (optional principal) (err uint))
    (get-pool-count () (response uint (err uint)))
    (register-pool-implementation (pool-type (string-ascii 64)) (implementation-contract principal)) (response bool (err uint))
  )
)

(define-trait router-trait
  (
    (swap-exact-tokens-for-tokens (uint (list 10 principal) principal uint) (response (list 10 uint) (err uint)))
    (swap-tokens-for-exact-tokens (uint (list 10 principal) principal uint) (response (list 10 uint) (err uint)))
    (get-amounts-out (uint (list 10 principal)) (response (list 10 uint) (err uint)))
    (get-amounts-in (uint (list 10 principal)) (response (list 10 uint) (err uint)))
  )
)

(define-trait yield-optimizer-trait
  (
    ;; @notice Deposit funds into the yield optimizer
    (deposit (token-contract <sip-010-ft-trait>) (amount uint)) (response uint (err uint))

    ;; @notice Withdraw funds from the yield optimizer
    (withdraw (token-contract <sip-010-ft-trait>) (amount uint)) (response uint (err uint))

    ;; @notice Get the current total supply of shares for a token
    (get-total-shares (token-contract <sip-010-ft-trait>)) (response uint (err uint))

    ;; @notice Get the amount of underlying tokens for a given amount of shares
    (get-amount-out-from-shares (token-contract <sip-010-ft-trait>) (shares uint)) (response uint (err uint))

    ;; @notice Get the amount of shares for a given amount of underlying tokens
    (get-shares-from-amount-in (token-contract <sip-010-ft-trait>) (amount uint)) (response uint (err uint))

    ;; @notice Rebalance the strategy (admin only)
    (rebalance-strategy (token-contract <sip-010-ft-trait>)) (response bool (err uint))

    ;; @notice Set the strategy for a given token (admin only)
    (set-strategy (token-contract <sip-010-ft-trait>) (strategy-contract principal)) (response bool (err uint))

    ;; @notice Get the current strategy for a given token
    (get-strategy (token-contract <sip-010-ft-trait>)) (response (optional principal) (err uint))

    ;; @notice Get the current APY for a given token
    (get-apy (token-contract <sip-010-ft-trait>)) (response uint (err uint))

    ;; @notice Get the total value locked (TVL) for a given token
    (get-tvl (token-contract <sip-010-ft-trait>)) (response uint (err uint))
  )
)
