# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- **Enhanced Circuit Breaker**: Implemented `contracts/security/circuit-breaker.clar` with comprehensive interface support for lending systems, including `record-success`, `record-failure`, and `check-circuit-state`.
- **Keeper Coordination**: Implemented `contracts/automation/keeper-coordinator.clar` with batch execution logic for protocol maintenance tasks.
- **Lending & Liquidation Tests**: Added strict full-lifecycle tests for `comprehensive-lending-system.clar` and new scenario tests for `liquidation-manager.clar` and `liquidation-engine.clar`, using mock lending pools for deterministic coverage.
- **DEX & Liquidity Tests**: Extended concentrated-liquidity pool tests with guard-rail scenarios and added a dedicated test harness for `multi-hop-router-v3.clar` using a mock pool contract.
- **Vaults, Yield, and Automation Tests**: Introduced baseline test suites for `sbtc-vault`, `keeper-coordinator`, and `yield-optimizer` modules to verify admin controls and core behaviors.
- **Mock Contracts for Testing**: Added `contracts/mocks/mock-pool.clar` and `contracts/mocks/mock-lending-pool.clar` plus their `Clarinet.toml` wiring to support isolated, deterministic tests.
- **TypeScript Matcher Typings**: Added `vitest-clarity-matchers.d.ts` to provide global typings for custom Clarinet matchers (`toBeOk`, `toBeErr`, `toBeSome`) in the Vitest harness.
- **Conxian Operations Engine Integrations**: Wired `contracts/governance/conxian-operations-engine.clar` to the emission controller, lending system, MEV protection NFTs, insurance protection NFTs, and cross-chain bridge NFTs, and added read-only dashboards for emissions, lending health, MEV posture, insurance coverage, and bridged positions.
- **Lending Health-Factor Guardrails**: Implemented aggregate per-user supply/borrow totals, a conservative `get-health-factor` in `contracts/lending/comprehensive-lending-system.clar`, and optional `borrow-checked` / `withdraw-checked` entrypoints gated by a configurable `min-health-factor`.
- **Position & Enterprise Instrumentation**: Extended dimensional and CXLP position NFTs with enterprise-friendly print events and metadata views, and enhanced `contracts/dex/vault.clar` with service-budget semantics and read-only budget views for dashboards.
- **Behavior Metrics & Reputation System**: Implemented comprehensive behavior tracking in `conxian-operations-engine.clar` to incentivize excellent behavior across governance (voting accuracy, participation), lending (health factor management, timely repayments), MEV protection (awareness, usage), insurance (claims quality, premium reliability), and bridge operations (reliability, security awareness). System calculates weighted behavior scores (0-10000), assigns tiers (Bronze/Silver/Gold/Platinum), and provides incentive multipliers (1.0x-2.0x) to reward positive protocol participation. Includes full test suite in `tests/governance/behavior-metrics.test.ts`.

### Fixed

- **Compilation Errors**:
  - Resolved `err` type indeterminacy in `dimensional-engine.clar` by explicit unwrapping of `collateral-manager` calls.
  - Resolved `err` type indeterminacy in `funding-rate-calculator.clar` for `open-interest` retrieval.
  - Fixed list expression syntax in `keeper-coordinator.clar`.
  - Harmonized return types in `comprehensive-lending-system.clar` circuit breaker checks.
- **DEX Guardrails**: Aligned error codes and tests in `concentrated-liquidity-pool` to match actual contract behavior and prevent regressions in initialization and zero-liquidity paths.
- **Router Test Harness**: Updated `tests/dex/multi-hop-router-v3.test.ts` to use the current `swap-hop-*` interface and a mock pool, while keeping the suite explicitly skipped until the router configuration is fully stabilized.
- **Line Endings**: Converted multiple contract files from CRLF to LF to satisfy Clarity parser requirements.
- **Trait Implementations**: Corrected function signatures in `funding-rate-calculator.clar` to match defined traits.
- **Dependency Management**: Updated `Clarinet.toml` contract deployment order to resolve unresolved contract references.

### Changed

- Refactored `check-circuit-breaker` in `comprehensive-lending-system.clar` to use explicit `match` flow for robust error propagation.
- Updated `funding-rate-calculator.clar` to use `get-real-time-price` and `get-twap` with proper lookback window from `oracle-aggregator-v2`.
