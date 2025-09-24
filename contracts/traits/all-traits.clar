;; ===========================================
;; CONXIAN PROTOCOL - CENTRALIZED TRAIT DEFINITIONS
;; ===========================================
;;
;; This file serves as the single source of truth for all trait definitions
;; in the Conxian protocol. All contracts should reference traits from this file
;; to ensure consistency and avoid duplication.
;;
;; USAGE:
;; (use-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.<trait-name>)
;;
;; ===========================================
;; CORE TRAITS
;; ===========================================

(define-trait lending-system-trait
  (
    (deposit (principal uint) (response bool uint))
    (withdraw (principal uint) (response bool uint))
    (borrow (principal uint) (response bool uint))
    (repay (principal uint) (response bool uint))
    (liquidate (principal principal principal principal uint) (response bool uint))
    (get-account-liquidity (principal) (response (tuple (liquidity uint) (shortfall uint)) uint))
    (get-asset-price (principal) (response uint uint))
    (get-borrow-rate (principal) (response uint uint))
    (get-supply-rate (principal) (response uint uint))
  )
)

(define-trait sip-010-ft-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-decimals () (response uint uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 10) uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

(define-trait bond-trait
  (
    (issue-bond (string-ascii 32) (string-ascii 10) uint uint uint uint uint principal) (response bool uint)
    (claim-coupon () (response uint uint))
    (redeem-at-maturity (principal) (response uint uint))
    (get-maturity-block () (response uint uint))
    (get-coupon-rate () (response uint uint))
    (get-face-value () (response uint uint))
    (get-payment-token () (response principal uint))
    (is-matured () (response bool uint))
    (get-next-coupon-block (principal) (response (optional uint) uint))
  )
)

(define-trait pool-trait
  (
    (add-liquidity (uint uint principal) (response (tuple (tokens-minted uint) (token-a-used uint) (token-b-used uint)) uint))
    (remove-liquidity (uint principal) (response (tuple (token-a-returned uint) (token-b-returned uint)) uint))
    (swap (principal uint principal) (response uint uint))
    (get-reserves () (response (tuple (reserve-a uint) (reserve-b uint)) uint))
    (get-total-supply () (response uint uint))
  )
)

(define-trait sip-009-nft-trait
  (
    (transfer (principal principal uint (optional (buff 34))) (response bool uint))
    (get-owner (uint) (response (optional principal) uint))
    (get-token-uri (uint) (response (optional (string-utf8 256)) uint))
    (get-last-token-id () (response uint uint))
    (get-token-by-index (principal uint) (response (optional uint) uint))
  )
)

(define-trait access-control-trait
  (
    ;; Check if an account has a specific role
    (has-role (account principal) (role uint) (response bool uint))

    ;; Get the admin address
    (get-admin () (response principal uint))

    ;; Transfer admin rights
    (set-admin (new-admin principal) (response bool uint))

    ;; Grant a role to an account
    (grant-role (role uint) (account principal) (response bool uint))

    ;; Revoke a role from an account
    (revoke-role (role uint) (account principal) (response bool uint))

    ;; Renounce a role (callable by role holder only)
    (renounce-role (role uint) (response bool uint))

    ;; Get role name by ID
    (get-role-name (role uint) (response (string-ascii 64) uint))

    ;; Check if caller has admin role (convenience function)
    (is-admin (caller principal) (response bool uint))
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
    (pause () (response bool uint))

    ;; Unpause the contract (only callable by pauser role)
    (unpause () (response bool uint))

    ;; Check if the contract is paused
    (is-paused () (response bool uint))

    ;; Require that the contract is not paused
    (when-not-paused () (response bool uint))

    ;; Require that the contract is paused
    (when-paused () (response bool uint))
  )
)

;; Error Codes
(define-constant ERR_PAUSED (err u200))
(define-constant ERR_NOT_PAUSED (err u201))

(define-trait ownable-trait
  (
    (get-owner () (response principal uint))
    (transfer-ownership (principal) (response bool uint))
    (renounce-ownership () (response bool uint))
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
    (is-circuit-open () (response bool uint))
    
    ;; @notice Check if the circuit is open for a specific operation
    ;; @param operation The operation identifier (max 64 chars)
    ;; @return (response bool uint) true if circuit is open for this operation
    (check-circuit-state (operation (string-ascii 64)) (response bool uint))

    ;; @notice Record a successful operation
    (record-success (operation (string-ascii 64)) (response bool uint))

    ;; @notice Record a failed operation
    (record-failure (operation (string-ascii 64)) (response bool uint))

    ;; @notice Get the failure rate for an operation
    (get-failure-rate (operation (string-ascii 64)) (response uint uint))

    ;; @notice Get the current state of the circuit
    (get-circuit-state (operation (string-ascii 64)) 
      (response {
        state: uint, 
        last-checked: uint, 
        failure-rate: uint,
        failure-count: uint,
        success-count: uint
      } uint)
    )

    ;; ===== Admin Functions =====
    
    ;; @notice Manually override the circuit state (admin only)
    (set-circuit-state (operation (string-ascii 64)) (state bool) (response bool uint))

    ;; @notice Set the failure threshold (admin only)
    (set-failure-threshold (threshold uint) (response bool uint))

    ;; @notice Set the reset timeout (admin only)
    (set-reset-timeout (timeout uint) (response bool uint))

    ;; @notice Get the admin address
    (get-admin () (response principal uint))

    ;; @notice Transfer admin rights
    (set-admin (new-admin principal) (response bool uint))
    
    ;; ===== Enhanced Features =====
    
    ;; @notice Set rate limit for an operation
    (set-rate-limit (operation (string-ascii 64)) (limit uint) (window uint) (response bool uint))
    
    ;; @notice Get rate limit for an operation
    (get-rate-limit (operation (string-ascii 64)) 
      (response {
        limit: uint, 
        window: uint, 
        current: uint,
        reset-time: uint
      } uint)
    )
    
    ;; @notice Batch record successes
    (batch-record-success (operations (list 20 (string-ascii 64))) (response bool uint))
    
    ;; @notice Batch record failures
    (batch-record-failure (operations (list 20 (string-ascii 64))) (response bool uint))
    
    ;; @notice Get health status
    (get-health-status () 
      (response {
        is_operational: bool,
        total_failure_rate: uint,
        last_checked: uint,
        uptime: uint,
        total_operations: uint,
        failed_operations: uint
      } uint)
    )
    
    ;; @notice Set circuit breaker mode
    (set-circuit-mode (mode (optional bool)) (response bool uint))
    
    ;; @notice Get circuit breaker mode
    (get-circuit-mode () (response (optional bool) uint))
    
    ;; @notice Emergency shutdown (multi-sig protected)
    (emergency-shutdown () (response bool uint))
    
    ;; @notice Recover from emergency shutdown (multi-sig protected)
    (recover-from-shutdown () (response bool uint))
  )
)

(define-trait standard-constants-trait
  (
    ;; Precision and mathematical constants (18 decimals)
    (get-precision) (response uint uint)
    (get-basis-points) (response uint uint)

    ;; Common time constants (in blocks, assuming ~1 block per minute)
    (get-blocks-per-minute) (response uint uint)
    (get-blocks-per-hour) (response uint uint)
    (get-blocks-per-day) (response uint uint)
    (get-blocks-per-week) (response uint uint)
    (get-blocks-per-year) (response uint uint)

    ;; Common percentage values (in basis points)
    (get-max-bps) (response uint uint)
    (get-one-hundred-percent) (response uint uint)
    (get-fifty-percent) (response uint uint)
    (get-zero) (response uint uint)

    ;; Common precision values
    (get-precision-18) (response uint uint)
    (get-precision-8) (response uint uint)
    (get-precision-6) (response uint uint)
  )
)

(define-trait vault-trait
  (
    ;; Core vault operations
    (deposit (principal uint) (response (tuple (shares uint) (fee uint)) uint))
    (withdraw (principal uint) (response (tuple (amount uint) (fee uint)) uint))
    (flash-loan (uint principal) (response bool uint))

    ;; Asset management
    (get-total-balance (principal) (response uint uint))
    (get-total-shares (principal) (response uint uint))
    (get-user-shares (principal principal) (response uint uint))

    ;; Vault configuration
    (get-deposit-fee () (response uint uint))
    (get-withdrawal-fee () (response uint uint))
    (get-vault-cap (principal) (response uint uint))
    (is-paused () (response bool uint))

    ;; Enhanced tokenomics integration
    (get-revenue-share () (response uint uint))
    (collect-protocol-fees (principal) (response uint uint))
  )
)

(define-trait vault-admin-trait
  (
    ;; Administrative controls
    (set-deposit-fee (uint) (response bool uint))
    (set-withdrawal-fee (uint) (response bool uint))
    (set-vault-cap (principal uint) (response bool uint))
    (set-paused (bool) (response bool uint))

    ;; Asset management
    (emergency-withdraw (principal uint principal) (response uint uint))
    (rebalance-vault (principal) (response bool uint))

    ;; Enhanced tokenomics integration
    (set-revenue-share (uint) (response bool uint))
    (update-integration-settings ((tuple (monitor-enabled bool) (emission-enabled bool))) (response bool uint))

    ;; Governance
    (transfer-admin (principal) (response bool uint))
    (get-admin () (response principal uint))
  )
)

(define-trait strategy-trait
  (
    ;; Core strategy operations
    (deploy-funds (uint) (response uint uint))
    (withdraw-funds (uint) (response uint uint))
    (harvest-rewards () (response uint uint))

    ;; Strategy information
    (get-total-deployed () (response uint uint))
    (get-current-value () (response uint uint))
    (get-expected-apy () (response uint uint))
    (get-strategy-risk-level () (response uint uint))

    ;; Asset management
    (get-underlying-asset () (response principal uint))
    (emergency-exit () (response uint uint))

    ;; Enhanced tokenomics integration
    (distribute-rewards () (response uint uint))
    (get-performance-fee () (response uint uint))
    (update-dimensional-weights () (response bool uint))
  )
)

(define-trait staking-trait
  (
    (stake (uint) (response uint uint))
    (unstake (uint) (response uint uint))
    (get-staked-balance (principal) (response uint uint))
    (get-total-staked () (response uint uint))
  )
)

(define-trait dao-trait
  (
    (has-voting-power (principal) (response bool uint))
    (get-voting-power (principal) (response uint uint))
    (get-total-voting-power () (response uint uint))
    (delegate (delegatee principal) (response bool uint))
    (undelegate () (response bool uint))
    (execute-proposal (proposal-id uint) (response bool uint))
    (vote (proposal-id uint) (support bool) (response bool uint))
    (get-proposal (proposal-id uint)
      (response {
        id: uint,
        proposer: principal,
        start-block: uint,
        end-block: uint,
        for-votes: uint,
        against-votes: uint,
        executed: bool,
        canceled: bool
      } uint)
    )
  )
)

(define-trait liquidation-trait
  (
    (can-liquidate-position
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
    ) (response bool uint)
    (liquidate-position
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
      (debt-amount uint)
      (max-collateral-amount uint)
    ) (response (tuple (debt-repaid uint) (collateral-seized uint)) uint)
    (liquidate-multiple-positions
      (positions (list 10 (tuple
        (borrower principal)
        (debt-asset principal)
        (collateral-asset principal)
        (debt-amount uint)
      )))
    ) (response (tuple (success-count uint) (total-debt-repaid uint) (total-collateral-seized uint)) uint)
    (calculate-liquidation-amounts
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
      (debt-amount uint)
    ) (response (tuple
        (max-debt-repayable uint)
        (collateral-to-seize uint)
        (liquidation-incentive uint)
        (debt-value uint)
        (collateral-value uint)
      ) uint))
    (emergency-liquidate
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
    ) (response bool uint)
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
    ) (response bool uint)
    (get-events (component (string-ascii 32))
                (limit uint)
                (offset uint)
                (response (list 100 (tuple (id uint)
                                         (event-type (string-ascii 32))
                                         (severity uint)
                                         (message (string-ascii 256))
                                         (block-height uint)
                                         (data (optional {}))))
                         uint))
    (get-event (event-id uint)
               (response (tuple (id uint)
                              (component (string-ascii 32))
                              (event-type (string-ascii 32))
                              (severity uint)
                              (message (string-ascii 256))
                              (block-height uint)
                              (data (optional {})))
                        uint))
    (get-health-status (component (string-ascii 32))
                      (response (tuple (status uint)
                                     (last-updated uint)
                                     (uptime uint)
                                     (error-count uint)
                                     (warning-count uint))
                               uint))
    (set-alert-threshold (component (string-ascii 32))
                         (alert-type (string-ascii 32))
                         (threshold uint)
                         (response bool uint))
    (get-admin () (response principal uint))
    (set-admin (new-admin principal) (response bool uint))
  )
)

