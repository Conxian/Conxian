# Conxian Enhanced Tokenomics User Guide

Welcome to the Conxian Enhanced Multi-Token Tokenomics System.
This guide will help you understand and interact with the comprehensive token
ecosystem that powers the Conxian dimensional DeFi protocol.

## Table of Contents

- [Overview](#overview)
- [Token Ecosystem](#token-ecosystem)
- [Getting Started](#getting-started)
- [Staking Guide](#staking-guide)
- [Governance Participation](#governance-participation)
- [Revenue Sharing](#revenue-sharing)
- [Migration Guide](#migration-guide)
- [Security Features](#security-features)
- [Advanced Features](#advanced-features)
- [Troubleshooting](#troubleshooting)

## Overview

The Conxian Enhanced Tokenomics system is a sophisticated multi-token ecosystem
designed to align incentives, distribute value, and enable governance across
the dimensional vault protocol. The system includes four primary tokens with
distinct purposes and utility mechanisms.

### Key Features

- **Multi-token architecture** for specialized use cases
- **Revenue distribution** from protocol fees to token holders
- **Governance utilities** with fee discounts and voting power
- **Staking mechanisms** with anti-gaming protections
- **Migration pathways** for existing liquidity providers
- **Dimensional integration** with yield farming and bond systems
- **Circuit breakers** and invariant monitoring for security

## Token Ecosystem

### CXD - Revenue Token

**Purpose:** Primary revenue-generating token for the protocol

**Key Features:**

- Earns revenue from protocol fees when staked as xCXD
- Can be minted through various protocol activities
- Stakable for yield generation
- Used for fee payments across the protocol

**Supply Mechanics:**

- Maximum supply: 21,000,000 CXD
- Emission controlled by governance
- Revenue-backed with protocol fee distribution

### CXVG - Governance Token

**Purpose:** Governance participation and utility token

**Key Features:**

- Voting power in protocol governance
- Fee discounts when locked
- Proposal bonding for governance security
- Governance boosts for active participants

**Utility Mechanisms:**

- Lock CXVG to earn fee discounts (5%-30%)
- Bond CXVG to create governance proposals
- Boost voting power through longer lock periods
- Earn governance rewards for participation

### CXLP - Legacy Migration Token

**Purpose:** Migration path for existing liquidity providers

**Key Features:**

- Migrates to CXD with bonus multipliers
- Time-banded migration with decreasing bonuses
- User and epoch caps to prevent gaming
- Pro-rata settlement mechanism

**Migration Benefits:**

- Early migration bonuses up to 10%
- Guaranteed conversion to revenue-earning CXD
- Migration fees contribute to revenue pool
- Smooth transition for existing users

### CXTR - Contributor Token

**Purpose:** Rewards for protocol contributors and builders

**Key Features:**

- Merit-based distribution
- Soulbound characteristics for reputation
- Contributor recognition system
- Integration with governance utilities

**Distribution:**

- Developer contributions
- Community building activities
- Protocol improvement proposals
- Long-term ecosystem support

## Getting Started

### Prerequisites

1. **Stacks Wallet:** Install a compatible Stacks wallet (Hiro Wallet recommended)
2. **STX Tokens:** Ensure you have STX for transaction fees
3. **Understanding:** Familiarize yourself with the token purposes above

### Initial Setup

1. **Acquire Tokens:**

   ```
   - Participate in protocol activities to earn CXD
   - Provide liquidity to earn CXVG rewards
   - Contribute to the ecosystem for CXTR
   - Hold existing LP tokens for CXLP migration
   ```

2. **Connect Wallet:**

   - Connect your Stacks wallet to the Conxian interface
   - Verify your address has sufficient STX for transactions
   - Review token balances and available actions

3. **Explore Features:**

   - Start with small amounts to understand mechanics
   - Review available staking and governance options
   - Understand fee structures and discount opportunities

## Staking Guide

### CXD Staking (xCXD)

Staking CXD tokens creates xCXD positions that earn revenue from protocol fees.

#### How to Stake

1. **Initiate Staking:**

   ```
   Minimum: 1 CXD
   Maximum: 10,000,000 CXD per user
   Warmup Period: 2 weeks (mainnet) / 1 day (testnet)
   ```

2. **Warmup Period:**

   - Newly staked tokens enter a warmup period
   - No revenue earned during warmup
   - Prevents snapshot sniping attacks
   - Can withdraw during warmup without penalties

3. **Active Staking:**

   - Earn proportional share of protocol revenue
   - Revenue distributed weekly
   - Compounding available through restaking
   - Can add more CXD to existing position

4. **Unstaking Process:**

   ```text
   Cooldown Period: 4 weeks (mainnet) / 1 day (testnet)
   Immediate Exit: Available with penalty
   Scheduled Exit: Full amount after cooldown
   ```

#### Revenue Distribution

- **Sources:** Vault fees, DEX fees, migration fees, dimensional yield
- **Split:** 70% to stakers, 20% treasury, 10% reserves
- **Frequency:** Weekly distribution cycles
- **Claiming:** Manual claiming or auto-compound options

#### Staking Strategies

1. **Long-term Holders:**
   - Stake for consistent revenue stream
   - Benefit from compound growth
   - Participate in governance decisions

2. **Active Traders:**
   - Monitor revenue cycles for optimal entry/exit
   - Consider warmup/cooldown periods in timing
   - Use fee discounts for trading benefits

## Governance Participation

### CXVG Locking Mechanism

Lock CXVG tokens to participate in governance and earn utilities.

#### Locking Process

1. **Choose Lock Duration:**

   ```
   Minimum: 6 months (mainnet) / 1 week (testnet)
   Maximum: 2 years
   Longer locks = Higher voting power + Better fee discounts
   ```

2. **Lock Your CXVG:**
   - Select amount and duration
   - Confirm transaction
   - Tokens become locked and non-transferable
   - Begin earning voting power and fee discounts

#### Voting Power Calculation

```
Voting Power = Locked Amount × Time Multiplier
Time Multiplier = 1.0 + (Lock Duration / Max Duration)
```

#### Fee Discount Tiers

| Locked CXVG | Discount | Additional Benefits |
|-------------|----------|-------------------|
| 10K+        | 5%       | Basic governance access |
| 100K+       | 10%      | Priority proposal queue |
| 1M+         | 20%      | Enhanced voting weight |
| 5M+         | 30%      | Governance council eligibility |

### Creating Proposals

1. **Proposal Requirements:**
   - Bond 10,000 CXVG (refunded if successful)
   - Minimum 6-month lock period
   - Clear proposal specification
   - Community discussion period

2. **Proposal Process:**

   ```
   1. Bond CXVG tokens
   2. Submit proposal with rationale
   3. Community review (1 week)
   4. Voting period (1 week)
   5. Implementation (if passed)
   ```

3. **Proposal Types:**
   - Parameter changes (fees, limits, durations)
   - New feature additions
   - Integration partnerships
   - Treasury allocation decisions

### Voting Process

1. **Eligible Votes:** Lock CXVG for minimum duration
2. **Voting Period:** 1 week for most proposals
3. **Quorum:** Minimum 10% of locked CXVG must participate
4. **Threshold:** 60% approval required for passage

## Revenue Sharing

### Revenue Sources

The protocol generates revenue from multiple sources that are distributed to CXD stakers:

1. **Vault Management Fees (0.5%-1%):**
   - Charged on vault deposits/withdrawals
   - Performance fees on vault profits
   - Automated strategy execution fees

2. **DEX Trading Fees (0.3%):**
   - Swap fees from dimensional DEX
   - Liquidity provision rewards
   - Arbitrage and market making

3. **Migration Fees:**
   - CXLP to CXD conversion fees
   - Legacy system transition charges
   - Migration bonus adjustments

4. **Dimensional Yield:**
   - Dimensional staking rewards
   - Cross-dimensional arbitrage profits
   - Yield farming optimization returns

5. **Tokenized Bond Coupons:**
   - Bond interest payments
   - Bond maturation proceeds
   - Secondary market trading fees

### Distribution Mechanics

1. **Collection:** All fees flow to revenue distributor contract
2. **Accumulation:** Fees accumulate over weekly periods  
3. **Distribution:** Weekly distribution to active stakers
4. **Claiming:** Manual claim or automatic restaking options

### Revenue Calculation

```
Your Share = (Your Staked CXD / Total Staked CXD) × Weekly Revenue × 70%
```

### Maximizing Returns

1. **Stake Early:** Benefit from protocol growth
2. **Long-term Holding:** Avoid warmup/cooldown periods
3. **Compound Returns:** Restake earned revenue
4. **Fee Discounts:** Lock CXVG to reduce protocol fees

## Migration Guide

### CXLP to CXD Migration

Existing liquidity providers can migrate CXLP tokens to CXD with time-based bonuses.

#### Migration Mechanics

1. **Time Bands:**
   - Band 1 (Months 1-6): 110% conversion rate
   - Band 2 (Months 7-12): 108% conversion rate
   - Band 3 (Months 13-24): 105% conversion rate
   - Band 4 (Months 25+): 100% conversion rate

2. **Migration Limits:**

   ```
   Epoch Cap: 1M CXD per week
   User Base: 10K CXD per user per epoch
   User Max: 500K CXD per user total
   ```

3. **Migration Process:**

   ```
   1. Check current migration band
   2. Calculate expected CXD output
   3. Submit migration transaction
   4. Receive CXD tokens (can immediately stake)
   ```

#### Migration Strategy

1. **Early Migration Benefits:**
   - Higher conversion rates
   - Priority in epoch caps
   - Immediate staking eligibility

2. **Timing Considerations:**
   - Monitor epoch usage to avoid caps
   - Consider gas costs vs. bonus amounts
   - Plan for immediate CXD staking

## Security Features

### Circuit Breakers

The system includes multiple layers of protection:

1. **Protocol Invariant Monitor:**
   - Continuously monitors system health
   - Detects anomalous behavior
   - Triggers automatic pauses if needed

2. **Emergency Pause System:**
   - Admin-triggered system-wide pause
   - Individual contract pause capabilities
   - Multi-signature requirements for critical actions

3. **Emission Controls:**
   - Hard-coded maximum supplies
   - Governance-controlled emission rates
   - Automatic limits on minting operations

### Best Practices

1. **Verify Transactions:** Always double-check transaction details
2. **Use Official Interfaces:** Only interact through verified Conxian interfaces
3. **Monitor Announcements:** Stay updated on protocol changes
4. **Understand Risks:** DeFi protocols carry inherent smart contract risks

## Advanced Features

### Dimensional Integration

The tokenomics system integrates with dimensional vault mechanics:

1. **Dimensional Yield Distribution:**
   - Dimensional staking rewards flow to CXD stakers
   - Cross-dimensional arbitrage profits shared
   - Yield farming optimization returns

2. **Tokenized Bond Integration:**
   - Bond coupon payments distributed to stakers
   - Bond maturation proceeds shared
   - Secondary market fee sharing

### Automated Strategies

1. **Auto-Compounding:**
   - Automatically restake earned revenue
   - Optimize for compound growth
   - Minimize transaction costs

2. **Fee Optimization:**
   - Dynamic CXVG locking for fee discounts
   - Optimal migration timing
   - Gas cost optimization

3. **Yield Maximization:**
   - Cross-token arbitrage opportunities
   - Optimal staking duration planning
   - Revenue cycle optimization

## Troubleshooting

### Common Issues

1. **Transaction Failures:**
   - Check STX balance for gas fees
   - Verify contract approvals
   - Ensure sufficient token balances
   - Wait for network confirmation

2. **Staking Issues:**
   - Respect minimum/maximum limits
   - Account for warmup periods
   - Verify xCXD position status
   - Check for system pauses

3. **Revenue Claims:**
   - Ensure staking position is active
   - Check distribution schedule
   - Verify claim eligibility
   - Account for processing delays

### Getting Help

1. **Documentation:** Review this guide and API documentation
2. **Community:** Join Discord/Telegram for community support
3. **Support:** Contact support team for technical issues
4. **Updates:** Follow official channels for announcements

### Emergency Procedures

1. **System Pause:** If system is paused, wait for official updates
2. **Contract Issues:** Do not interact with flagged contracts
3. **Security Incidents:** Follow official guidance immediately
4. **Recovery:** Use only official recovery procedures

---

## Next Steps

1. **Start Small:** Begin with small amounts to understand mechanics
2. **Explore Features:** Try staking, governance, and fee discounts
3. **Join Community:** Participate in governance discussions
4. **Stay Updated:** Monitor protocol developments and improvements

For technical details and advanced integration, see the [API Reference Documentation](./API_REFERENCE.md).

For developers building on Conxian, see the [Developer Guide](./DEVELOPER_GUIDE.md).

**Disclaimer:** This documentation describes the intended behavior of smart contracts. Always verify current contract state and behavior before transacting. DeFi protocols carry inherent risks including smart contract bugs, economic attacks, and market volatility.
