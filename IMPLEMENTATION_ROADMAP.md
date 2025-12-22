# Conxian Protocol: Implementation Roadmap

**Date:** December 22, 2025  
**Timeline:** 10 weeks to testnet launch

---

## Priority Alignment (P-Order)

| Priority | Workstream | Ownership & Dependencies | Acceptance Criteria |
| --- | --- | --- | --- |
| **P1** | **Economic Safety Net Hardening** | Risk + Treasury squads; depends on updated `protocol-fee-switch` specs and lending metrics from `comprehensive-lending-system` | Lifecycle doc includes liquidation buffer table per asset; insurance vault trigger logic defined; cross-module stress scenarios documented and rehearsed; integration tests cover fee routing into insurance |
| **P2** | **Founder & OPEX Vault Economics** | Governance + Treasury | `founder-vault.clar` + `opex-vault.clar` deployed with immutable emission curves; DAO override timelocks documented; BUSINESS_VALUE_ROI updated with math + payout timelines |
| **P3** | **Reg Tech Stack Enablement** | Enterprise + Compliance | Travel Rule middleware + trait shipped; sanctions oracle live with Chainhook feed; compliance API endpoints published; enterprise modules gated via new traits |
| **P4** | **Ecosystem SDK / Builder Kit** | Developer Experience | Trait bundle, deployment templates, and testing harness published; docs guide third-party integrations; fee hooks enforce protocol revenue |
| **P5** | **Audit & Formal Verification Track** | Security Office | Specs + threat models finalized for `keeper-coordinator`, `comprehensive-lending-system`, `enterprise-facade`, `proposal-engine`; auditor RFPs issued; formal verification backlog created |

> **Implementation Note:** Each sprint section below now references its related priority. Work must satisfy the acceptance criteria above before moving to the next priority.

---

## Sprint 1: Critical Security Fixes (Week 1-2) — _Covers P1_

### Nakamoto Block Time Constants

**Files to Update:**

```clarity
// token-emission-controller.clar:18-25
(define-constant EMISSION_PERIOD u6307200)  // Was: u756864000
(define-constant EPOCH_BLOCKS u6307200)     // Was: u756864000
(define-constant TIMELOCK_BLOCKS u241920)   // Was: u290304000
(define-constant EMERGENCY_TIMELOCK u17280) // Was: u20736000

// self-launch-coordinator.clar:45
(define-constant OPEX_LOAN_BLOCKS_PER_YEAR u6307200)  // Was: u756864000

// founder-vesting.clar:18-19
(define-constant VESTING_DURATION u25228800)  // Was: u2102400 (4 years)
(define-constant CLIFF_DURATION u6307200)     // Was: u525600 (1 year)

// conxian-insurance-fund.clar:21
(define-constant COOLDOWN_BLOCKS u172800)  // Verify: ~10 days at 5s blocks
```

**Script:** Run `python scripts/apply_nakamoto_fixes.py` (verify it covers all files)

---

### Add Missing Founder Withdrawal Function  _(Blocks P2)_

**File:** `self-launch-coordinator.clar` (add after line 897)

```clarity
(define-public (claim-launch-funds)
  (let ((available (var-get launch-fund-allocation)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> available u0) ERR_INSUFFICIENT_BALANCE)
    (try! (as-contract (stx-transfer? available tx-sender (var-get contract-owner))))
    (var-set launch-fund-allocation u0)
    (print {
      event: "launch-funds-claimed",
      amount: available,
      recipient: (var-get contract-owner),
      timestamp: block-height
    })
    (ok available)
  )
)
```

---

### Fix Vault Inflation Attack  _(Feeds P1 stress scenarios)_

**File:** `vault.clar:164-180`

**Current:**
```clarity
(if (is-eq total-shares u0)
  (if (> amount u1000)
    (- amount u1000)  // ❌ Doesn't burn
    u0
  )
  ...
)
```

**Fixed:**
```clarity
(if (is-eq total-shares u0)
  (begin
    ;; Burn 1000 shares to dead address
    (map-set user-shares {
      user: 'ST000000000000000000002AMW42H,
      asset: asset
    } u1000)
    (map-set vault-shares asset u1000)
    (if (> amount u1000)
      (- amount u1000)
      u0
    )
  )
  (/ (* amount total-shares) total-balance)
)
```

---

### Wire Compliance Manager to KYC Registry  _(Pre-req for P3)_

**File:** `compliance-manager.clar:21-29`

**Replace:**
```clarity
(define-public (check-kyc-compliance (account principal))
  (let ((tier (unwrap! (contract-call? .kyc-registry get-kyc-tier account) ERR_COMPLIANCE_FAIL)))
    (asserts! (>= tier u1) ERR_COMPLIANCE_FAIL)
    (ok true)
  )
)
```

