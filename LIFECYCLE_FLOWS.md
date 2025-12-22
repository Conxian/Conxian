# Conxian Protocol: End-to-End Lifecycle Flows

**Date:** December 22, 2025

---

## 1. SYSTEM LAUNCH FLOW

### Phase 0: Pre-Launch Deployment

**Step 1: Deploy Contracts (StacksOrbit)**

```bash
python stacksorbit_cli.py deploy --network testnet --dry-run
python stacksorbit_cli.py deploy --network testnet
```

**Deployment Order (150+ contracts in 4 batches):**

1. Traits + Standards (SIP-010, core-traits, defi-traits)
2. Base + Utils (ownable, pausable, math libraries)
3. Core System (tokens, coordinators, protocol)
4. DeFi Modules (DEX, lending, vaults, governance)

**Step 2: Initialize Core Coordinators**

```typescript
// 1. Token System Coordinator
await simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
// Registers: CXD, CXVG, CXLP, CXTR, CXS

// 2. Protocol Fee Switch
await simnet.callPublicFn('protocol-fee-switch', 'set-recipients', [
  treasury, staking, insuranceFund
], deployer);
await simnet.callPublicFn('protocol-fee-switch', 'set-fee-splits', [
  Cl.uint(2000), // 20% treasury
  Cl.uint(6000), // 60% staking
  Cl.uint(2000), // 20% insurance
  Cl.uint(0)     // 0% burn
], deployer);

// 3. Token Emission Controller
await simnet.callPublicFn('token-emission-controller', 'set-cxd-contract', 
  [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);
await simnet.callPublicFn('token-emission-controller', 'set-cxvg-contract', 
  [Cl.contractPrincipal(deployer, 'cxvg-token')], deployer);
await simnet.callPublicFn('token-emission-controller', 'enable-system-integration', [], deployer);
await simnet.callPublicFn('token-emission-controller', 'initialize-emission-limits', [], deployer);

// 4. Self-Launch Coordinator
await simnet.callPublicFn('self-launch-coordinator', 'initialize-self-launch', [
  Cl.uint(100000000),    // base-cost: 100 STX
  Cl.uint(25000000000),  // funding-target: 25K STX
  Cl.uint(1000000)       // curve-rate
], deployer);
await simnet.callPublicFn('self-launch-coordinator', 'initialize-community-phase-requirements', [], deployer);
await simnet.callPublicFn('self-launch-coordinator', 'activate-funding-curve', [], deployer);

// 5. Founder Vesting
await simnet.callPublicFn('founder-vesting', 'initialize', [founderAddress], deployer);
```

---

### Phase 1-7: Community Launch (Progressive Deployment)

**Launch Phases:**

| Phase | Name | Min Funding | Contributors | Contracts Deployed |
|-------|------|-------------|--------------|-------------------|
| 1 | Bootstrap | 100 STX | 3 | Traits, utils, encoding |
| 2 | Micro Core | 500 STX | 5 | Price initializer, coordinator |
| 3 | Token System | 1K STX | 10 | CXD, emission controller |
| 4 | DEX Core | 2.5K STX | 15 | Oracle, factory, budget manager |
| 5 | Liquidity | 5K STX | 20 | Router, pools, aggregator |
| 6 | Governance | 10K STX | 25 | Governance token, proposals, timelock |
| 7 | Fully Operational | 25K STX | 30 | Monitoring, automation |

**Contribution Flow:**

```clarity
User calls: contribute-funding(amount)

1. Validate:
   - self-launch-enabled == true
   - funding-curve-active == true
   - amount >= MIN_CONTRIBUTION (1 STX)

2. Split Contribution:
   launch-portion = amount / 2
   opex-portion = amount / 2

3. Transfer STX:
   stx-transfer? amount tx-sender (as-contract tx-sender)

4. Update Allocations:
   launch-fund-allocation += launch-portion
   opex-fund-allocation += opex-portion

5. Initialize OPEX Loan (first contribution):
   IF opex-loan-start-block == 0:
     opex-loan-start-block = block-height
     opex-loan-duration = 5 years * BLOCKS_PER_YEAR
     opex-loan-principal = opex-fund-allocation

6. Mint Governance Tokens:
   curve-price = get-funding-curve-price(current-funding)
   tokens-to-mint = (amount * PRECISION) / curve-price
   cxvg-token.mint(tokens-to-mint, contributor)

7. Mint NFTs:
   IF launch-portion >= MIN_CONTRIBUTION:
     position-factory.create-launch-lp-nft(contributor, launch-portion)
   ELSE:
     position-factory.create-normal-lp-nft(contributor, opex-portion)

8. Check Phase Advancement:
   IF total-funding >= phase-min-funding AND contributors >= phase-min-support:
     launch-phase += 1
     execute-phase-deployments(new-phase)

9. Check OPEX Repayment:
   IF should-trigger-repayment():
     execute-automatic-repayment()
```

