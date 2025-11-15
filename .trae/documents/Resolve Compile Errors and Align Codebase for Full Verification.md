## Objectives

- Align the codebase with Clarity 4 standards by integrating new functions like `contract-hash`, `restrict-assets`, and `to-ascii` to enhance security and functionality.
- Reduce 62 compile errors to zero and align all modules to canonical traits
- Verify implementations with compile gates and unit tests per subsystem
- Maintain non-interactive checks and update documentation/artifacts through execution

## Phase 1: Canonical Traits & Manifests

- Map all `(use-trait ...)` to canonical entries in `Clarinet.toml`:
  - `sip-010-ft-trait` → `.sip-010-ft-trait.sip-010-ft-trait`
  - `rbac-trait` → `.base-traits.rbac-trait`
  - `pausable-trait` → `.base-traits.pausable-trait`
  - `circuit-breaker-trait` → `.monitoring-security-traits.circuit-breaker-trait`
  - `oracle-aggregator-v2-trait` → `.oracle-aggregator-v2-trait.oracle-aggregator-v2-trait`
- Remove `.all-traits.*` and `.traits.*` references that are not registered
- Normalize token/governance traits across `contracts/tokens/**` and gov modules
- Ensure non-interactive `clarinet check` by pre-populating deployment plan or using the `--manifest-path` with scoped manifests

## Phase 2: High-Impact Compile Blockers (Targeted Fixes)

- `dex-factory-v2.clar`:
  - Replace `map-to-list` with a supported idiom (maintain a registry list or iterate keys with helper)
  - **Clarity 4 Enhancement**: Implement `get-all-pool-types` and `get-all-pools` using the `to-ascii` function to provide readable string-based outputs.
- Tokens (e.g., `cxd-token.clar`):
  - Fix SIP‑010 trait import to canonical; ensure trait contract exists and signatures match SIP‑010
- `math_lib_advanced.clar`:
  - Remove duplicate `log2`; align math function names and signatures used by CLP/Router
- `mev-protector.clar`:
  - Remove/replace lambda mapping and `.utils.encoding` calls; use named helpers and supported encoding approach
- `external-oracle-adapter.clar`:
  - Close list expression; correct trait import lines (resolve `.oracle-trait`, `.sip-010-ft-trait` paths)
- `sbtc-integration.clar`:
  - Fix `match` arm type mismatch so both branches return the same `(response ...)` type
- `access/traits/access-traits.clar`:
  - Correct type spec parse errors (e.g., `initial-owner`), validate trait methods and signatures
- Modules referencing `.all-traits` (e.g., `budget-manager.clar`, `pools/tiered-pools.clar`):
  - Replace with canonical trait paths and register contracts if missing
- Governance (proposal/voting):
  - Replace event macros with `print`; ensure `has-voting-power` returns expected type; verify `asserts!` sequences and state updates conform to Clarity

## Phase 3: Router v3 Completion

- **Clarity 4 Enhancement**: Secure external calls within the router by implementing `restrict-assets` post-conditions to prevent unauthorized asset transfers during swaps.

- Implement neighbors via Factory v2 (`get-pool` over known tokens) to build adjacency list
- Implement Dijkstra (distances, predecessors) with non-mutating reconstruction
- Add minimal caching for common pairs; add unit tests (single-hop, multi-hop, slippage guard, hop limit)

## Phase 4: CLP Tick Math & Liquidity

- **Clarity 4 Enhancement**: Bolster security by integrating `contract-hash` checks, allowing other contracts to verify the CLP contract's integrity before interaction.

- Implement `get-sqrt-price-from-tick`, `get-tick-from-price` via `math-lib-concentrated`
- Implement `add/remove-liquidity`, fee growth inside ranges; position NFT lifecycle
- Add unit tests for tick conversion, liquidity computations, fee growth

## Phase 5: Lending Helpers & Health Factor

- Implement `check-not-paused`, `accrue-interest`, `get-asset-price-safe`
- Health factor math and PoR enforcement
- Add tests: supply/borrow/repay, liquidation paths, health factor validation

## Phase 6: Governance/Tokens SIP‑010 Compliance

- Normalize token trait usage; fix governance token principal references
- Add tests for SIP‑010 transfers/approvals and proposal/voting flows

## Phase 7: Manifests & Compile Gates

- Expand test manifests progressively; run non-interactive `clarinet check` per gate
- Record outcomes in capability matrix and documentation suite

## QA & Acceptance

- Each module: compile clean + unit tests passing
- Full manifest: `clarinet check` passes with zero errors
- Docs updated with version metadata; alignment matrix complete; handover checklists signed off

## Sequence

1) Canonical traits & manifests normalization
1) Targeted compile blockers fixes (tokens, factory, math libs, oracle adapter, mev, governance)
3) Router v3 completion + tests
4) CLP implementation + tests
5) Lending stabilization + tests
6) Governance/Tokens compliance + tests
7) Manifest expansion and final compile gate

## Notes

- Keep changes minimal and idiomatic; avoid unsupported macros/lambdas
- Maintain non-interactive checks and update artifacts after each gate