---

### Fix Oracle Circuit Breaker  _(Supports P1/P5 readiness)_

**File:** `oracle-aggregator-v2.clar:86-96`

**Option 1 (Use dynamic):**
```clarity
(match cb-opt
  cb-principal (asserts!
    (not (unwrap-panic (contract-call? cb-principal is-circuit-open)))
    ERR_CIRCUIT_OPEN
  )
  true
)
```

**Option 2 (Remove variable, use hardcoded):**
```clarity
;; Remove: (define-data-var circuit-breaker-contract (optional principal) none)
;; Keep: (contract-call? .circuit-breaker is-circuit-open)
```

---

### Add Self-Launch Coordinator to Clarinet.toml

**File:** `Clarinet.toml` (add before line 832)

```toml
[contracts.self-launch-coordinator]
path = "contracts/self-launch-coordinator.clar"
address = "STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ"
depends_on = ["cxvg-token", "position-factory"]
```

---

## Sprint 2: Gamification Infrastructure (Week 3-4) — _Bridges P1 ➜ P2_

### New Contract: gamification-manager.clar

**Location:** `contracts/governance/gamification-manager.clar`

**Key Functions:**
```clarity
(define-public (claim-rewards (proof (list 12 (buff 32)))))
(define-public (auto-convert-unclaimed (users (list 100 principal))))
(define-read-only (get-user-points (user principal)))
(define-read-only (get-conversion-rates))
```

**Size:** ~300 lines

---

### New Contract: points-oracle.clar

**Location:** `contracts/oracle/points-oracle.clar`

**Key Functions:**
```clarity
(define-public (submit-merkle-root (root (buff 32)) (epoch uint) (signatures (list 5 (buff 65)))))
(define-public (verify-user-points (user principal) (points tuple) (proof (list 12 (buff 32)))))
(define-read-only (get-merkle-root (epoch uint)))
```

**Size:** ~200 lines

---

### Enhance automation-keeper.clar

**File:** `contracts/automation/keeper-coordinator.clar`

**Add Tasks:**
```clarity
(define-public (execute-auto-conversions (batch-size uint)))
(define-public (trigger-opex-repayment))
(define-public (update-behavior-metrics (users (list 50 principal))))
```

**Size:** +150 lines

---

## Sprint 3: Test Coverage (Week 5-6) — _Validates P1/P2 outcomes_

### Priority 1 Tests (Must Have)

**1. Self-Launch Coordinator Tests**

**File:** `tests/governance/self-launch-coordinator.test.ts` (NEW)

```typescript
describe('Self-Launch Coordinator', () => {
  it('splits contributions 50/50')
  it('advances phases correctly')
  it('initializes OPEX loan')
  it('mints NFTs correctly')
  it('allows founder to claim launch funds')
  it('triggers automatic repayment')
});
```

**Lines:** ~300

---

**2. Founder Vesting Tests**

**File:** `tests/governance/founder-vesting.test.ts` (NEW)

```typescript
describe('Founder Vesting', () => {
  it('enforces cliff period')
  it('calculates linear vesting')
  it('supports multiple tokens')
  it('allows partial claims')
  it('prevents unauthorized claims')
});
```

**Lines:** ~200

---

**3. Behavior Reputation Tests**

**File:** `tests/governance/behavior-reputation.test.ts` (NEW)

```typescript
describe('Behavior Reputation', () => {
  it('calculates weighted score')
  it('assigns tiers correctly')
  it('applies multipliers')
  it('records actions')
  it('updates overall metrics')
});
```

**Lines:** ~250

---

**4. Compliance E2E Tests**

**File:** `tests/integration/compliance-e2e.test.ts` (NEW)

```typescript
describe('Compliance E2E', () => {
  it('mints badge on KYC verification')
  it('enforces KYC for enterprise features')
  it('blocks sanctioned users')
  it('enforces region restrictions')
});
```

**Lines:** ~200

---

**5. Vault Inflation Attack Tests**

**File:** `tests/vaults/inflation-attack.test.ts` (NEW)

```typescript
describe('Vault Inflation Attack', () => {
  it('prevents inflation via dead shares')
  it('prevents donation manipulation')
  it('prevents rounding attacks')
});
```

**Lines:** ~150

---

### Priority 2 Tests (Should Have)

**6. OPEX Loan Tests** (~150 lines)  
**7. Genesis Distribution Tests** (~200 lines)  
**8. Governance Execution Tests** (~150 lines)  
**9. Liquidation Tests** (~200 lines)  
**10. Cross-Module Integration Tests** (~300 lines)

