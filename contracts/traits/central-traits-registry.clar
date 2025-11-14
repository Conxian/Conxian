;; ===========================================
;; CENTRAL TRAITS REGISTRY
;; ===========================================
;; @desc Conxian Protocol Trait Registry. This contract serves as a central registry for all traits in the protocol.
;; It imports and re-exports traits from various modules, providing a single, consistent entry point for other contracts.
;; This modular approach optimizes compilation speed and improves organization.
;;
;; @sdk SDK 3.9+ & Nakamoto Standard
;;
;; @architecture Modular trait system for optimal compilation speed
;; - Domain-specific trait files for better organization
;; - Import-based composition for minimal compilation overhead
;; - Backward compatibility maintained for existing contracts

;; ===========================================
;; IMPORT MODULAR TRAIT MODULES
;; ===========================================

;; Core foundational traits - always needed
(use-trait ownable-trait .base-traits.ownable-trait)
(use-trait pausable-trait .base-traits.pausable-trait)
(use-trait rbac-trait .base-traits.rbac-trait)
(use-trait math-trait .base-traits.math-trait)

;; DEX-specific traits - loaded on demand
(use-trait sip-010-ft-trait .dex-traits.sip-010-ft-trait)
(use-trait pool-trait .dex-traits.pool-trait)
(use-trait factory-trait .dex-traits.factory-trait)

;; Governance traits - for voting systems
(use-trait dao-trait .governance-traits.dao-trait)
(use-trait governance-token-trait .governance-traits.governance-token-trait)

;; Multi-dimensional DeFi traits
(use-trait dimensional-trait .dimensional-traits.dimensional-trait)
(use-trait dim-registry-trait .dimensional-traits.dim-registry-trait)

;; Price feeds and risk management
(use-trait oracle-aggregator-v2-trait .oracle-risk-traits.oracle-aggregator-v2-trait)
(use-trait risk-trait .oracle-risk-traits.risk-trait)
(use-trait liquidation-trait .oracle-risk-traits.liquidation-trait)

;; System monitoring and security
(use-trait protocol-monitor-trait .monitoring-security-traits.protocol-monitor-trait)
(use-trait circuit-breaker-trait .monitoring-security-traits.circuit-breaker-trait)
