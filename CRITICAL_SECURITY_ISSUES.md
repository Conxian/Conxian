# Conxian Protocol: Critical Security Issues — Expert Stacks Security Review

**Date:** December 22, 2025  
**Status:** 🔴 NOT MAINNET READY (Nakamoto-Unsafe, Governance-Incomplete, Launch-Blocked)

---

## P0 Issues (MUST FIX BEFORE ANY PUBLIC DEPLOYMENT)

### 1. Nakamoto Block Time Constants (120x Misconfiguration)

**Severity:** P0 – Protocol-wide timing corruption  
**Impact:** All time-based logic using `block-height` is effectively 120x faster than intended under Nakamoto (5s blocks). This breaks vesting, locks, loans, and emission schedules.

**Root Cause:** Constants were calculated assuming ~10-minute blocks (Bitcoin) or 1 block/minute, not 5 seconds/block.

**Affected Files:**

| File | Constant | Current Value | Correct Value | Impact |
|------|----------|---------------|---------------|--------|
| `token-emission-controller.clar:18` | `EMISSION_PERIOD` | `u756864000` | `u6307200` | 1-year epoch becomes ~3 days |
| `token-emission-controller.clar:19` | `EPOCH_BLOCKS` | `u756864000` | `u6307200` | Same as above |
| `token-emission-controller.clar:24` | `TIMELOCK_BLOCKS` | `u290304000` | `u241920` | 2-week timelock becomes ~20 days |
| `token-emission-controller.clar:25` | `EMERGENCY_TIMELOCK` | `u20736000` | `u17280` | 1-day becomes ~1.4 days |
| `self-launch-coordinator.clar:45` | `OPEX_LOAN_BLOCKS_PER_YEAR` | `u756864000` | `u6307200` | 5-year loan becomes ~600 years |
| `founder-vesting.clar:18` | `VESTING_DURATION` | `u2102400` | `u25228800` | 4-year vest becomes ~12 days |
| `founder-vesting.clar:19` | `CLIFF_DURATION` | `u525600` | `u6307200` | 1-year cliff becomes ~3 days |

**Correct Reference:**  
**Nakamoto Block Time:** 5 seconds/block → 6,307,200 blocks/year

**Required Actions:**

- [ ] Replace all hardcoded time constants above with correct values.  
- [ ] Audit for ANY other `block-height`-based time arithmetic, especially for:
  - vesting, cliffs, and lockups
  - loan durations and grace periods
  - governance voting / timelocks
- [ ] Prefer `burn-block-height` for long-term, Bitcoin-aligned timing where appropriate.

**Fix Script:** Use the existing `scripts/apply_nakamoto_fixes.py` to apply and verify updates, then rerun full test suite under Nakamoto assumptions.

---

### 2. Missing Founder Launch Fund Withdrawal (Funds Locked Forever)

**File:** `self-launch-coordinator.clar`  
**Severity:** P0 – Permanent lock of 50% of launch contributions  
**Issue:** `launch-fund-allocation` accumulates 50% of contributions, but there is **no withdrawal path** for the founder or launch entity.

**Current Flow (Simplified):**

```clarity
contribute-funding(amount)
  ├─ launch-portion = amount / 2
  ├─ var-set launch-fund-allocation (+ current launch-portion)
  └─ ❌ NO WITHDRAWAL FUNCTION IMPLEMENTED
```

**Expected Behavior:** Launch operator must be able to pull STX funds out of the contract in a controlled, permissioned way.

**Proposed Fix (per design intent):**

```clarity
(define-public (claim-launch-funds)
  (let ((available (var-get launch-fund-allocation)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> available u0) ERR_INSUFFICIENT_BALANCE)
    (try! (as-contract (stx-transfer? available tx-sender (var-get contract-owner))))
    (var-set launch-fund-allocation u0)
    (print { event: "launch-funds-claimed", amount: available })
    (ok available)
  )
)
```