**⚠️ MISSING:** Founder cannot withdraw `launch-fund-allocation` (no claim function)

---

### Phase 8: Genesis Distribution

**Trigger:** After Phase 7 complete + DAO vote

```clarity
token-system-coordinator.distribute-genesis-supply(founder-vesting, treasury)

1. Calculate Allocations:
   founder-amt-cxd = 100M * 15% = 15M CXD
   treasury-amt-cxd = 100M * 30% = 30M CXD
   community-amt-cxd = 100M * 55% = 55M CXD
   (Same for CXVG: 10M total)

2. Mint to Founder Vesting:
   cxd-token.mint(founder-vesting, 15M)
   founder-vesting.add-vesting-allocation(cxd-token, 15M)
   cxvg-token.mint(founder-vesting, 1.5M)
   founder-vesting.add-vesting-allocation(cxvg-token, 1.5M)

3. Mint to Treasury:
   cxd-token.mint(treasury, 30M)
   cxvg-token.mint(treasury, 3M)

4. Mint to Community Pool:
   cxd-token.mint(coordinator, 55M)
   (Held for liquidity mining distribution)

5. Mark Complete:
   distribution-complete = true
```

---

## 2. USER OPERATIONS FLOWS

### 2.1 Lending Operations

#### Liquidation & Insurance Safety Net Matrix

| Asset | Max LTV | Target Health Factor | Liquidation Buffer | Insurance Top-Up Trigger | Notes |
| --- | --- | --- | --- | --- | --- |
| CXD | 70% | 2.0 | +8% collateral when HF < 2.2 | Route +10% fees to insurance if CXD reserve \< 6 months payouts | Default retail market |
| STX | 65% | 1.9 | +10% collateral when HF < 2.1 | Same as CXD, but monitored hourly due to volatility | Backed by native STX |
| sBTC | 60% | 2.2 | +5% collateral when HF < 2.3 | Activate emergency routing if BTC drawdown > 15% in 24h | Bitcoin-backed positions |
| Stablecoins (USDT, USDA) | 75% | 1.8 | +12% collateral when HF < 2.0 | Pause new borrows if stablecoin depeg > 1% | Lower volatility bucket |

- **Liquidation buffer** reflects automatic collateral add from `liquidation-manager` before full liquidation.
- **Insurance top-up trigger** feeds into `protocol-fee-switch` (see §2.4) to divert additional revenue to the insurance vault when buffers are depleted.

**Supply Collateral:**

```clarity
comprehensive-lending-system.supply(asset, amount)

1. Validations:
   - amount > 0
   - protocol not paused
   - circuit breaker closed

2. Transfer:
   asset.transfer(amount, user, lending-contract, none)

3. Accrue Interest:
   interest-rate-model.accrue-interest(asset)
   → Returns updated supply-index

4. Calculate Principal:
   principal = amount / supply-index

5. Update State:
   user-supplies[user][asset].amount += principal
   user-supplies[user][asset].index = supply-index
   user-total-supplies[user] += amount

6. Update Market:
   interest-rate-model.update-market-state(asset, +amount, 0)
```

**Borrow Against Collateral:**

```clarity
comprehensive-lending-system.borrow-checked(asset, amount)

1. Pre-Check Health Factor:
   new-borrow = current-borrow + amount
   new-hf = (current-supply * 10000) / new-borrow
   IF new-hf < min-health-factor: REJECT

2. Accrue Interest:
   interest-rate-model.accrue-interest(asset)
   → Returns updated borrow-index

3. Calculate Principal:
   delta-principal = amount / borrow-index

4. Transfer:
   asset.transfer(amount, lending-contract, user, none)

5. Update State:
   user-borrows[user][asset].amount += delta-principal
   user-borrows[user][asset].index = borrow-index
   user-total-borrows[user] += amount

6. Update Market:
   interest-rate-model.update-market-state(asset, -amount, +amount)
```