(define-trait oracle-trait
  (
    ;; Get the current price of an asset
    (get-price (token principal) (response uint uint))

    ;; Update the price of an asset (restricted to oracle admin)
    (update-price (token principal) (price uint) (response bool uint))

    ;; Get the last update time for an asset
    (get-last-updated (token principal) (response uint uint))

    ;; Add a new price feed (admin only)
    (add-price-feed (token principal) (feed principal) (response bool uint))

    ;; Remove a price feed (admin only)
    (remove-price-feed (token principal) (response bool uint))

    ;; Set the heartbeat interval (admin only)
    (set-heartbeat (token principal) (interval uint) (response bool uint))

    ;; Set the maximum price deviation (admin only)
    (set-max-deviation (token principal) (deviation uint) (response bool uint))

    ;; Get the current deviation threshold for a token
    (get-deviation-threshold (token principal) (response uint uint))

    ;; Emergency price override (admin only)
    (emergency-price-override (token principal) (price uint) (response bool uint))

    ;; Check if a price is stale
    (is-price-stale (token principal) (response bool uint))

    ;; Get the number of feeds for a token
    (get-feed-count (token principal) (response uint uint))

    ;; Get the admin address
    (get-admin () (response principal uint))

    ;; Transfer admin rights
    (set-admin (new-admin principal) (response bool uint))
  )
)

