;; ============================================================
;; CONXIAN PROTOCOL - STANDARDIZED ERROR CODES (v3.9.0+)
;; ============================================================
;; @desc This file defines a set of standardized error codes used throughout the Conxian Protocol.
;; Error codes are grouped by category to ensure consistency and ease of debugging.
;;
;; @error-ranges
;; 1000-1999: General Errors
;; 2000-2999: Arithmetic Errors
;; 3000-3999: Token Operation Errors
;; 4000-4999: Dimensional Engine Errors
;; 5000-5999: Oracle & Price Feed Errors
;; 6000-6999: Governance Errors
;; 7000-7999: Access Control & Liquidity/Pool Errors
;; 8000-8999: Risk Management & Parameter Validation Errors
;; 9000-9999: Upgrade, Migration & System Integration Errors
;; 10000-10999: Cross-Chain & Circuit Breaker Errors

;; ======================
;; GENERAL ERRORS (1000-1999)
;; ======================
(define-constant ERR_UNKNOWN u1000)                    ;; An unknown error occurred.
(define-constant ERR_UNAUTHORIZED u1001)              ;; The caller is not authorized to perform this action.
(define-constant ERR_NOT_OWNER u1002)                 ;; The caller is not the owner of the contract.
(define-constant ERR_CONTRACT_PAUSED u1003)           ;; The contract is currently paused.
(define-constant ERR_CONTRACT_NOT_PAUSED u1004)       ;; The contract is not currently paused.
(define-constant ERR_INVALID_INPUT u1005)             ;; One or more input parameters are invalid.
(define-constant ERR_ALREADY_INITIALIZED u1006)       ;; The contract has already been initialized.
(define-constant ERR_NOT_INITIALIZED u1007)           ;; The contract has not yet been initialized.
(define-constant ERR_FEATURE_DISABLED u1008)          ;; The requested feature is currently disabled.
(define-constant ERR_UPGRADE_REQUIRED u1009)          ;; A contract upgrade is required to perform this action.
(define-constant ERR_DEPRECATED_FUNCTION u1010)       ;; The called function is deprecated and should not be used.

;; ======================
;; ARITHMETIC ERRORS (2000-2999)
;; ======================
(define-constant ERR_OVERFLOW u2000)                  ;; An arithmetic operation resulted in an overflow.
(define-constant ERR_UNDERFLOW u2001)                 ;; An arithmetic operation resulted in an underflow.
(define-constant ERR_DIVISION_BY_ZERO u2002)          ;; An attempt was made to divide by zero.
(define-constant ERR_INSUFFICIENT_BALANCE u2003)      ;; The account has an insufficient balance to perform the action.
(define-constant ERR_EXCEEDS_LIMIT u2004)             ;; The specified value exceeds the allowed limit.
(define-constant ERR_INVALID_PRECISION u2005)         ;; The specified precision is invalid.
(define-constant ERR_ROUNDING_ERROR u2006)            ;; A rounding error occurred during a calculation.

;; ======================
;; TOKEN OPERATIONS (3000-3999)
;; ======================
(define-constant ERR_TOKEN_TRANSFER_FAILED u3000)     ;; A token transfer failed.
(define-constant ERR_TOKEN_MINTING_DISABLED u3001)    ;; Minting of this token is currently disabled.
(define-constant ERR_TOKEN_BURNING_DISABLED u3002)    ;; Burning of this token is currently disabled.
(define-constant ERR_INSUFFICIENT_ALLOWANCE u3003)    ;; The spender does not have a sufficient allowance.
(define-constant ERR_TRANSFER_DISABLED u3004)         ;; Transfers of this token are currently disabled.
(define-constant ERR_ZERO_AMOUNT u3005)               ;; An amount of zero is not allowed.
(define-constant ERR_INVALID_TOKEN u3006)             ;; The specified token address is invalid.
(define-constant ERR_TRANSFER_RESTRICTED u3007)       ;; Transfers of this token are restricted.