**Total New Test Code:** ~2,100 lines

---

## Sprint 4: Governance Implementation (Week 7-8) — _Enables P2/P5_

### Complete Proposal Execution

**File:** `proposal-engine.clar:136-174`

**Add Execution Logic:**
```clarity
(define-public (execute (proposal-id uint))
  (begin
    ;; ... existing validation ...
    
    ;; NEW: Execute targets
    (let ((proposal-data (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND)))
      (try! (execute-proposal-calls 
        (get targets proposal-data)
        (get values proposal-data)
        (get signatures proposal-data)
        (get calldatas proposal-data)
      ))
    )
    
    (try! (contract-call? .proposal-registry set-executed proposal-id))
    (ok true)
  )
)

(define-private (execute-proposal-calls 
  (targets (list 10 principal))
  (values (list 10 uint))
  (signatures (list 10 (string-ascii 64)))
  (calldatas (list 10 (buff 1024)))
)
  ;; Iterate and execute contract-call? for each target
  (ok true)
)
```

---

### Add Proposal Types

**New Contracts:**

**1. `proposal-types.clar`**
```clarity
(define-constant PROPOSAL_TYPE_PARAMETER_CHANGE u1)
(define-constant PROPOSAL_TYPE_CONTRACT_UPGRADE u2)
(define-constant PROPOSAL_TYPE_TREASURY_SPEND u3)
(define-constant PROPOSAL_TYPE_EMERGENCY_ACTION u4)
```

**2. Proposal Templates:**
- Parameter change (fee rates, emission caps)
- Contract upgrade (migration-manager integration)
- Treasury spend (budget allocation)
- Emergency action (pause, circuit breaker)

---

## Sprint 5: Deployment & Monitoring (Week 9-10) — _Prepares P3-P5 launch_

### Testnet Deployment Checklist

**Pre-Deployment:**
- [ ] All Nakamoto constants updated
- [ ] All P0 security issues fixed
- [ ] Test suite passing (90%+ coverage)
- [ ] Clarinet check passing
- [ ] Gas estimates reviewed

**Deployment Steps:**

```bash
# 1. Dry run
python stacksorbit_cli.py deploy --network testnet --dry-run --run-npm-tests

# 2. Review plan
# Check: 150+ contracts, correct order, gas estimates

# 3. Deploy
python stacksorbit_cli.py deploy --network testnet

# 4. Verify
python stacksorbit_cli.py verify --comprehensive

# 5. Initialize
# Run initialization scripts (see LIFECYCLE_FLOWS.md Phase 0)
```

---

### Post-Deployment Initialization

**Script:** `scripts/initialize-testnet.ts` (NEW)

```typescript
async function initializeTestnet() {
  // 1. Token System
  await initTokenSystem();
  
  // 2. Fee Switch
  await configureFeeSwitch();
  
  // 3. Emission Controller
  await initEmissionController();
  
  // 4. Self-Launch
  await initSelfLaunch();
  
  // 5. Founder Vesting
  await initFounderVesting();
  
  // 6. Governance
  await initGovernance();
}
```

---

### Monitoring Setup

**1. Deploy StacksOrbit Dashboard:**
```bash
python stacksorbit_dashboard.py
```

**2. Configure Chainhooks:**
```yaml
# chainhooks/conxian-events.yaml
- event: contract-call
  contract: self-launch-coordinator
  method: contribute-funding
  action: log-contribution

- event: contract-call
  contract: proposal-engine
  method: execute
  action: log-proposal-execution
```

**3. Set Up Alerts:**
- Circuit breaker trips
- Large withdrawals (> $100K)
- Governance proposals created
- OPEX repayment triggers
- Unusual activity (potential exploits)

---

## Sprint 6-10: Feature Development (Week 11-20)

### Sprint 6: Gamification Contracts

- Implement `gamification-manager.clar`
- Implement `points-oracle.clar`
- Enhance `automation-keeper.clar`
- Add tests (100% coverage for new contracts)

### Sprint 7: Off-Chain Services

- Points calculation service
- Attestor network setup (5 nodes, 3-of-5 multisig)
- Automation keeper service
- Monitoring dashboard

### Sprint 8: UI Integration

- Gamification dashboard
- Points tracking
- Claim interface
- Behavior metrics display

### Sprint 9: Enterprise Features

- Complete institutional account management
- Advanced order types (TWAP, Iceberg)
- Compliance reporting
- KYC/AML integration

### Sprint 10: Audit & Mainnet Prep

- Third-party security audit
- Bug bounty launch
- Documentation finalization
- Mainnet deployment plan

