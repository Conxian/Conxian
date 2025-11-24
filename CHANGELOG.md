# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added - 2025-11-24
- **Modular Trait Architecture**: Completed migration to centralized trait system
  - All contracts now use standardized `.trait-file.trait-name` pattern
  - Added `get-protocol-fee-rate()` to collateral-manager
  - Added `get-price()` and `get-twap-with-window()` to oracle-aggregator-v2
  - Added `compute-swap()` placeholder to concentrated-liquidity-pool

### Changed - 2025-11-24
- **Contract Reference Standardization**: 
  - Migrated 25+ contracts to use `.roles` instead of dynamic access-control references
  - Updated circuit-breaker references across security contracts
  - Standardized oracle-pricing trait imports
  - Fixed security-monitoring and dimensional-traits imports
- **Dynamic Contract Calls**: Eliminated 7 dynamic `(var-get ...)` calls, replaced with static references
- **Type Safety**: Fixed argument ordering in has-role calls, unwrapped responses properly
- **Function Implementations**: Added missing helper functions across core contracts

### Fixed - 2025-11-24
- **Contract Resolution**: Fixed unresolved contract errors in 15+ files
- **Trait Imports**: Corrected import paths for modular trait architecture
- **Type Mismatches**: Fixed response unwrapping in twap-oracle, pausable, keeper-coordinator
- **Lambda Functions**: Fixed parameter naming collision in mev-protector fold operation
- Reduced compilation errors from 31 to 30 through systematic architectural improvements

### Added - 2025-11-23
- **Cross-Chain Dimension**: Implemented `btc-adapter.clar` with 6-block Bitcoin finality verification.
- **Risk Dimension**: Enhanced `oracle-aggregator-v2.clar` with tenure-aware price tracking and circuit breaker hooks.
- **DLC Integration**: Added `dlc-manager.clar` and `dlc-manager-trait.clar` to support Native Bitcoin Lending and Derivatives.
- **Traits**: Added missing traits (`collateral-manager-trait`, `risk-manager-trait`, `funding-rate-calculator-trait`, `position-manager-trait`) to `Clarinet.toml`.

### Changed - 2025-11-23
- **Liquidation Engine**: Updated `liquidation-engine.clar` to use correct trait imports and fixed syntax errors.
- **Dimensional Engine**: Fixed `dimensional-engine.clar` to correctly handle `sip-010-ft-trait` in `open-position` and `close-position` calls.
- **Configuration**: Updated `Clarinet.toml` to include new DLC contracts and fix dependency ordering.

### Fixed - 2025-11-23
- Resolved multiple `clarinet check` errors related to missing traits and invalid contract calls.
- Fixed `use-trait` paths in `dimensional-engine.clar` and `liquidation-engine.clar`.

## [0.1.0] - 2025-11-22
### Added
- Initial Conxian Protocol architecture.
- 6-Dimensional System Design (Spatial, Temporal, Risk, Cross-Chain, Institutional, Governance).
