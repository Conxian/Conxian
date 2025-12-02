;; ===========================================================
;; CONXIAN PROTOCOL - TRAIT ARCHITECTURE
;; ===========================================================
;; @desc Index of the 15 modular trait files defining the protocol interfaces
;; @nakamoto-optimized Production-grade trait architecture
;; @version 2.1.0 (Current)

;; ===========================================
;; TRAIT FILE INDEX
;; ===========================================

;; MODULE 01: SIP STANDARDS (File: sip-standards.clar)
;; - sip-010-ft-trait (Fungible tokens)
;; - sip-009-nft-trait (NFTs)
;; - sip-018-metadata-trait (Metadata)
;; - ft-mintable-trait (Minting extension)

;; MODULE 02: CORE PROTOCOL & ACCESS (Files: core-traits.clar, core-protocol.clar)
;; - ownable-trait (core-traits)
;; - pausable-trait (core-traits)
;; - rbac-trait (core-traits)
;; - reentrancy-guard-trait (core-traits)
;; - upgradeable-trait (core-protocol)
;; - revenue-distributor-trait (core-protocol)
;; - token-coordinator-trait (core-protocol)

;; MODULE 03: DEFI PRIMITIVES (Files: defi-primitives.clar, defi-traits.clar)
;; - pool-trait (defi-primitives)
;; - pool-factory-trait (defi-primitives)
;; - router-trait (defi-primitives)
;; - concentrated-liquidity-trait (defi-primitives)
;; - vault-trait (defi-traits)
;; - flash-loan-trait (defi-traits)
;; - factory-trait (defi-traits)

;; MODULE 04: DIMENSIONAL ENGINE (File: dimensional-traits.clar)
;; - dimensional-trait
;; - position-manager-trait ✨ Key for position management
;; - collateral-manager-trait ✨ Key for deposits/withdrawals
;; - funding-rate-calculator-trait ✨ Key for perpetuals
;; - dimensional-engine-trait

;; MODULE 05: ORACLE & PRICING (File: oracle-pricing.clar)
;; - oracle-trait
;; - oracle-aggregator-v2-trait
;; - price-initializer-trait
;; - dimensional-oracle-trait

;; MODULE 06: RISK MANAGEMENT (File: risk-management.clar)
;; - risk-manager-trait
;; - liquidation-trait
;; - risk-oracle-trait
;; - funding-trait

;; MODULE 07: CROSS-CHAIN & BITCOIN (File: cross-chain-traits.clar)
;; - dlc-manager-trait ✨ Key for native Bitcoin lending
;; - btc-bridge-trait
;; - cross-chain-verifier-trait
;; - sbtc-trait

;; MODULE 08: GOVERNANCE (File: governance-traits.clar)
;; - dao-trait
;; - proposal-engine-trait
;; - proposal-trait
;; - governance-token-trait
;; - voting-trait

;; MODULE 09: SECURITY & MONITORING (File: security-monitoring.clar)
;; - circuit-breaker-trait
;; - mev-protector-trait
;; - protocol-monitor-trait
;; - audit-registry-trait

;; MODULE 10: MATH & UTILITIES (File: math-utilities.clar)
;; - math-trait
;; - fixed-point-math-trait
;; - finance-metrics-trait
;; - utils-trait
;; - encoding-trait

;; ADDITIONAL DEFINITIONS
;; - controller-traits.clar (Minting control)
;; - queue-traits.clar (Queue operations)
;; - trait-errors.clar (Standardized error constants)

;; ===========================================
;; NAKAMOTO OPTIMIZATIONS
;; ===========================================
;; ✅ All traits support sub-second block times
;; ✅ Tenure-aware state management
;; ✅ Bitcoin finality validation (6+ confirmations)
;; ✅ Async operation support
;; ✅ MEV protection via tenure ordering
;; ✅ Real-time liquidation checks
;; ✅ Event-driven oracle updates

;; ===========================================
;; USAGE PATTERNS
;; ===========================================
;; Example 1: Import SIP-010 token trait
;; (use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
;;
;; Example 2: Import RBAC trait from core-traits
;; (use-trait rbac-trait .core-traits.rbac-trait)
;;
;; Example 3: Import DLC manager for Bitcoin integration
;; (use-trait dlc-manager-trait .cross-chain-traits.dlc-manager-trait)
