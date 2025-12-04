# Stabilization Phase Tasks

## Phase 1: Compilation & Build Integrity (COMPLETED)
- [x] **Fix Circular Dependency**: Reorder `Clarinet.toml` so `tier-manager` loads before `protocol-fee-switch`.
- [x] **Fix Protocol Fee Switch**: Resolve `match` type ambiguity in `contracts/core/protocol-fee-switch.clar`.
- [x] **Verify Build**: Run `clarinet check` until 0 errors.

## Phase 2: Safety Hardening (IN PROGRESS)
- [ ] **Audit `unwrap-panic`**: Replace 180+ instances with `unwrap!` and error constants.
  - [ ] `contracts/security/enhanced-circuit-breaker.clar` (Partially started)
  - [ ] `contracts/tokens/cxd-price-initializer.clar`
  - [ ] `contracts/proposal-engine.clar`
  - [ ] [Full list in Review Report]

## Phase 3: Test System Restoration

- [ ] **Fix Oracle**: Replace `oracle-adapter-stub.clar` with `oracle-mock.clar` in `Clarinet.toml`.
- [ ] **Deduplicate Tests**: Merge `stacks/tests` into `tests/`.
- [ ] **Restore Load Tests**: Create `load-test.yml`.

## Phase 4: Verification

- [ ] **Run Full Suite**: `npm test` must pass.
- [ ] **Deployment Rehearsal**: Dry-run deployment to Testnet.
