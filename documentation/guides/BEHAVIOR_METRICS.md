# Conxian Behavior Metrics & Reputation System

## Overview

The Conxian Protocol implements a comprehensive behavior metrics and reputation system to incentivize excellent behavior across all protocol interactions. This system tracks user actions in governance, lending, MEV protection, insurance, and cross-chain bridging, calculating weighted scores that determine reputation tiers and reward multipliers.

## Core Principles

1. **Transparency**: All metrics are on-chain and publicly verifiable
2. **Fairness**: Weighted scoring across multiple dimensions prevents gaming
3. **Progressive Rewards**: Higher tiers unlock better incentive multipliers
4. **Continuous Improvement**: Scores update dynamically based on recent behavior
5. **Multi-Dimensional**: No single activity dominates the overall score

## Behavior Dimensions

### 1. Governance Behavior (20% Weight)

Tracks participation and quality of governance engagement:

- **Proposals Voted**: Number of proposals user has voted on
- **Proposals Created**: Number of proposals user has created
- **Voting Accuracy**: Alignment with successful outcomes (0-10000 scale)
- **Delegation Trust Score**: Reliability as a vote delegatee
- **Council Participation**: Engagement in council activities
- **Emergency Response Count**: Participation in emergency actions

**Scoring Formula**:
```
governance_score = (voting_accuracy * 2000) / 10000
```

**Positive Actions**:
- Voting on proposals: +1 to proposals_voted
- Creating proposals: +1 to proposals_created
- Accurate voting: +100 to voting_accuracy per aligned vote

**Negative Actions**:
- Inaccurate voting: -50 to voting_accuracy per misaligned vote

### 2. Lending Behavior (25% Weight)

Tracks responsible borrowing and collateral management:

- **Average Health Factor**: Historical average health factor
- **Liquidation Count**: Number of liquidations (lower is better)
- **Timely Repayment Count**: On-time repayments
- **Collateral Management Score**: Quality of collateral management (0-10000)
- **Lending Volume**: Total lending activity volume

**Scoring Formula**:
```
lending_score = (collateral_management_score * 2500) / 10000
```

**Positive Actions**:
- Maintaining high health factor: +50 to collateral_management_score
- Timely repayments: +1 to timely_repayment_count
- No liquidations: Preserves collateral_management_score

**Negative Actions**:
- Liquidation: +1 to liquidation_count, -5% to collateral_management_score
- Low health factor: Reduces average_health_factor

### 3. MEV Protection Behavior (15% Weight)

Tracks awareness and usage of MEV protection:

- **Protection Usage Count**: Times MEV protection was used
- **Attacks Prevented**: Attacks successfully prevented
- **Protected Volume**: Total volume protected
- **MEV Awareness Score**: Understanding of MEV risks (0-10000)

**Scoring Formula**:
```
mev_score = (mev_awareness_score * 1500) / 10000
```

**Positive Actions**:
- Using MEV protection: +1 to protection_usage_count, +100 to mev_awareness_score
- Preventing attacks: +1 to attacks_prevented
- Protecting volume: Adds to protected_volume

### 4. Insurance Behavior (15% Weight)

Tracks insurance coverage quality and claims management:

- **Coverage Utilization**: How well coverage is utilized
- **Claims Filed**: Number of claims
- **Claims Approved**: Approved claims (quality indicator)
- **Premium Payment Reliability**: Payment reliability score (0-10000)
- **Risk Management Score**: Overall risk management quality (0-10000)

**Scoring Formula**:
```
insurance_score = (risk_management_score * 1500) / 10000
```

**Positive Actions**:
- Paying premiums on time: +100 to premium_payment_reliability
- Approved claims: +1 to claims_approved, +50 to risk_management_score

**Negative Actions**:
- Missed premium payments: -5% to premium_payment_reliability
- Rejected claims: +1 to claims_filed, -10% to risk_management_score

### 5. Bridge Behavior (15% Weight)

