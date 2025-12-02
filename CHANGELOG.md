# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **Enhanced Circuit Breaker**: Implemented `contracts/security/circuit-breaker.clar` with comprehensive interface support for lending systems, including `record-success`, `record-failure`, and `check-circuit-state`.
- **Keeper Coordination**: Implemented `contracts/automation/keeper-coordinator.clar` with batch execution logic for protocol maintenance tasks.

### Fixed
- **Compilation Errors**:
  - Resolved `err` type indeterminacy in `dimensional-engine.clar` by explicit unwrapping of `collateral-manager` calls.
  - Resolved `err` type indeterminacy in `funding-rate-calculator.clar` for `open-interest` retrieval.
  - Fixed list expression syntax in `keeper-coordinator.clar`.
  - Harmonized return types in `comprehensive-lending-system.clar` circuit breaker checks.
- **Line Endings**: Converted multiple contract files from CRLF to LF to satisfy Clarity parser requirements.
- **Trait Implementations**: Corrected function signatures in `funding-rate-calculator.clar` to match defined traits.
- **Dependency Management**: Updated `Clarinet.toml` contract deployment order to resolve unresolved contract references.

### Changed
- Refactored `check-circuit-breaker` in `comprehensive-lending-system.clar` to use explicit `match` flow for robust error propagation.
- Updated `funding-rate-calculator.clar` to use `get-real-time-price` and `get-twap` with proper lookback window from `oracle-aggregator-v2`.
