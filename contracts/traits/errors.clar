;; =
;; CONXIAN PROTOCOL ERROR CODES
;; =
;; Error codes are grouped by category with 1000s increments

;; --- General Errors (1000-1999) ---
(define-constant ERR_UNKNOWN u1000)
(define-constant ERR_UNAUTHORIZED u1001)
(define-constant ERR_NOT_OWNER u1002)
(define-constant ERR_CONTRACT_PAUSED u1003)
(define-constant ERR_CONTRACT_NOT_PAUSED u1004)
(define-constant ERR_INVALID_INPUT u1005)
(define-constant ERR_ALREADY_INITIALIZED u1006)
(define-constant ERR_NOT_INITIALIZED u1007)

;; --- Arithmetic Errors (2000-2999) ---
(define-constant ERR_OVERFLOW u2000)
(define-constant ERR_UNDERFLOW u2001)
(define-constant ERR_DIVISION_BY_ZERO u2002)
(define-constant ERR_INSUFFICIENT_BALANCE u2003)
(define-constant ERR_EXCEEDS_LIMIT u2004)

;; --- Token Operation Errors (3000-3999) ---
(define-constant ERR_TOKEN_TRANSFER_FAILED u3000)
(define-constant ERR_TOKEN_MINTING_DISABLED u3001)
(define-constant ERR_TOKEN_BURNING_DISABLED u3002)
(define-constant ERR_INSUFFICIENT_ALLOWANCE u3003)
(define-constant ERR_TRANSFER_DISABLED u3004)
(define-constant ERR_ZERO_AMOUNT u3005)

;; --- Protocol-Specific Errors (4000-4999) ---
(define-constant ERR_EMISSION_LIMIT_EXCEEDED u4000)
(define-constant ERR_STAKING_NOT_ACTIVE u4001)
(define-constant ERR_STAKING_LOCKED u4002)
(define-constant ERR_REWARD_RATE_TOO_HIGH u4003)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u4004)
(define-constant ERR_SLIPPAGE_EXCEEDED u4005)

;; --- Oracle & Price Feed Errors (5000-5999) ---
(define-constant ERR_ORACLE_STALE_PRICE u5000)
(define-constant ERR_ORACLE_INVALID_PRICE u5001)
(define-constant ERR_PRICE_TOO_OLD u5002)
(define-constant ERR_PRICE_OUT_OF_BOUNDS u5003)

;; --- Governance Errors (6000-6999) ---
(define-constant ERR_PROPOSAL_NOT_FOUND u6000)
(define-constant ERR_PROPOSAL_ALREADY_EXECUTED u6001)
(define-constant ERR_VOTING_PERIOD_ENDED u6002)
(define-constant ERR_INSUFFICIENT_VOTING_POWER u6003)
(define-constant ERR_QUORUM_NOT_REACHED u6004)

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