# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **Cross-Chain Dimension**: Implemented `btc-adapter.clar` with 6-block Bitcoin finality verification.
- **Risk Dimension**: Enhanced `oracle-aggregator-v2.clar` with tenure-aware price tracking and circuit breaker hooks.
- **DLC Integration**: Added `dlc-manager.clar` and `dlc-manager-trait.clar` to support Native Bitcoin Lending and Derivatives.
- **Traits**: Added missing traits (`collateral-manager-trait`, `risk-manager-trait`, `funding-rate-calculator-trait`, `position-manager-trait`) to `Clarinet.toml`.

### Changed
- **Liquidation Engine**: Updated `liquidation-engine.clar` to use correct trait imports and fixed syntax errors.
- **Dimensional Engine**: Fixed `dimensional-engine.clar` to correctly handle `sip-010-ft-trait` in `open-position` and `close-position` calls.
- **Configuration**: Updated `Clarinet.toml` to include new DLC contracts and fix dependency ordering.

### Fixed
- Resolved multiple `clarinet check` errors related to missing traits and invalid contract calls.
- Fixed `use-trait` paths in `dimensional-engine.clar` and `liquidation-engine.clar`.

## [0.1.0] - 2025-11-22
### Added
- Initial Conxian Protocol architecture.
- 6-Dimensional System Design (Spatial, Temporal, Risk, Cross-Chain, Institutional, Governance).