**Repay Loan:**

```clarity
comprehensive-lending-system.repay(asset, amount)

1. Accrue Interest:
   interest-rate-model.accrue-interest(asset)

2. Calculate Repayment:
   repay-principal = amount / borrow-index
   actual-repay = min(repay-principal, current-principal)
   actual-amount = actual-repay * borrow-index

3. Transfer:
   asset.transfer(actual-amount, user, lending-contract, none)

4. Update State:
   user-borrows[user][asset].amount -= actual-repay
   user-total-borrows[user] -= actual-amount

5. Update Market:
   interest-rate-model.update-market-state(asset, +actual-amount, -actual-amount)
```

### 2.2 DEX Operations

**Instant Swap:**

```clarity
multi-hop-router-v3.swap-direct(amount-in, min-out, pool, token-in, token-out)

1. Execute Swap:
   pool.swap(amount-in, token-in, token-out)
   → Returns amount-out

2. Slippage Check:
   ASSERT amount-out >= min-out

3. Collect Fee:
   fee = amount-out * 0.003 (0.3%)
   net-amount = amount-out - fee

4. Route Fee:
   protocol-fee-switch.route-fees(token-out, fee, false, "DEX")
   → Splits: 20% treasury, 60% staking, 20% insurance

5. Transfer:
   token-out.transfer(net-amount, pool, user, none)
```

**MEV-Protected Swap:**

```clarity
Phase 1: Commit (Block N)
  mev-protector.commit-order(hash)
  → Stores: {hash, sender, start-block, revealed: false}

Phase 2: Reveal (Block N+10 to N+20)
  mev-protector.reveal-order(commitment-id, token-in, token-out, amount, min-out, salt)
  → Verifies: sha256(salt) == stored-hash
  → Adds to batch: batch-orders[batch-id][order-index]

Phase 3: Execute (Block N+20+)
  mev-protector.execute-order-in-batch(batch-id, order-index, pool, ...)
  → Executes: pool.swap(amount-in, token-in, token-out)
  → Validates: amount-out >= min-out
  → Marks: order as executed
```

### 2.3 Vault Operations

**Deposit:**

```clarity
vault.deposit(asset, amount)

1. Calculate Shares:
   IF total-shares == 0:
     shares = amount - 1000  // Burn 1000 dead shares
     total-shares = shares + 1000
   ELSE:
     shares = (amount * total-shares) / total-balance

2. Collect Fee:
   fee = amount * deposit-fee-bps / 10000  // 0.5% default
   net-amount = amount - fee

3. Transfer:
   asset.transfer(amount, user, vault, none)

4. Update State:
   vault-balances[asset] += net-amount
   vault-shares[asset] += shares
   user-shares[user][asset] += shares

5. Route Fee:
   collected-fees[asset] += fee
   token-system-coordinator.trigger-revenue-distribution(asset, fee)
```

**Withdraw:**

```clarity
vault.withdraw(asset, shares)

1. Calculate Amount:
   amount = (shares * total-balance) / total-shares

2. Collect Fee:
   fee = amount * withdrawal-fee-bps / 10000  // 1% default
   net-amount = amount - fee

3. Update State:
   vault-balances[asset] -= amount
   vault-shares[asset] -= shares
   user-shares[user][asset] -= shares

4. Transfer:
   asset.transfer(net-amount, vault, user, none)

5. Route Fee:
   collected-fees[asset] += fee
   token-system-coordinator.trigger-revenue-distribution(asset, fee)
```

---

## 2.4 Insurance Trigger Logic (Protocol Fee Switch)

1. **Baseline Split:** Treasury 20% / Staking 60% / Insurance 20% per `protocol-fee-switch.set-fee-splits`.
2. **Top-Up Trigger:** When `conxian-insurance-fund` balance \< `6 * avg-monthly-claims`, automation keepers call `protocol-fee-switch.activate-insurance-topup` (to be implemented) or governance updates the split to temporarily allocate +10% toward insurance.
3. **Emergency Trigger:** If simultaneous conditions occur—vault \< 3 months runway _and_ `liquidation-manager` reports > 5% system shortfall—the keeper executes `execute-auto-conversions` to route 100% of module fees to insurance until reserves recover.
4. **Validation:** Integration test `tests/integration/full-system-fee-insurance.test.ts` covers baseline routing; new stress harness will include mocked deficits once `protocol-fee-switch` exposes trigger functions.

