# Dimensional System Remediation Tasks

## Phase 1: Baseline and Encoding

- [x] Create PRD (documentation/prd/dimensional-system-prd.md)
- [x] Create tasks plan (this file)
- [x] Normalize foundation manifest: add clarity_version=3, epoch="3.0"
- [x] Unify encoding utils to sha256(to-consensus-buff? ...)
- [x] Clarinet check (foundation)

## Phase 2: Manifests & Router

- [ ] Ensure [contracts.all-traits] and depends_on in all manifests
- [x] Disable legacy multi-hop router v3 in test manifest
- [ ] Disable legacy multi-hop router v3 in root manifest
- [ ] Ensure remapping: dex-router -> dimensional/advanced-router-dijkstra
- [ ] Clarinet check (core, test)

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

## Phase 5: MEV & Nakamoto

- [ ] Fix mev-protector response types and circuit-breaker handling; unify encoding
- [ ] Centralize Nakamoto calls via block-utils
- [ ] Clarinet check (root)

## Phase 6: Root Manifest Normalization

- [ ] De-duplicate [contracts.*] entries; fix names to match addresses
- [ ] Ensure consistent deployer/address across manifests
- [ ] Final Clarinet check (root)

## Verification

- [ ] Static scan: ensure no banned functions (principal-to-buff-33, to-consensus-buff?, keccak256, etc.)
- [ ] Unit/integration tests for router/factory/MEV/oracle/positions