**Additional Expert Recommendations:**

- [ ] Consider **rate-limiting** or **milestone-based** withdrawals (e.g., linked to governance or vesting conditions).
- [ ] Emit detailed events (block-height, remaining balance) for off-chain accounting.
- [ ] Add tests covering:
  - unauthorized calls
  - re-entrancy-like patterns (sequential calls when balance is 0)
  - state after partial/failed transfers.

**Impact if Unfixed:** Launch economics break; capital is stranded, making the protocol operationally unusable.

---

### 3. Vault Inflation Attack Mitigation Incomplete (Dead Shares Not Actually Burned)

**File:** `vault.clar:164-180`  
**Severity:** P0 – Share accounting corruption enabling theft of future deposits

**Issue:** When `total-shares == 0`, the logic attempts to reserve 1000 "dead shares" conceptually but only subtracts from the first depositor's shares; no actual burn/mint to a dead address occurs.

**Current Code:**

```clarity
(if (is-eq total-shares u0)
  (if (> amount u1000)
    (- amount u1000)  ;; ❌ User gets fewer shares but 1000 not burned/locked
    u0
  )
  (/ (* amount total-shares) total-balance)
)
```

**Attack Vector:**

1. Attacker deposits 1 wei → calculation yields 0 shares due to rounding.
2. Attacker donates a large amount (e.g., 1M tokens) directly to the vault without minting shares.
3. Next honest depositor computes: `shares = amount * 0 / 1M = 0` (rounds down).
4. Attacker then withdraws, capturing value contributed by the new depositor.

**Correct Mitigation Pattern:** Mint a non-withdrawable minimum share balance to a dead/blackhole address on first deposit, so that share price cannot be manipulated from zero.

**Proposed Fix:**

```clarity
(if (is-eq total-shares u0)
  (begin
    ;; Mint 1000 shares to a dead address to establish an initial share price
    (map-set user-shares
      { user: 'ST000000000000000000002AMW42H, asset: asset }
      u1000
    )
    (- amount u1000)
  )
  (/ (* amount total-shares) total-balance)
)
```

**Expert Notes:**

- [ ] Verify that `'ST000000000000000000002AMW42H` is **never** used elsewhere and is treated as unrecoverable.
- [ ] Confirm that `user-shares` updates are consistent with `total-shares` tracking and vault balance.
- [ ] Add tests for:
  - first-deposit scenario
  - small deposits below the 1000-share threshold
  - behavior after large direct donations.

---

### 4. Compliance Manager Not Actually Enforcing KYC (Bypassable Control)

**File:** `compliance-manager.clar:21-29`  
**Severity:** P0/P1 (depending on regulatory exposure) – KYC checks are effectively noop

**Current Implementation:**

```clarity
(define-public (check-kyc-compliance (account principal))
  (let ((info (unwrap! (contract-call? .institutional-account-manager get-account-details account) ERR_UNAUTHORIZED)))
    (asserts! (get kyc-verified info) ERR_COMPLIANCE_FAIL)
    (ok true)
  )
)
```

**Problem:** `institutional-account-manager.register-account()` sets `kyc-verified: true` by default, without any real verification. This means **any registered account automatically passes compliance**.

**Correct Approach:** Compliance should derive from the authoritative KYC registry, not a convenience flag.

**Proposed Fix:**

```clarity
(define-public (check-kyc-compliance (account principal))
  (let ((tier (unwrap! (contract-call? .kyc-registry get-kyc-tier account) ERR_COMPLIANCE_FAIL)))
    (asserts! (>= tier u1) ERR_COMPLIANCE_FAIL) ;; Require at least Basic KYC
    (ok true)
  )
)
```

**Additional Requirements:**

- [ ] Document tier semantics (e.g., `u0 = none`, `u1 = basic`, `u2 = enhanced`, etc.).
- [ ] Ensure **all** compliance-critical flows (lending, borrowing, large transfers, institutional onboarding) call this method or equivalent.
- [ ] Add regression tests confirming:
  - unregistered accounts fail
  - tier downgrades reflect in enforcement.

