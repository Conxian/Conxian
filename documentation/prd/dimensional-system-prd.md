# Conxian Dimensional System PRD (SDK 3.8.1 & Nakamoto Standard)

## 1. Overview

- Dimensional architecture integrates routing, pools, position/NFTs, oracles, and MEV protection under Bitcoin-finalized, tenure-aware operations on Stacks.
- This PRD codifies the target state, acceptance criteria, and remediation scope based on the codebase scan and Clarinet checks.

## 2. Objectives

- Tenure-aware, Bitcoin-finalized swaps and positions with deterministic encoding and MEV protection.
- Unified routing via advanced Dijkstra router; retire legacy multi-hop v3 path.
- Deterministic token ordering in factory and canonical trait/manifest policy.
- Clean manifests (foundation, core, test, root) with consistent deployer/addressing.

## 3. Scope

- Contracts: dim-registry, dimensional-oracle, position-nft/manager, advanced-router-dijkstra, dex-factory, pools (concentrated/stable/weighted), mev-protector, block-utils, encoding.
- Manifests: stacks/Clarinet.foundation.toml, stacks/Clarinet.core.toml, stacks/Clarinet.test.toml, root Clarinet.toml.
- Tooling/CI: Clarinet 3.8.1, test harness alignment.

## 4. Architectural Principles

- Centralized traits via `.all-traits.<trait>` for imports and implementations; no principal-qualified trait ids.
- Token parameters typed `<sip-010-ft-trait>`; dynamic dispatch for token calls.
- Deterministic encoding: `sha256(unwrap-panic (to-consensus-buff payload))`; strictly avoid non-standard conversions.
- Nakamoto integration: `get-burn-block-info?` (>=6 conf), `get-tenure-info?`, `get-block-info?` via centralized `block-utils`.
- Deterministic principal ordering: owner-managed `token-order` map.
- Secrets & Wallets: no mnemonics in manifests; store in `.env` (gitignored). Derive deterministic wallets via `@stacks/wallet-sdk` and update configs programmatically.

## 5. Functional Requirements

- Routing
  - Advanced Dijkstra router provides optimal multi-hop path selection and statistics.
  - Legacy router v3 disabled in manifests; if present, must not use banned functions.
- Factory
  - Create pools with deterministic token ordering and registry registration.
  - Admin controls for pool types and implementations.
- Pools
  - Concentrated, stable, weighted pools expose unified swap and quoting APIs compatible with router.
- Positions & NFTs
  - Position lifecycle tracked; NFT alignment with SIP-009; tenure/time-aware updates.
- MEV Protection
  - Commit-reveal scheme with deterministic encoding and optional circuit breaker integration.
- Oracles
  - Dimensional oracle and adapters provide price/timestamp/TWAP; strict response typing.

## 6. Non-Functional Requirements

- Security: circuit breaker/pausable, access control roles, audit registry integration.
- Determinism: all encodings and orderings canonical; no environment-dependent behavior.
- Maintainability: manifests sanity, no duplicate contract entries; modular utilities.

## 7. Acceptance Criteria

- Core manifest compiles cleanly (already satisfied).
- Test manifest compiles with zero errors after remediation.
- Root manifest compiles after normalization of contract names and references.
- Encoding utilities use only `sha256(unwrap-panic (to-consensus-buff ...))`.
- Router integration targets advanced Dijkstra contract; legacy router disabled.
- No banned/non-standard functions present in codebase.
- Secrets are not stored in manifests; `.env` is authoritative for mnemonics. Wallet derivation script exists and config/wallets.* reflect derived addresses.

## 8. Gaps Identified (from checks)

- Trait/contract misuse: direct ST1.* principals and `.all-traits` as contract calls.
- Encoding divergence: `to-consensus-buff?` used; duplicate encoding utils. (Resolved: unified to `to-consensus-buff`.)
- Legacy router v3 uses banned ops and undefined helpers.
- MEV protector: response typing and parentheses errors; circuit-breaker handling.
- Missing helpers: `max`, `range`; wrong arities and undefined functions in multiple modules.
- Manifest/address inconsistencies (e.g., circuit-breaker name mismatch in root).
- Nakamoto utilities: incorrect arity/syntax; should be centralized.

## 9. Remediation Plan (High-Level)

1) Manifests hygiene: fix foundation clarity settings; ensure `[contracts.all-traits]` and consistent deployer.
2) Encoding unification: canonicalize `contracts/utils/encoding.clar` and remove duplicates.
3) Router: disable v3 in manifests; standardize on advanced-router-dijkstra.
4) Traits: replace static principals/contract names with trait imports and admin-set principals.
5) Helpers/arities: add math utilities; implement missing functions or gate features.
6) Nakamoto: route through `block-utils` wrappers.

## 10. Milestones