> **Testing Note:** The fee routing scenario above is already enforced by `Full System - Fees Routed to Insurance`. As new trigger entrypoints land, extend that suite with deficit simulations.

---

## 3. GOVERNANCE FLOW

### 3.1 Voting Power Acquisition

```clarity
voting.lock-tokens(amount)

1. Transfer:
   governance-token.transfer(amount, user, voting-contract, none)

2. Set Lock:
   locks[user] = {
     amount: current-amount + amount,
     unlock-burn-height: burn-block-height + 100
   }

3. Voting Power:
   get-voting-power(user) = locked-amount (if not expired)
```

### 3.2 Proposal Lifecycle

**Create:**

```clarity
proposal-engine.propose(description, targets, values, signatures, calldatas, start, end)

1. Delegate to Registry:
   proposal-registry.create-proposal(tx-sender, description, start, end)
   → Returns proposal-id

2. Emit Event:
   {event: "proposal-created", proposal-id, proposer, start-block, end-block}
```

**Vote:**

```clarity
proposal-engine.vote(proposal-id, support)

1. Validate:
   - Proposal exists
   - Not executed/canceled
   - burn-block-height >= start-block
   - burn-block-height <= end-block

2. Get Voting Power:
   voting-power = voting.get-voting-power(tx-sender)

3. Cast Vote:
   voting.vote(proposal-id, support, tx-sender)
   → Records: {support, votes: voting-power}
   → Updates: proposal for-votes or against-votes

4. Emit Event:
   {event: "vote-cast", proposal-id, voter, support}
```

**Execute:**

```clarity
proposal-engine.execute(proposal-id)

1. Validate:
   - burn-block-height >= end-block
   - Not already executed/canceled
   - tx-sender == proposer

2. Check Quorum:
   total-votes = for-votes + against-votes
   quorum = (total-votes * 10000) / governance-token-supply
   ASSERT quorum >= quorum-percentage (default 5000 = 50%)

3. Check Majority:
   ASSERT for-votes > against-votes

4. Mark Executed:
   proposal-registry.set-executed(proposal-id)

⚠️ MISSING: Actual execution (contract-call? to targets)
```

---

## 4. OPEX LOAN MECHANICS

### 4.1 Loan Initialization

**Trigger:** First contribution to `self-launch-coordinator`

```clarity
IF opex-loan-start-block == 0:
  opex-loan-start-block = block-height
  opex-loan-duration = OPEX_LOAN_MIN_YEARS * OPEX_LOAN_BLOCKS_PER_YEAR
  opex-loan-principal = opex-fund-allocation
  
  ⚠️ CRITICAL: OPEX_LOAN_BLOCKS_PER_YEAR = u756864000 (120x too high)
  ✅ CORRECT: u6307200 (Nakamoto 5s blocks)
```

### 4.2 Repayment Triggers

**Automated Repayment Conditions:**

```clarity
should-trigger-repayment() returns true when ALL met:
  - TVL >= repayment-tvl-threshold (default: 10M STX)
  - Monthly revenue >= repayment-revenue-threshold (default: 1M STX)
  - System utilization <= 80%
  - Reserve ratio >= 20%
```

**Repayment Execution:**

```clarity
execute-automatic-repayment()

1. Calculate Available:
   available-revenue = get-available-revenue-safe()
   minimum-reserve = get-minimum-reserve-requirement-safe()
   repayable-amount = available-revenue - minimum-reserve

2. Calculate Outstanding:
   outstanding-loan = opex-loan-principal - opex-loan-repaid

3. Repay:
   IF repayable-amount >= outstanding-loan:
     // Full repayment
     opex-loan-repaid = opex-loan-principal
     EMIT {event: "opex-loan-fully-repaid", amount: outstanding-loan}
   ELSE:
     // Partial repayment
     opex-loan-repaid += repayable-amount
     EMIT {event: "opex-loan-partial-repayment", amount: repayable-amount}
```

**⚠️ NOTE:** Repayment metrics are currently MOCKED (get-total-tvl-safe, etc.)

---

## 5. FOUNDER TOKEN DISTRIBUTION

### 5.1 Vesting Schedule

**Parameters:**

