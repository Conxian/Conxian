# Conxian Gamification & Regulatory Strategy

**Date:** December 22, 2025

---

## 1. EXISTING INFRASTRUCTURE

### Behavior Reputation System (`conxian-operations-engine.clar`)

**Tracked Metrics:**
- **Governance:** proposals-voted, proposals-created, voting-accuracy, delegation-trust
- **Lending:** avg-health-factor, liquidation-count, timely-repayments, collateral-mgmt-score
- **MEV:** protection-usage, attacks-prevented, protected-volume, awareness-score
- **Insurance:** coverage-utilization, claims-filed/approved, premium-reliability
- **Bridge:** successful-bridges, failed-bridges, reliability-score

**Score Calculation:**
```
Total Score (0-10000) = 
  Governance (20%) + Lending (25%) + MEV (15%) + Insurance (15%) + Bridge (15%) + Participation (10%)
```

**Tiers:**
- Bronze (1000-2999): 1.0x multiplier
- Silver (3000-5999): 1.25x multiplier
- Gold (6000-8999): 1.5x multiplier
- Platinum (9000+): 2.0x multiplier

---

## 2. PROPOSED GAMIFICATION MODEL

### Phase 1: Points Accumulation (Months 1-3)

**Activity Points:**

**Liquidity (40% weight):**
- Provide liquidity: 10 pts/day per $1000 TVL
- Hold > 30 days: 2x multiplier
- Multiple pools: 1.5x multiplier
- Priority pairs (CXD/STX): 3x multiplier

**Governance (25% weight):**
- Vote on proposal: 50 pts
- Create proposal (passed): 200 pts
- Lock tokens: 5 pts/day per 1000 tokens

**Usage (20% weight):**
- Swap: 5 pts per $100 volume
- MEV-protected swap: +25 pts bonus
- Borrow/lend: 10 pts per $1000

**Security (10% weight):**
- Insurance staking: 15 pts/day per $1000
- Healthy loan (HF > 1.5): 5 pts/day
- Bug report (verified): 1000 pts

**Community (5% weight):**
- Refer user (contributes): 100 pts
- Forum participation: 25 pts/post

### Phase 2: Conversion Window (Month 3-4)

**Allocation Pool:**
- 550K CXLP (from 55M community allocation)
- 550K CXVG (from 5.5M community allocation)
- CXD reserved (post-decentralization only)

**Conversion:**
```
cxlp-amount = user-liquidity-points / total-liquidity-points * 550K
cxvg-amount = user-governance-points / total-governance-points * 550K
```

**Claim Window:** 30 days  
**Auto-Conversion:** Keeper converts unclaimed after window

### Phase 3: Perpetual Rewards (Month 4+)

**Emission-Based:**
- CXLP: 1% annual emission to LPs
- CXVG: 0.5% annual emission to voters
- Multipliers: Bronze 1.0x → Platinum 2.0x

---

## 3. REGULATORY COMPLIANCE

### Securities Law Mitigation

**Howey Test Avoidance:**
- ✅ Tokens earned through WORK (not passive)
- ✅ No pre-sale or ICO
- ✅ Utility-first (governance, not revenue)
- ✅ Active participation required

**Safe Practices:**
- Distribute CXVG/CXLP (governance/LP shares) ✅
- Delay CXD (revenue token) until DAO-controlled ❌
- No APY promises ✅
- No "investment" marketing ✅

### DeFi Precedents

| Protocol | Model | Token Utility | Conxian Alignment |
|----------|-------|---------------|-------------------|
| Uniswap | Liquidity mining | Governance-only | ✅ CXVG similar |
| Aave | Safety module | Gov + insurance | ✅ Insurance fund |
| Compound | Usage-based | Governance-only | ✅ Points system |
| Curve | Vote-escrowed | Gov + boosted rewards | ✅ Lock-based voting |

**Key Takeaway:** All avoided securities classification via:
1. No pre-sale
2. Earned through usage
3. Governance utility first
4. Progressive decentralization

### KYC/AML Tiers

**Tier 0:** Basic access (no KYC)  
**Tier 1:** Full access (basic KYC)  
**Tier 2:** Enterprise features (enhanced KYC)  
**Tier 3:** Institutional (KYB + regulatory compliance)

---

## 4. IMPLEMENTATION REQUIREMENTS

### New Contracts

**1. `gamification-manager.clar`**
- Claim rewards (Merkle proof verification)
- Auto-conversion for unclaimed
- Conversion rate calculation

**2. `points-oracle.clar`**
- Merkle root submission (multi-sig)
- Proof verification
- Epoch management

**3. Enhanced `automation-keeper.clar`**
- Auto-conversion task
- OPEX repayment trigger
- Behavior metric updates

### Off-Chain Services

**Points Calculator:**
- Monitor on-chain events
- Calculate points per user
- Generate Merkle tree
- Submit root (multi-sig)

**Attestor Network:**
- 5 independent nodes
- 3-of-5 threshold
- Geographic distribution

**Automation Keeper:**
- Monitor claim window
- Trigger auto-conversions
- Monitor OPEX conditions

### UI Components

**Gamification Dashboard:**
- Real-time points display
- Activity breakdown
- Tier progress bar
- Projected rewards
- Claim interface

---

## 5. ENTERPRISE UNLOCK

### DAO Vote Requirements

**Thresholds:**
- TVL ≥ $10M
- Active users ≥ 1000
- Governance participation ≥ 30%
- KYC infrastructure operational

**Execution:**
```clarity
proposal-engine.execute(proposal-id)
  → enterprise-facade.set-enterprise-active(true)
```

**Features Unlocked:**
- TWAP orders
- Iceberg orders
- Institutional accounts
- Advanced compliance

---

## 6. EMISSION CAP REMOVAL

### DAO Vote Process

**Requirements:**
- 66.67% supermajority
- 2-week timelock
- Demonstrated success (TVL, revenue, users)

**Proposed Increases:**
- CXD: 2% → 5%
- CXVG: 0.5% → 1%
- CXLP: 1% → 3%

**Gradual Approach:**
- Year 1: Current caps
- Year 2-4: Gradual increases
- Year 5+: Return to sustainable rates

---

## Summary

**Gamification:**
✅ Points system (work-based)  
✅ Conversion window (30 days)  
✅ Auto-conversion (keeper)  
✅ Behavior multipliers (1.0x-2.0x)  
✅ Perpetual rewards (emission-based)

**Regulatory:**
✅ No securities classification  
✅ KYC/AML compliance  
✅ Geographic restrictions  
✅ Progressive decentralization  
✅ Transparency + disclosures

**Missing:**
❌ gamification-manager contract  
❌ points-oracle contract  
❌ Off-chain calculator service  
❌ Attestor network setup
