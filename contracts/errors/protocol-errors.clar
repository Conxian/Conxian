;; protocol-errors.clar
;; Centralized error code definitions for Conxian Protocol
;; Standardizes all error codes across contracts to prevent conflicts
;; and improve maintainability

;; =============================================================================
;; AUTHORIZATION ERRORS (1000-1099)
;; =============================================================================
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_NOT_OWNER (err u1001))
(define-constant ERR_NOT_AUTHORIZED (err u1002))
(define-constant ERR_CONTRACT_NOT_AUTHORIZED (err u1003))
(define-constant ERR_INVALID_SIGNATURE (err u1004))
(define-constant ERR_EXPIRED_SIGNATURE (err u1005))

;; =============================================================================
;; SYSTEM STATE ERRORS (1100-1199)
;; =============================================================================
(define-constant ERR_PROTOCOL_PAUSED (err u1100))
(define-constant ERR_SYSTEM_PAUSED (err u1101))
(define-constant ERR_EMERGENCY_PAUSE (err u1102))
(define-constant ERR_CIRCUIT_BREAKER_OPEN (err u1103))
(define-constant ERR_MAINTENANCE_MODE (err u1104))

;; =============================================================================
;; ARITHMETIC ERRORS (1200-1299)
;; =============================================================================
(define-constant ERR_OVERFLOW (err u1200))
(define-constant ERR_UNDERFLOW (err u1201))
(define-constant ERR_DIVISION_BY_ZERO (err u1202))
(define-constant ERR_INVALID_CALCULATION (err u1203))

;; =============================================================================
;; BALANCE & TOKEN ERRORS (1300-1399)
;; =============================================================================
(define-constant ERR_INSUFFICIENT_BALANCE (err u1300))
(define-constant ERR_NOT_ENOUGH_BALANCE (err u1301))
(define-constant ERR_INVALID_AMOUNT (err u1302))
(define-constant ERR_ZERO_AMOUNT (err u1303))
(define-constant ERR_AMOUNT_TOO_HIGH (err u1304))
(define-constant ERR_TOKEN_NOT_FOUND (err u1305))

;; =============================================================================
;; CONFIGURATION ERRORS (1400-1499)
;; =============================================================================
(define-constant ERR_INVALID_CONFIG_KEY (err u1400))
(define-constant ERR_INVALID_CONFIG_VALUE (err u1401))
(define-constant ERR_CONFIG_NOT_SET (err u1402))
(define-constant ERR_ALREADY_INITIALIZED (err u1403))
(define-constant ERR_NOT_INITIALIZED (err u1404))

;; =============================================================================
;; DEPENDENCY & INTEGRATION ERRORS (1500-1599)
;; =============================================================================
(define-constant ERR_DEPENDENCY_FAILED (err u1500))
(define-constant ERR_CONTRACT_CALL_FAILED (err u1501))
(define-constant ERR_ORACLE_UNAVAILABLE (err u1502))
(define-constant ERR_ORACLE_STALE (err u1503))
(define-constant ERR_TRANSFER_HOOK_FAILED (err u1504))
(define-constant ERR_EXTERNAL_CALL_FAILED (err u1505))

;; =============================================================================
;; MARKET & LIQUIDITY ERRORS (1600-1699)
;; =============================================================================
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1600))
(define-constant ERR_SLIPPAGE_TOO_HIGH (err u1601))
(define-constant ERR_PRICE_DEVIATION (err u1602))
(define-constant ERR_MARKET_INACTIVE (err u1603))
(define-constant ERR_POOL_NOT_FOUND (err u1604))

;; =============================================================================
;; LENDING & BORROWING ERRORS (1700-1799)
;; =============================================================================
(define-constant ERR_COLLATERAL_INSUFFICIENT (err u1700))
(define-constant ERR_HEALTH_FACTOR_TOO_LOW (err u1701))
(define-constant ERR_BORROW_CAP_EXCEEDED (err u1702))
(define-constant ERR_LIQUIDATION_FAILED (err u1703))
(define-constant ERR_POSITION_NOT_FOUND (err u1704))

;; =============================================================================
;; GOVERNANCE ERRORS (1800-1899)
;; =============================================================================
(define-constant ERR_VOTING_PERIOD_ENDED (err u1800))
(define-constant ERR_ALREADY_VOTED (err u1801))
(define-constant ERR_QUORUM_NOT_MET (err u1802))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u1803))
(define-constant ERR_EXECUTION_DELAYED (err u1804))