- **Cliff:** 1 year (⚠️ currently 525,600 blocks = 3 days, should be 6,307,200)
- **Duration:** 4 years (⚠️ currently 2,102,400 blocks = 12 days, should be 25,228,800)
- **Tokens:** CXD (15M) + CXVG (1.5M)

**Vesting Calculation:**

```clarity
get-claimable-amount(token)

IF block-height < (start + CLIFF_DURATION):
  return 0  // Still in cliff

IF block-height >= (start + VESTING_DURATION):
  return total-allocated - amount-claimed  // Fully vested

ELSE:
  time-passed = block-height - start
  vested = (total-allocated * time-passed) / VESTING_DURATION
  return vested - amount-claimed
```

### 5.2 Claim Process

```clarity
founder-vesting.claim(token)

1. Validate:
   - tx-sender == founder-address
   - claimable > 0

2. Calculate:
   claimable = get-claimable-amount(token)

3. Update:
   vesting-schedule[token].amount-claimed += claimable

4. Transfer:
   token.transfer(claimable, vesting-contract, founder, none)

5. Emit:
   {event: "vesting-claimed", token, amount: claimable, recipient: founder}
```

### 5.3 Launch Fund Distribution

**⚠️ MISSING FUNCTION:** `claim-launch-funds()` not implemented

**Intended Flow:**

```clarity
self-launch-coordinator.claim-launch-funds()

1. Validate:
   - tx-sender == contract-owner (founder)
   - launch-fund-allocation > 0

2. Transfer:
   stx-transfer? launch-fund-allocation (as-contract tx-sender) contract-owner

3. Reset:
   launch-fund-allocation = 0

4. Emit:
   {event: "launch-funds-claimed", amount, recipient: contract-owner}
```

**Recommended Implementation:** Add to `self-launch-coordinator.clar` after line 897

---

## 6. REVENUE DISTRIBUTION FLOW

### 6.1 Fee Collection

**Source Modules:**

- DEX (swap fees)
- Lending (interest reserves)
- Vaults (deposit/withdrawal fees)
- Enterprise (order execution fees)

**Collection Pattern:**

```clarity
Module collects fee internally
  ↓
Transfers fee to protocol-fee-switch
  ↓
Calls: protocol-fee-switch.route-fees(token, fee-amount, false, "MODULE_NAME")
```

### 6.2 Fee Routing

```clarity
protocol-fee-switch.route-fees(token, amount, is-total, module)

1. Calculate Splits:
   treasury-amt = amount * treasury-share-bps / 10000  // 20%
   staking-amt = amount * staking-share-bps / 10000    // 60%
   insurance-amt = amount * insurance-share-bps / 10000 // 20%
   burn-amt = amount - (treasury + staking + insurance) // Dust

2. Transfer to Recipients:
   token.transfer(treasury-amt, fee-switch, treasury-address, none)
   token.transfer(staking-amt, fee-switch, staking-address, none)
   token.transfer(insurance-amt, fee-switch, insurance-address, none)
   token.transfer(burn-amt, fee-switch, treasury-address, none)  // Dust to treasury

3. Emit Event:
   {event: "fee-routed", module, token, total-fee, treasury, staking, insurance, burn}
```

### 6.3 Revenue Distribution Tracking

```clarity
token-system-coordinator.trigger-revenue-distribution(token, amount)

1. Validate:
   - System not paused
   - Token is registered

2. Delegate:
   revenue-distributor.distribute-revenue(token, amount)

3. Record Metrics:
   total-revenue-distributed += amount
   last-distribution = block-height
   next-distribution-id += 1

4. Emit Event:
   {event: "revenue-distribution", token, amount, id}
```

---

## 7. BEHAVIOR TRACKING FLOW

### 7.1 Action Recording

**Governance Actions:**

```clarity
conxian-operations-engine.record-governance-action(user, action-type, accuracy-delta)

Updates:
  - proposals-voted (if action-type == "vote")
  - proposals-created (if action-type == "create")
  - voting-accuracy (adjusted by accuracy-delta)
  - last-vote-block = block-height

Then: update-overall-behavior-metrics(user)
```

**Lending Actions:**

```clarity
conxian-operations-engine.record-lending-action(user, health-factor, was-liquidated, timely-repayment)

Updates:
  - average-health-factor (exponential moving average)
  - liquidation-count (if was-liquidated)
  - timely-repayment-count (if timely-repayment)
  - collateral-management-score (increases if healthy, decreases if liquidated)

Then: update-overall-behavior-metrics(user)
```