Tracks cross-chain bridge reliability and security awareness:

- **Successful Bridges**: Successful cross-chain transfers
- **Failed Bridges**: Failed transfers
- **Bridge Volume**: Total bridged volume
- **Bridge Reliability**: Reliability score (0-10000)
- **Security Awareness Score**: Bridge security awareness (0-10000)

**Scoring Formula**:
```
bridge_score = (bridge_reliability * 1500) / 10000
bridge_reliability = (successful_bridges * 10000) / (successful_bridges + failed_bridges)
```

**Positive Actions**:
- Successful bridge: +1 to successful_bridges, +50 to security_awareness_score
- High success rate: Improves bridge_reliability

**Negative Actions**:
- Failed bridge: +1 to failed_bridges, -5% to security_awareness_score

### 6. Participation Bonus (10% Weight)

Rewards active protocol participation:

**Scoring Formula**:
```
participation_bonus = governance_participation * 10
```

## Reputation Tiers

The system assigns users to one of four tiers based on their overall behavior score:

| Tier | Threshold | Multiplier | Description |
|------|-----------|------------|-------------|
| **Bronze** | 0 - 999 | 1.0x (100) | New or low-activity users |
| **Silver** | 1,000 - 2,999 | 1.25x (125) | Regular participants with good behavior |
| **Gold** | 3,000 - 5,999 | 1.5x (150) | Highly engaged users with excellent behavior |
| **Platinum** | 6,000 - 9,000+ | 2.0x (200) | Elite users with exceptional behavior |

### Tier Benefits

- **Bronze**: Standard protocol access
- **Silver**: 25% bonus on governance rewards, priority support
- **Gold**: 50% bonus on all rewards, early access to new features
- **Platinum**: 100% bonus on all rewards, governance weight boost, exclusive features

## Overall Behavior Score Calculation

The comprehensive behavior score is calculated as a weighted sum:

```clarity
overall_score = 
  (governance_score * 0.20) +
  (lending_score * 0.25) +
  (mev_score * 0.15) +
  (insurance_score * 0.15) +
  (bridge_score * 0.15) +
  (participation_bonus * 0.10)
```

Maximum possible score: **10,000**

## API Reference

### Read-Only Functions

#### `get-user-behavior-metrics`
Returns overall behavior metrics for a user.

```clarity
(get-user-behavior-metrics (user principal))
```

**Returns**:
```clarity
{
  reputation-score: uint,
  governance-participation: uint,
  lending-health-score: uint,
  mev-protection-score: uint,
  insurance-coverage-score: uint,
  bridge-reliability-score: uint,
  total-protocol-value: uint,
  last-updated: uint,
  behavior-tier: uint,
  incentive-multiplier: uint,
}
```

#### `get-governance-behavior`
Returns governance-specific behavior metrics.

```clarity
(get-governance-behavior (user principal))
```

#### `get-lending-behavior`
Returns lending-specific behavior metrics.

```clarity
(get-lending-behavior (user principal))
```

#### `get-mev-behavior`
Returns MEV protection behavior metrics.

```clarity
(get-mev-behavior (user principal))
```

#### `get-insurance-behavior`
Returns insurance behavior metrics.

```clarity
(get-insurance-behavior (user principal))
```

#### `get-bridge-behavior`
Returns bridge behavior metrics.

```clarity
(get-bridge-behavior (user principal))
```

#### `calculate-behavior-score`
Calculates the comprehensive weighted behavior score.

```clarity
(calculate-behavior-score (user principal))
```

#### `get-behavior-tier`
Determines tier based on score.

```clarity
(get-behavior-tier (score uint))
```

#### `get-incentive-multiplier`
Returns multiplier for a given tier.

```clarity
(get-incentive-multiplier (tier uint))
```

#### `get-user-behavior-dashboard`
Returns complete behavior dashboard with all metrics.

```clarity
(get-user-behavior-dashboard (user principal))
```