- M1: Foundation + encoding pass green.
- M2: Test manifest reduced to <10 errors (router/MEV/manifest fixes).
- M3: Test manifest green (traits/static refs/arity fixes).
- M4: Root manifest normalized and green.

## 11. Risks & Mitigations

- Wide surface area: address by staged manifests and small atomic patches.
- Contract name drift: add remaps or adjust manifests to match code references.
- Legacy modules: disable in manifests; refactor later.

## 12. Verification

- Clarinet checks for foundation/core/test/root per milestone.
- Static scans: banned functions, trait usage, encoding calls.
- Unit/integration tests for router, factory, MEV, oracle, positions.

## 13. Terminology and Component Naming (Unified)

- Router (standard): Advanced Dijkstra Router
  - Contract name: advanced-router-dijkstra
  - Trait name: advanced-router-dijkstra-trait
  - Legacy router v3: disabled in manifests; not a target for further development.
- Oracle (standard): Dimensional Oracle
  - Contract name: oracle-aggregator-v2 (also referenced as dimensional-oracle)
  - Functionality: TWAP, manipulation detection, circuit breaker hooks.
- Factory: dex-factory-v2 (multi-pool support)
- Pools: concentrated-liquidity-pool, stable-swap, weighted-pool
- MEV Protection: mev-protector (commit-reveal, batch auction, sandwich detection)
- Encoding: canonical encoding via sha256(unwrap-panic (to-consensus-buff payload)) only, implemented in centralized encoding utilities.

## 14. Current Status Snapshot (as of 2025-11-02)

- Manifests
  - Foundation manifest normalization: completed (clarity_version=3, epoch="3.0").
  - Test manifest: legacy multi-hop router v3 disabled; core compiles are reported clean.
  - Root manifest: legacy router v3 disabling pending; contract name normalization pending.
- Router
  - Advanced Dijkstra router: designated as the canonical router; integration work ongoing.
  - Legacy multi-hop router v3: disabled in manifests; no active root/test entries post-alignment.
- Encoding
  - Encoding utilities unified on `sha256(unwrap-panic (to-consensus-buff ...))` policy.
  - Non-standard conversions remain banned.
- Traits & Static References
  - Centralized trait usage via use-trait imports against the aggregator; avoid principal-qualified trait identifiers.
  - Sweep for static ST* references is planned; replace with admin-set principals or trait-typed parameters.
- Oracle & MEV
  - Dimensional oracle (oracle-aggregator-v2) enhancements planned for TWAP/manipulation detection.
  - MEV protections planned: commit-reveal, batch auction, sandwich detection; circuit-breaker integration.

## 19. Secrets & Wallets (Operational Guidance)

- Store mnemonics only in `.env` (gitignored). Never commit secrets to manifests.
- Use `npm run derive:wallets` to deterministically derive system wallets from the approved mnemonic and update config files.
- Align `DEPLOYER_ADDRESS` in `.env` with the derived deployer; the script aborts on mismatch.

## 15. Cross-References

- Execution Status: documentation/PRD_EXECUTION_UPDATE.md
- Task Checklist: documentation/prd/tasks.md

## 16. Revision History

- 2025-11-02
  - Added unified terminology section for router, oracle, factory, pools, MEV, and encoding.
  - Documented current status snapshot to reflect the latest development and manifest states.
  - Clarified encoding policy to explicitly include unwrap-panic inside canonical utilities and restrict to-consensus-buff usage.
  - Added cross-references to Execution Update and Task Checklist for alignment.
- 2025-11-03
  - Integrated benchmarking addendum and quarterly review framework.
  - Noted router integration tests and performance benchmarks for advanced-router-dijkstra.
- 2025-11-05
  - Updated encoding policy to `to-consensus-buff` (no `?`) across PRD.
  - Added Secrets & Wallets operational guidance; moved mnemonics to `.env` and added wallet derivation process.
  - Status snapshot updated: manifests alignment (consistent deployer, testnet expected-sender), router v3 disabled, encoding unified.

## 17. Benchmarking Alignment Addendum

- Benchmarking report: documentation/benchmarking/benchmarking-report.md (authoritative for KPI targets and quarterly framework)
- Alignment goals: meet/exceed Tier‑1 benchmarks across routing latency, quote accuracy, slippage, liquidity depth, oracle/MEV protections, and UX.
- Implementation linkage: router standardization, oracle TWAP/manip thresholds, MEV batch auctions, liquidity incentives, UX transparency.

## 18. Quarterly Review Framework

- Inputs: CI perf logs, liquidity depth metrics, oracle/MEV alert stats, UX analytics.
- Cadence: Quarterly executive review; monthly engineering checkpoints.
- KPI targets: As specified in benchmarking-report.md; update targets annually.
- Adjustments: Roadmap refinements based on KPI delta; publish in PRD_EXECUTION_UPDATE.md.
