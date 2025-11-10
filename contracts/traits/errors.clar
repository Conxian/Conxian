;; ============================================================
;; CONXIAN PROTOCOL - STANDARDIZED ERROR CODES (v3.9.0+)
;; ============================================================
;; Error codes follow a consistent pattern:
;; - Grouped by category with 1000s increments
;; - Each category has 100 available codes (e.g., 1000-1099, 2000-2099)
;; - New errors should be added in the appropriate category

;; ======================
;; GENERAL ERRORS (1000-1099)
;; ======================
(define-constant ERR_UNKNOWN u1000)                    ;; An unknown error occurred
(define-constant ERR_UNAUTHORIZED u1001)              ;; Caller is not authorized
(define-constant ERR_NOT_OWNER u1002)                 ;; Caller is not the owner
(define-constant ERR_CONTRACT_PAUSED u1003)           ;; Contract is paused
(define-constant ERR_CONTRACT_NOT_PAUSED u1004)       ;; Contract is not paused
(define-constant ERR_INVALID_INPUT u1005)             ;; Invalid input parameters
(define-constant ERR_ALREADY_INITIALIZED u1006)       ;; Already initialized
(define-constant ERR_NOT_INITIALIZED u1007)           ;; Not initialized
(define-constant ERR_FEATURE_DISABLED u1008)          ;; Feature is disabled
(define-constant ERR_UPGRADE_REQUIRED u1009)          ;; Contract upgrade required
(define-constant ERR_DEPRECATED_FUNCTION u1010)       ;; Function is deprecated

;; ======================
;; ARITHMETIC ERRORS (2000-2099)
;; ======================
(define-constant ERR_OVERFLOW u2000)                  ;; Arithmetic overflow
(define-constant ERR_UNDERFLOW u2001)                 ;; Arithmetic underflow
(define-constant ERR_DIVISION_BY_ZERO u2002)          ;; Division by zero
(define-constant ERR_INSUFFICIENT_BALANCE u2003)      ;; Insufficient balance
(define-constant ERR_EXCEEDS_LIMIT u2004)             ;; Value exceeds limit
(define-constant ERR_INVALID_PRECISION u2005)         ;; Invalid precision
(define-constant ERR_ROUNDING_ERROR u2006)            ;; Rounding error

;; ======================
;; TOKEN OPERATIONS (3000-3099)
;; ======================
(define-constant ERR_TOKEN_TRANSFER_FAILED u3000)     ;; Token transfer failed
(define-constant ERR_TOKEN_MINTING_DISABLED u3001)    ;; Token minting disabled
(define-constant ERR_TOKEN_BURNING_DISABLED u3002)    ;; Token burning disabled
(define-constant ERR_INSUFFICIENT_ALLOWANCE u3003)    ;; Insufficient allowance
(define-constant ERR_TRANSFER_DISABLED u3004)         ;; Transfer disabled
(define-constant ERR_ZERO_AMOUNT u3005)               ;; Zero amount not allowed
(define-constant ERR_INVALID_TOKEN u3006)             ;; Invalid token address
(define-constant ERR_TRANSFER_RESTRICTED u3007)       ;; Transfer restricted

;; ======================
;; DIMENSIONAL ENGINE (4000-4199)
;; ======================
(define-constant ERR_POSITION_NOT_FOUND u4000)        ;; Position not found
(define-constant ERR_INVALID_LEVERAGE u4001)          ;; Invalid leverage
(define-constant ERR_INSUFFICIENT_COLLATERAL u4002)   ;; Insufficient collateral
(define-constant ERR_POSITION_NOT_ACTIVE u4003)       ;; Position not active
(define-constant ERR_POSITION_LIQUIDATED u4004)       ;; Position liquidated
(define-constant ERR_MAX_LEVERAGE_EXCEEDED u4005)     ;; Max leverage exceeded
(define-constant ERR_INVALID_POSITION_SIZE u4006)     ;; Invalid position size
(define-constant ERR_SLIPPAGE_TOO_HIGH u4007)         ;; Slippage too high
(define-constant ERR_MAINTENANCE_MARGIN u4008)        ;; Below maintenance margin
(define-constant ERR_INVALID_PRICE_IMPACT u4009)      ;; Invalid price impact

;; ======================
;; ORACLE & PRICE FEEDS (5000-5199)
;; ======================
(define-constant ERR_ORACLE_STALE_PRICE u5000)        ;; Stale price data
(define-constant ERR_ORACLE_INVALID_PRICE u5001)      ;; Invalid price
(define-constant ERR_PRICE_TOO_OLD u5002)             ;; Price too old
(define-constant ERR_PRICE_OUT_OF_BOUNDS u5003)       ;; Price out of bounds
(define-constant ERR_ORACLE_NOT_READY u5004)          ;; Oracle not ready
(define-constant ERR_PRICE_VOLATILE u5005)            ;; Price too volatile
(define-constant ERR_INVALID_PRICE_FEED u5006)        ;; Invalid price feed
(define-constant ERR_CIRCUIT_BREAKER u5007)           ;; Circuit breaker triggered