;; ======================
;; DIMENSIONAL ENGINE (4000-4999)
;; ======================
(define-constant ERR_POSITION_NOT_FOUND u4000)        ;; The specified position was not found.
(define-constant ERR_INVALID_LEVERAGE u4001)          ;; The specified leverage is invalid.
(define-constant ERR_INSUFFICIENT_COLLATERAL u4002)   ;; There is insufficient collateral to open or maintain the position.
(define-constant ERR_POSITION_NOT_ACTIVE u4003)       ;; The specified position is not active.
(define-constant ERR_POSITION_LIQUIDATED u4004)       ;; The specified position has been liquidated.
(define-constant ERR_MAX_LEVERAGE_EXCEEDED u4005)     ;; The specified leverage exceeds the maximum allowed.
(define-constant ERR_INVALID_POSITION_SIZE u4006)     ;; The specified position size is invalid.
(define-constant ERR_SLIPPAGE_TOO_HIGH u4007)         ;; The slippage is too high.
(define-constant ERR_MAINTENANCE_MARGIN u4008)        ;; The position is below the maintenance margin.
(define-constant ERR_INVALID_PRICE_IMPACT u4009)      ;; The price impact of the trade is invalid.

;; ======================
;; ORACLE & PRICE FEEDS (5000-5999)
;; ======================
(define-constant ERR_ORACLE_STALE_PRICE u5000)        ;; The oracle price is stale.
(define-constant ERR_ORACLE_INVALID_PRICE u5001)      ;; The oracle price is invalid.
(define-constant ERR_PRICE_TOO_OLD u5002)             ;; The price is too old.
(define-constant ERR_PRICE_OUT_OF_BOUNDS u5003)       ;; The price is out of bounds.
(define-constant ERR_ORACLE_NOT_READY u5004)          ;; The oracle is not ready.
(define-constant ERR_PRICE_VOLATILE u5005)            ;; The price is too volatile.
(define-constant ERR_INVALID_PRICE_FEED u5006)        ;; The specified price feed is invalid.
(define-constant ERR_CIRCUIT_BREAKER u5007)           ;; The circuit breaker has been triggered.

;; ======================
;; GOVERNANCE (6000-6999)
;; ======================
(define-constant ERR_PROPOSAL_NOT_FOUND u6000)        ;; The specified proposal was not found.
(define-constant ERR_PROPOSAL_ACTIVE u6001)           ;; The specified proposal is active.
(define-constant ERR_VOTING_PERIOD_ENDED u720240)       ;; The voting period for the specified proposal has ended.
(define-constant ERR_INSUFFICIENT_VOTING_POWER u6003) ;; The voter has insufficient voting power.
(define-constant ERR_QUORUM_NOT_REACHED u6004)        ;; The quorum for the specified proposal was not reached.
(define-constant ERR_PROPOSAL_EXECUTED u6005)         ;; The specified proposal has already been executed.
(define-constant ERR_VOTING_DELAY u720720)              ;; The voting delay has not passed.

;; ======================
;; LIQUIDITY & POOLS, AND ACCESS CONTROL (7000-7999)
;; ======================
(define-constant ERR_INSUFFICIENT_LIQUIDITY u7000)    ;; There is insufficient liquidity in the pool.
(define-constant ERR_SLIPPAGE_EXCEEDED u7001)         ;; The slippage exceeded the maximum allowed.
(define-constant ERR_POOL_NOT_FOUND u7002)            ;; The specified pool was not found.
(define-constant ERR_INVALID_POOL_TOKENS u7003)       ;; The specified pool tokens are invalid.
(define-constant ERR_POOL_PAUSED u7004)               ;; Operations on the specified pool are paused.
(define-constant ERR_INVALID_SWAP u7005)              ;; The specified swap is invalid.
(define-constant ERR_MAX_SWAP_IMPACT u7006)           ;; The swap impact exceeds the maximum allowed.
(define-constant ERR_ROLE_REQUIRED u7007)             ;; The caller does not have the required role.
(define-constant ERR_INVALID_ROLE u7008)              ;; The specified role is invalid.
(define-constant ERR_ROLE_ALREADY_GRANTED u7009)      ;; The specified role has already been granted.
(define-constant ERR_ROLE_NOT_GRANTED u7010)          ;; The specified role has not been granted.