(define-trait dim-registry-trait
  (
    (update-weight (uint uint) (response uint uint))
  )
)

(define-trait dimensional-oracle-trait
  (
    (update-weights ((list 10 {dim-id: uint, new-wt: uint})) (response bool uint))
  )
)

(define-trait compliance-hooks-trait
  (
    (pre-transfer-hook (uint principal principal) (response bool uint))
    (post-transfer-hook (uint principal principal) (response bool uint))
    (pre-mint-hook (uint principal) (response bool uint))
    (post-mint-hook (uint principal) (response bool uint))
    (pre-burn-hook (uint principal) (response bool uint))
    (post-burn-hook (uint principal) (response bool uint))
  )
)

(define-trait math-trait
  (
    (add (uint uint) (response uint uint))
    (subtract (uint uint) (response uint uint))
    (multiply (uint uint) (response uint uint))
    (divide (uint uint) (response uint uint))
    (square-root (uint) (response uint uint))
    (power (uint uint) (response uint uint))
    (sqrt (uint) (response uint uint))
    (abs (uint) (response uint uint))
    (min (uint uint) (response uint uint))
    (max (uint uint) (response uint uint))
  )
)

(define-trait flash-loan-receiver-trait
  (
    (execute-operation (principal uint principal (buff 256)) (response bool uint))
    (on-flash-loan (principal uint principal (buff 256)) (response bool uint))
  )
)

(define-trait pool-creation-trait
  (
    (create-instance (principal principal (buff 256)) (response principal uint)) ;; token-a, token-b, params
  )
)

(define-trait factory-trait
  (
    (create-pool (principal principal uint (buff 256)) (response principal uint))
    (get-pool (principal principal) (response (optional principal) uint))
    (get-pool-count () (response uint uint))
    (register-pool-implementation (uint principal) (response bool uint))
  )
)

(define-trait router-trait
  (
    (swap-exact-tokens-for-tokens (uint (list 10 principal) principal uint) (response (list 10 uint) uint))
    (swap-tokens-for-exact-tokens (uint (list 10 principal) principal uint) (response (list 10 uint) uint))
    (get-amounts-out (uint (list 10 principal)) (response (list 10 uint) uint))
    (get-amounts-in (uint (list 10 principal)) (response (list 10 uint) uint))
  )
)

(define-trait yield-optimizer-trait
  (
    (optimize-allocation (principal uint) (response (list 10 (tuple (strategy principal) (allocation uint))) uint))
    (get-optimal-allocation (principal uint) (response (list 10 (tuple (strategy principal) (allocation uint))) uint))
    (rebalance-portfolio (principal) (response bool uint))
  )
)
