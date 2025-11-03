# Dimensional System Remediation Tasks

## Phase 1: Baseline and Encoding

- [x] Create PRD (documentation/prd/dimensional-system-prd.md)
- [x] Create tasks plan (this file)
- [x] Normalize foundation manifest: add clarity_version=3, epoch="3.0"
- [x] Unify encoding utils to sha256(to-consensus-buff? ...)
- [x] Unify encoding utils to sha256(unwrap-panic (to-consensus-buff? ...))
- [x] Clarinet check (foundation)

## Phase 2: Manifests & Router

- [ ] Ensure [contracts.all-traits] and depends_on in all manifests
- [x] Disable legacy multi-hop router v3 in test manifest
 - [x] Disable legacy multi-hop router v3 in root manifest (no root Clarinet entry present); removed legacy router from deployments/default.testnet-plan.yaml and stacks/deployments/default.testnet-plan.yaml
- [ ] Ensure remapping: dex-router -> dimensional/advanced-router-dijkstra
- [ ] Clarinet check (core, test)

## Phase 2b: Benchmarking Instrumentation

- [ ] Add router pathfinding and quote estimation latency probes (p95 reporting)
- [ ] Add liquidity depth dashboards (top pairs TVL, slippage bands)
- [ ] Integrate oracle deviation alerts and circuit breaker telemetry
- [ ] Add UX telemetry (swap success, revert ratio, fee transparency adherence)

### Manifest hygiene tasks (new)

- [ ] Fix stacks/deployments/default.simnet-plan.yaml paths: prefix all paths with "..\\"
- [ ] Update stacks/deployments/default.simnet-plan.yaml deployer address to ST3N0ZC9HBPDEBEJ1H1QFGMJF3PSNGW3FYZSVN513
- [ ] Update deployments/default.testnet-plan.yaml expected-sender to ST3N0ZC9HBPDEBEJ1H1QFGMJF3PSNGW3FYZSVN513

## Phase 3: Traits & Static References

- [ ] Sweep for `.all-traits` or ST*.all-traits contract calls and replace with `use-trait`/`impl-trait`
- [ ] Replace static ST* contract references with admin-set principals or trait-typed params
- [ ] Clarinet check (test)

## Phase 4: Missing Helpers & Arities

- [ ] Add math helpers (maxu/maxi) to modules using `max`
- [ ] Replace `range` usage with fold/counter loops
- [ ] Implement undefined functions or gate features: price-history, get-lp-fee-bps, execute-pool-rebalance, calculate-claimable-yield
- [ ] Fix arity mismatches highlighted by checks
- [ ] Clarinet check (test)
  
### Phase 4a: Math & Type Hygiene (new)

- [x] Add local `abs(int)`, `max(uint)`, and `min(uint)` helpers in liquidation-engine.clar
- [ ] Unify return types across if branches (avoid mixing uint and response types) in cxvg-token, yield-distribution-engine, advanced-router-dijkstra
- [ ] Move state changes out of `define-read-only` functions (e.g., dim-revenue-adapter)
- [ ] Fix invalid `contract-of` type usages by ensuring the trait is imported (dex-factory-v2: sip-010-ft-trait)

## Phase 5: MEV & Nakamoto

- [ ] Fix mev-protector response types and circuit-breaker handling; unify encoding
- [ ] Centralize Nakamoto calls via block-utils
- [ ] Clarinet check (root)

## Phase 6: Root Manifest Normalization

- [ ] De-duplicate [contracts.*] entries; fix names to match addresses
- [ ] Ensure consistent deployer/address across manifests
- [ ] Final Clarinet check (root)

## Verification

- [ ] Static scan: ensure no banned functions (principal-to-buff-33/32, keccak256, non-canonical conversions). Note: to-consensus-buff? is allowed only within canonical encoding utilities paired with sha256 and unwrap-panic.
- [ ] Unit/integration tests for router/factory/MEV/oracle/positions
- [ ] Benchmarking report updated quarterly with measured metrics (see documentation/benchmarking/benchmarking-report.md)

## Revision History

- 2025-11-03
  - Added benchmarking instrumentation tasks and verification hooks; linked benchmarking report for quarterly updates.

## Cross-References

- PRD: documentation/prd/dimensional-system-prd.md
- Execution Update: documentation/PRD_EXECUTION_UPDATE.md

## Revision History

- 2025-11-02
  - Clarified encoding policy to include unwrap-panic and restrict to-consensus-buff? usage to canonical utilities.
  - Updated verification banned function list to remove to-consensus-buff? and specify non-canonical conversions.
  - Added cross-references to PRD and Execution Update for documentation alignment.