### 7.2 Score Calculation

```clarity
calculate-behavior-score(user)

Weighted Components:
  - Governance: 20% (voting-accuracy)
  - Lending: 25% (collateral-management-score)
  - MEV: 15% (mev-awareness-score)
  - Insurance: 15% (risk-management-score)
  - Bridge: 15% (bridge-reliability)
  - Participation: 10% (proposals-voted + proposals-created)

Total Score: 0-10000
```

### 7.3 Tier Assignment

```clarity
get-behavior-tier(score)

IF score >= 9000: Platinum (2.0x multiplier)
IF score >= 6000: Gold (1.5x multiplier)
IF score >= 3000: Silver (1.25x multiplier)
ELSE: Bronze (1.0x multiplier)
```

### 7.4 Reward Application

**Current Implementation:**

- Fee discounts (via `tier-manager.get-discount()`)
- Governance weight (via `conxian-operations-engine.execute-vote()`)
- Revenue share boosts (via `incentive-multiplier`)

**Proposed Gamification Extension:**

- Points accumulation (off-chain tracking → on-chain attestation)
- Token conversion (points → CXLP/CXVG)
- Auto-conversion for unclaimed rewards

---

## 8. EMERGENCY PROCEDURES

### 8.1 Circuit Breaker Activation

```clarity
Trigger: Admin detects attack/exploit

1. Open Circuit:
   circuit-breaker.open-circuit()
   → circuit-open = true

2. Cascade Effect:
   - comprehensive-lending-system.check-circuit-breaker() → FAILS
   - All lending operations blocked
   - DEX operations continue (different circuit)

3. Investigation:
   - Review logs
   - Identify root cause
   - Deploy fix if needed

4. Close Circuit:
   circuit-breaker.close-circuit()
   → circuit-open = false
```

### 8.2 Protocol-Wide Pause

```clarity
Trigger: Critical vulnerability discovered

1. Emergency Pause:
   conxian-protocol.emergency-pause(true)
   → emergency-paused = true

2. Cascade Effect:
   ALL facades check: conxian-protocol.is-protocol-paused()
   - proposal-engine: BLOCKED
   - enterprise-facade: BLOCKED
   - comprehensive-lending-system: BLOCKED
   - dimensional-engine: BLOCKED

3. Resume:
   conxian-protocol.emergency-pause(false)
   → emergency-paused = false
```

### 8.3 Insurance Fund Slashing

```clarity
Trigger: Protocol deficit (bad debt, exploit)

1. Governance Proposal:
   - Create proposal to slash insurance fund
   - Vote (66.67% supermajority required)
   - Execute after timelock

2. Slash Execution:
   conxian-insurance-fund.slash-funds(amount, token, recovery-multisig)
   → Transfers staked tokens to recovery address
   → Reduces total-staked
   → ⚠️ Does NOT update user-stakes (socialized loss)

3. Recovery:
   - Use slashed funds to cover deficit
   - Restore protocol solvency
```

---

## 9. UPGRADE & MIGRATION FLOW

**Current State:** Migration manager exists but not fully wired

**Proposed Flow:**

```clarity
1. Deploy New Contract Version:
   - Deploy contract-v2 to new address
   - Keep contract-v1 active

2. Governance Proposal:
   - Propose migration (targets: [migration-manager], signatures: ["migrate"], calldatas: [v2-address])
   - Vote + execute

3. Migration Execution:
   migration-manager.migrate(old-contract, new-contract)
   → Transfers state (if possible)
   → Updates references in coordinators
   → Pauses old contract

4. Verification:
   - Test new contract
   - Monitor for issues
   - Rollback if needed (unpause old, update references)
```

---

## Summary

**Critical Missing Pieces:**

1. ❌ `claim-launch-funds()` function
2. ❌ Governance proposal execution logic
3. ❌ OPEX repayment metrics (currently mocked)
4. ❌ Migration manager integration

**Working Flows:**
✅ Contribution → CXVG minting → NFT rewards  
✅ Lending supply/borrow/repay with interest  
✅ DEX swaps with fee routing  
✅ Vault deposit/withdraw with share calculation  
✅ Governance voting (but not execution)  
✅ Behavior tracking (but not reward distribution)