---

### 5. Oracle Circuit Breaker Hardcoded (Configuration Drift Risk)

**File:** `oracle-aggregator-v2.clar:86-96`  
**Severity:** P1 – Misconfigured risk control, hard to upgrade

**Current Snippet:**

```clarity
(match cb-opt
  ignored (asserts!
    (not (unwrap-panic (contract-call? .circuit-breaker is-circuit-open)))  ;; ❌ Hardcoded
    ERR_CIRCUIT_OPEN
  )
  true
)
```

**Issue:**

- Contract stores a dynamic `circuit-breaker-contract` variable, but **ignores it** in enforcement and instead calls `.circuit-breaker` directly.
- This breaks configurability and can lead to situations where:
  - The configured breaker differs from the enforced one.
  - Governance updates `circuit-breaker-contract` but enforcement still points at the old contract.

**Required Fix (Choose One Approach and Be Consistent):**

1. **Use the dynamic principal:**
   - [ ] Replace `.circuit-breaker` with `circuit-breaker-contract` via `contract-call?` on the stored principal.
2. **Or remove the unused variable:**
   - [ ] If governance is not meant to change the breaker, remove `circuit-breaker-contract` and document `.circuit-breaker` as immutable.

**Additional Recommendations:**

- [ ] Ensure `is-circuit-open` semantics are clearly documented (true = open or closed).
- [ ] Replace `unwrap-panic` with `unwrap!` and explicit error codes where feasible.

---

### 6. Token Emission Controller Not Initialized in Clarinet.toml / Deploy Flow

**Files:** `Clarinet.toml`, deploy/test scripts  
**Severity:** P1 – Emission system non-functional in tests and dev

**Issue:** `token-emission-controller` is deployed but never wired to the token contracts (`cxd-token`, `cxvg-token`) nor initialized with emission limits, leaving the system in an unusable state.

**Missing Initialization (Example in TypeScript using Clarinet Simnet):**

```typescript
// In deploy script or test setup:
await simnet.callPublicFn(
  'token-emission-controller',
  'set-cxd-contract',
  [Cl.contractPrincipal(deployer, 'cxd-token')],
  deployer
);

await simnet.callPublicFn(
  'token-emission-controller',
  'set-cxvg-contract',
  [Cl.contractPrincipal(deployer, 'cxvg-token')],
  deployer
);

await simnet.callPublicFn(
  'token-emission-controller',
  'enable-system-integration',
  [],
  deployer
);

await simnet.callPublicFn(
  'token-emission-controller',
  'initialize-emission-limits',
  [],
  deployer
);
```

**Required Actions:**

- [ ] Add deterministic initialization to:
  - local development setup
  - integration tests
  - any production deployment scripts.
- [ ] Add tests that fail clearly if emission-controller is not properly initialized.

---

### 7. Self-Launch Coordinator Not Registered in Clarinet.toml

**File:** `Clarinet.toml`  
**Severity:** P1 – Launch path untestable, missing from simnet deployments

**Issue:** `self-launch-coordinator.clar` is present in the contracts folder but **not** declared in `Clarinet.toml`, so it is never deployed in local simulations or CI tests.

**Impact:**

- Launch flow cannot be tested end-to-end.
- Integration with other modules (governance, emissions, vaults) is unverified.

**Fix – Add Contract Entry:**

```toml
[contracts.self-launch-coordinator]
path = "contracts/self-launch-coordinator.clar"
address = "STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ"
depends_on = ["cxvg-token", "position-factory", "governance-token"]
```

**Required Actions:**

- [ ] Add entry to `Clarinet.toml` with correct dependencies.
- [ ] Verify deployment order in simnet matches dependency graph.
- [ ] Add integration tests that exercise the full launch flow from contribution to phase advancement.