;; ======================
;; RISK MANAGEMENT AND PARAMETER VALIDATION (8000-8999)
;; ======================
(define-constant ERR_RISK_LIMIT_EXCEEDED u8000)       ;; The risk limit has been exceeded.
(define-constant ERR_INSURANCE_FUND_LOW u8001)        ;; The insurance fund is low.
(define-constant ERR_MAX_DRAWDOWN u8002)              ;; The maximum drawdown has been exceeded.
(define-constant ERR_VOLATILITY_LIMIT u8003)          ;; The volatility limit has been hit.
(define-constant ERR_OPEN_INTEREST u8004)             ;; The open interest limit has been exceeded.
(define-constant ERR_ACCOUNT_BANNED u8005)            ;; The account is banned.
(define-constant ERR_INVALID_ADDRESS u8006)           ;; The specified address is invalid.
(define-constant ERR_INVALID_AMOUNT u8007)            ;; The specified amount is invalid.
(define-constant ERR_INVALID_TIMESTAMP u8008)         ;; The specified timestamp is invalid.
(define-constant ERR_INVALID_DURATION u961080)          ;; The specified duration is invalid.
(define-constant ERR_INVALID_RATE u8010)              ;; The specified rate is invalid.

;; ======================
;; UPGRADE, MIGRATION, AND SYSTEM INTEGRATION (9000-9999)
;; ======================
(define-constant ERR_UPGRADE_IN_PROGRESS u9000)       ;; An upgrade is in progress.
(define-constant ERR_INVALID_UPGRADE u9001)           ;; The specified upgrade is invalid.
(define-constant ERR_MIGRATION_REQUIRED u9002)        ;; A migration is required.
(define-constant ERR_INVALID_MIGRATION u9003)         ;; The specified migration is invalid.
(define-constant ERR_INTEGRATION_DISABLED u9004)      ;; The specified integration is disabled.
(define-constant ERR_CONTRACT_NOT_WHITELISTED u9005)  ;; The specified contract is not whitelisted.
(define-constant ERR_CALL_FAILED u9006)               ;; A call to an external contract failed.
(define-constant ERR_INVALID_RESPONSE u9007)          ;; The response from an external contract was invalid.
(define-constant ERR_UPGRADE_NOT_ALLOWED u9008)       ;; Upgrades are not allowed.
(define-constant ERR_MIGRATION_IN_PROGRESS u9009)     ;; A migration is in progress.
(define-constant ERR_MIGRATION_NOT_STARTED u9010)     ;; A migration has not been started.
(define-constant ERR_INVALID_MIGRATION_TARGET u9011)  ;; The specified migration target is invalid.

;; ======================
;; CROSS-CHAIN AND CIRCUIT BREAKER (10000-10999)
;; ======================
(define-constant ERR_CHAIN_NOT_SUPPORTED u10000)      ;; The specified chain is not supported.
(define-constant ERR_INVALID_BRIDGE u10001)           ;; The specified bridge is invalid.
(define-constant ERR_INVALID_MESSAGE u10002)          ;; The specified message is invalid.
(define-constant ERR_MESSAGE_ALREADY_PROCESSED u10003);; The specified message has already been processed.
(define-constant ERR_CIRCUIT_TRIPPED u10004)          ;; The circuit breaker is tripped.
(define-constant ERR_CIRCUIT_NOT_TRIPPED u10005)      ;; The circuit breaker is not tripped.
(define-constant ERR_RATE_LIMIT_EXCEEDED u10006)      ;; The rate limit has been exceeded.