;; =============================================================================
;; REGULATORY & COMPLIANCE ERRORS (1900-1999)
;; =============================================================================
(define-constant ERR_KYC_REQUIRED (err u1900))
(define-constant ERR_COMPLIANCE_FAILED (err u1901))
(define-constant ERR_REGION_RESTRICTED (err u1902))
(define-constant ERR_SANCTIONED_ADDRESS (err u1903))
(define-constant ERR_TIER_INSUFFICIENT (err u1904))

;; =============================================================================
;; EMISSION & MINTING ERRORS (2000-2099)
;; =============================================================================
(define-constant ERR_EMISSION_LIMIT_EXCEEDED (err u2000))
(define-constant ERR_MINTING_DISABLED (err u2001))
(define-constant ERR_BURNING_DISABLED (err u2002))
(define-constant ERR_SUPPLY_CAP_REACHED (err u2003))

;; =============================================================================
;; TIME & BLOCK ERRORS (2100-2199)
;; =============================================================================
(define-constant ERR_INVALID_BLOCK_HEIGHT (err u2100))
(define-constant ERR_TIMESTAMP_TOO_OLD (err u2101))
(define-constant ERR_TIMESTAMP_TOO_FUTURE (err u2102))
(define-constant ERR_LOCK_PERIOD_NOT_MET (err u2103))

;; =============================================================================
;; NFT & POSITION ERRORS (2200-2299)
;; =============================================================================
(define-constant ERR_TOKEN_NOT_OWNER (err u2200))
(define-constant ERR_TOKEN_ALREADY_EXISTS (err u2201))
(define-constant ERR_TOKEN_DOES_NOT_EXIST (err u2202))
(define-constant ERR_INVALID_TOKEN_ID (err u2203))

;; =============================================================================
;; ENTERPRISE ERRORS (2300-2399)
;; =============================================================================
(define-constant ERR_ENTERPRISE_DISABLED (err u2300))
(define-constant ERR_INSTITUTIONAL_LIMIT_EXCEEDED (err u2301))
(define-constant ERR_ADVANCED_ORDER_FAILED (err u2302))
(define-constant ERR_COMPLIANCE_CHECK_FAILED (err u2303))

;; =============================================================================
;; CROSS-CHAIN ERRORS (2400-2499)
;; =============================================================================
(define-constant ERR_BRIDGE_UNAVAILABLE (err u2400))
(define-constant ERR_INVALID_TXID (err u2401))
(define-constant ERR_TX_ALREADY_PROCESSED (err u2402))
(define-constant ERR_NOT_CONFIRMED (err u2403))
(define-constant ERR_VERIFICATION_FAILED (err u2404))

;; =============================================================================
;; BATCH & AUCTION ERRORS (2500-2599)
;; =============================================================================
(define-constant ERR_BATCH_TOO_LARGE (err u2500))
(define-constant ERR_AUCTION_NOT_ACTIVE (err u2501))
(define-constant ERR_BID_TOO_LOW (err u2502))
(define-constant ERR_AUCTION_ENDED (err u2503))

;; =============================================================================
;; DIMENSIONAL SYSTEM ERRORS (2600-2699)
;; =============================================================================
(define-constant ERR_DIMENSION_NOT_SUPPORTED (err u2600))
(define-constant ERR_INVALID_DIMENSION_PARAMS (err u2601))
(define-constant ERR_DIMENSIONAL_CALCULATION_FAILED (err u2602))

;; =============================================================================
;; GAMIFICATION ERRORS (2700-2799)
;; =============================================================================
(define-constant ERR_POINTS_CALCULATION_FAILED (err u2700))
(define-constant ERR_REWARD_CLAIM_FAILED (err u2701))
(define-constant ERR_EPOCH_NOT_ACTIVE (err u2702))
(define-constant ERR_ALREADY_CLAIMED (err u2703))
(define-constant ERR_INVALID_EPOCH (err u2704))
(define-constant ERR_CLAIM_WINDOW_CLOSED (err u2705))
(define-constant ERR_INVALID_PROOF (err u2706))
(define-constant ERR_INSUFFICIENT_POOL (err u2707))

;; =============================================================================
;; UTILITY ERRORS (2800-2899)
;; =============================================================================
(define-constant ERR_INVALID_ADDRESS (err u2800))
(define-constant ERR_INVALID_PRINCIPAL (err u2801))
(define-constant ERR_DATA_NOT_FOUND (err u2802))
(define-constant ERR_OPERATION_FAILED (err u2803))
(define-constant ERR_INVALID_ASSET (err u2804))
(define-constant ERR_INTEREST_ACCRUAL_FAILED (err u2805))