---

## Deployment Checklist

### Pre-Launch (Testnet)

**Security:**
- [ ] All P0 issues fixed
- [ ] All P1 issues fixed
- [ ] Test coverage > 90%
- [ ] Clarinet check passing
- [ ] No unwrap-panic in critical paths

**Functionality:**
- [ ] Self-launch coordinator tested
- [ ] Founder vesting tested
- [ ] Gamification system tested
- [ ] Compliance flow tested
- [ ] Emergency procedures tested

**Infrastructure:**
- [ ] Monitoring dashboard deployed
- [ ] Chainhooks configured
- [ ] Alerting set up
- [ ] Backup/recovery plan documented

---

### Launch (Testnet)

**Week 1:**
- [ ] Deploy all contracts
- [ ] Initialize coordinators
- [ ] Fund test accounts
- [ ] Run smoke tests

**Week 2-4:**
- [ ] Community testing
- [ ] Bug fixes
- [ ] Performance optimization
- [ ] Documentation updates

**Week 5-8:**
- [ ] Gamification phase 1 (points accumulation)
- [ ] Monitor for issues
- [ ] Gather feedback
- [ ] Iterate on UX

**Week 9-12:**
- [ ] Gamification phase 2 (conversion window)
- [ ] Auto-conversion execution
- [ ] Transition to perpetual rewards
- [ ] Prepare for mainnet

---

### Pre-Launch (Mainnet)

**Security:**
- [ ] Third-party audit complete
- [ ] All audit findings resolved
- [ ] Bug bounty program (30 days, no critical issues)
- [ ] Formal verification (critical math)
- [ ] Insurance coverage (if available)

**Legal:**
- [ ] Legal review complete
- [ ] Terms of Service finalized
- [ ] Privacy Policy finalized
- [ ] Risk disclosures prepared
- [ ] Geographic restrictions implemented

**Governance:**
- [ ] DAO multisig set up (3-of-5 or 5-of-9)
- [ ] Timelock contracts deployed
- [ ] Emergency pause procedures documented
- [ ] Founder veto mechanism tested

**Operations:**
- [ ] Monitoring infrastructure production-ready
- [ ] Incident response plan documented
- [ ] Team trained on emergency procedures
- [ ] Communication channels established

---

## Risk Mitigation

### Technical Risks

| Risk | Mitigation | Owner |
|------|------------|-------|
| Smart contract exploit | Audit + bug bounty + insurance fund | Security team |
| Oracle manipulation | 10% deviation limit + TWAP + circuit breaker | Oracle team |
| Governance attack | Timelock + supermajority + veto power | Governance team |
| Liquidity crisis | Insurance fund + circuit breaker + pause | Risk team |

### Regulatory Risks

| Risk | Mitigation | Owner |
|------|------------|-------|
| Securities classification | No pre-sale + utility-first + active participation | Legal team |
| KYC/AML non-compliance | Tiered system + soulbound badges + attestors | Compliance team |
| Geographic restrictions | Region tracking + sanctioned list + blocking | Compliance team |
| Tax implications | User disclosure + documentation + legal guidance | Legal team |

### Operational Risks

| Risk | Mitigation | Owner |
|------|------------|-------|
| Key loss | Multi-sig + backup keys + recovery procedures | Ops team |
| Downtime | Redundant infrastructure + monitoring + alerts | DevOps team |
| Data loss | Backups + chain data + event logs | DevOps team |
| Team unavailability | Documentation + runbooks + cross-training | All teams |

---

## Success Metrics

### Launch Phase (Months 1-3)

**Targets:**
- TVL: $5M+
- Active users: 500+
- Governance participation: 20%+
- Zero critical exploits
- Uptime: 99.9%+

### Growth Phase (Months 4-12)

**Targets:**
- TVL: $50M+
- Active users: 5,000+
- Governance participation: 30%+
- Enterprise users: 50+
- Revenue: $100K+/month

### Maturity Phase (Year 2+)

**Targets:**
- TVL: $500M+
- Active users: 50,000+
- Full DAO control
- OPEX loan repaid
- Mainnet launch complete

---

## Summary

**Timeline:** 10 weeks to testnet, 12 months to mainnet

**Critical Path:**
1. Fix security issues (2 weeks)
2. Build gamification (2 weeks)
3. Add test coverage (2 weeks)
4. Complete governance (2 weeks)
5. Deploy + monitor (2 weeks)

**Estimated Effort:**
- Smart contract work: 4 weeks
- Testing: 3 weeks
- Infrastructure: 2 weeks
- Deployment: 1 week

**Team Size:** 3-5 developers recommended