### Update Functions (Owner-Only)

#### `record-governance-action`
Records a governance action (vote, proposal creation).

```clarity
(record-governance-action 
  (user principal)
  (action-type (string-ascii 32))
  (voting-accuracy-delta int))
```

#### `record-lending-action`
Records a lending action (borrow, repay, liquidation).

```clarity
(record-lending-action
  (user principal)
  (health-factor uint)
  (was-liquidated bool)
  (timely-repayment bool))
```

#### `record-mev-action`
Records MEV protection usage.

```clarity
(record-mev-action
  (user principal)
  (protection-used bool)
  (attack-prevented bool)
  (volume uint))
```

#### `record-insurance-action`
Records insurance activity (claims, premium payments).

```clarity
(record-insurance-action
  (user principal)
  (claim-filed bool)
  (claim-approved bool)
  (premium-paid bool))
```

#### `record-bridge-action`
Records cross-chain bridge activity.

```clarity
(record-bridge-action
  (user principal)
  (bridge-successful bool)
  (volume uint))
```

## Integration Guide

### For Protocol Contracts

Contracts should call the appropriate `record-*-action` functions after user actions:

```clarity
;; Example: After a successful vote
(contract-call? .conxian-operations-engine record-governance-action
  tx-sender
  "vote"
  100  ;; Positive accuracy delta
)

;; Example: After a borrow
(contract-call? .conxian-operations-engine record-lending-action
  tx-sender
  (get-health-factor tx-sender)
  false  ;; Not liquidated
  true   ;; Timely action
)
```

### For Frontend Applications

Query behavior metrics to display user reputation:

```typescript
// Get comprehensive dashboard
const dashboard = await callReadOnly(
  'conxian-operations-engine',
  'get-user-behavior-dashboard',
  [principalCV(userAddress)]
);

// Display tier badge
const tier = dashboard.behavior_tier;
const multiplier = dashboard.incentive_multiplier;

// Show tier-specific UI elements
if (tier >= 3) {
  // Show gold/platinum exclusive features
}
```

## Best Practices

### For Users

1. **Participate Actively**: Vote on proposals to build governance reputation
2. **Manage Risk**: Maintain healthy collateral ratios to avoid liquidations
3. **Use Protection**: Enable MEV protection to demonstrate security awareness
4. **Pay Premiums**: Keep insurance premiums current for reliability score
5. **Bridge Carefully**: Test with small amounts before large transfers

### For Developers

1. **Record All Actions**: Ensure all user actions are recorded for accurate metrics
2. **Handle Errors**: Gracefully handle metric recording failures
3. **Display Clearly**: Show users their tier and how to improve
4. **Incentivize**: Use multipliers in reward calculations
5. **Monitor**: Track aggregate behavior metrics for protocol health

## Security Considerations

1. **Owner-Only Updates**: Only contract owner can record behavior actions
2. **No Direct Manipulation**: Users cannot directly modify their scores
3. **Transparent Calculations**: All scoring logic is on-chain and auditable
4. **Gradual Changes**: Scores update incrementally to prevent gaming
5. **Multi-Dimensional**: Prevents focus on single dimension for score manipulation

## Future Enhancements

- **Time Decay**: Older actions have less weight over time
- **Seasonal Campaigns**: Temporary bonuses for specific behaviors
- **Peer Reputation**: User-to-user reputation ratings
- **Achievement NFTs**: Special NFTs for milestone achievements
- **Reputation Delegation**: Allow reputation to be temporarily delegated
- **Cross-Protocol Reputation**: Import reputation from other DeFi protocols

## Related Documentation

- `OPERATIONS_RUNBOOK.md` - Operational procedures
- `REGULATORY_ALIGNMENT.md` - Compliance mapping
- `ROADMAP.md` - Future development plans
- `contracts/governance/conxian-operations-engine.clar` - Implementation
- `tests/governance/behavior-metrics.test.ts` - Test suite