;; ======================
;; GOVERNANCE (6000-6199)
;; ======================
(define-constant ERR_PROPOSAL_NOT_FOUND u6000)        ;; Proposal not found
(define-constant ERR_PROPOSAL_ACTIVE u6001)           ;; Proposal is active
(define-constant ERR_VOTING_PERIOD_ENDED u6002)       ;; Voting period ended
(define-constant ERR_INSUFFICIENT_VOTING_POWER u6003) ;; Insufficient voting power
(define-constant ERR_QUORUM_NOT_REACHED u6004)        ;; Quorum not reached
(define-constant ERR_PROPOSAL_EXECUTED u6005)         ;; Already executed
(define-constant ERR_VOTING_DELAY u6006)              ;; Voting delay not passed

;; ======================
;; LIQUIDITY & POOLS (7000-7199)
;; ======================
(define-constant ERR_INSUFFICIENT_LIQUIDITY u7000)    ;; Insufficient liquidity
(define-constant ERR_SLIPPAGE_EXCEEDED u7001)         ;; Slippage too high
(define-constant ERR_POOL_NOT_FOUND u7002)            ;; Pool not found
(define-constant ERR_INVALID_POOL_TOKENS u7003)       ;; Invalid pool tokens
(define-constant ERR_POOL_PAUSED u7004)               ;; Pool operations paused
(define-constant ERR_INVALID_SWAP u7005)              ;; Invalid swap parameters
(define-constant ERR_MAX_SWAP_IMPACT u7006)           ;; Max swap impact exceeded

;; ======================
;; RISK MANAGEMENT (8000-8199)
;; ======================
(define-constant ERR_RISK_LIMIT_EXCEEDED u8000)       ;; Risk limit exceeded
(define-constant ERR_INSURANCE_FUND_LOW u8001)        ;; Insurance fund low
(define-constant ERR_MAX_DRAWDOWN u8002)              ;; Max drawdown exceeded
(define-constant ERR_VOLATILITY_LIMIT u8003)          ;; Volatility limit hit
(define-constant ERR_OPEN_INTEREST u8004)             ;; Open interest limit
(define-constant ERR_ACCOUNT_BANNED u8005)            ;; Account is banned

;; ======================
;; UPGRADE & MIGRATION (9000-9099)
;; ======================
(define-constant ERR_UPGRADE_IN_PROGRESS u9000)       ;; Upgrade in progress
(define-constant ERR_INVALID_UPGRADE u9001)           ;; Invalid upgrade
(define-constant ERR_MIGRATION_REQUIRED u9002)        ;; Migration required
(define-constant ERR_INVALID_MIGRATION u9003)         ;; Invalid migration

;; ======================
;; CROSS-CHAIN (10000-10099)
;; ======================
(define-constant ERR_CHAIN_NOT_SUPPORTED u10000)      ;; Chain not supported
(define-constant ERR_INVALID_BRIDGE u10001)           ;; Invalid bridge
(define-constant ERR_INVALID_MESSAGE u10002)          ;; Invalid message
(define-constant ERR_MESSAGE_ALREADY_PROCESSED u10003);; Message already processed

;; --- Access Control (7000-7999) ---
(define-constant ERR_ROLE_REQUIRED u7000)
(define-constant ERR_INVALID_ROLE u7001)
(define-constant ERR_ROLE_ALREADY_GRANTED u7002)
(define-constant ERR_ROLE_NOT_GRANTED u7003)

;; --- Parameter Validation (8000-8999) ---
(define-constant ERR_INVALID_ADDRESS u8000)
(define-constant ERR_INVALID_AMOUNT u8001)
(define-constant ERR_INVALID_TIMESTAMP u8002)
(define-constant ERR_INVALID_DURATION u8003)
(define-constant ERR_INVALID_RATE u8004)

;; --- System Integration (9000-9999) ---
(define-constant ERR_INTEGRATION_DISABLED u9000)
(define-constant ERR_CONTRACT_NOT_WHITELISTED u9001)
(define-constant ERR_CALL_FAILED u9002)
(define-constant ERR_INVALID_RESPONSE u9003)

;; --- Circuit Breaker (10000-10999) ---
(define-constant ERR_CIRCUIT_TRIPPED u10000)
(define-constant ERR_CIRCUIT_NOT_TRIPPED u10001)
(define-constant ERR_RATE_LIMIT_EXCEEDED u10002)

;; --- Migration & Upgrade (11000-11999) ---
(define-constant ERR_UPGRADE_NOT_ALLOWED u11000)
(define-constant ERR_MIGRATION_IN_PROGRESS u11001)
(define-constant ERR_MIGRATION_NOT_STARTED u11002)
(define-constant ERR_INVALID_MIGRATION_TARGET u11003)

;; =
;; ERROR CODE RANGES:
;; 1000-1999: General Errors
;; 2000-2999: Arithmetic Errors
;; 3000-3999: Token Operation Errors
;; 4000-4999: Protocol-Specific Errors
;; 5000-5999: Oracle & Price Feed Errors
;; 6000-6999: Governance Errors
;; 7000-7999: Access Control
;; 8000-8999: Parameter Validation
;; 9000-9999: System Integration
;; 10000-10999: Circuit Breaker
;; 11000-11999: Migration & Upgrade
;; =