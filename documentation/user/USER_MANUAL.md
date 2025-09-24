# Conxian User Manual

**Welcome to Conxian** - The most comprehensive DeFi ecosystem on Stacks blockchain, designed to offer Bitcoin-native DeFi with institutional-grade security and community governance.

*Last Updated: August 25, 2025*

---

## 📋 Table of Contents

1. [What is Conxian?](#what-is-conxian)
2. [Getting Started](#getting-started)
3. [Core Features Overview](#core-features-overview)
4. [Vault Operations](#vault-operations)
5. [Token Economics Guide](#token-economics-guide)
6. [DAO Governance Participation](#dao-governance-participation)
7. [DEX Trading Features](#dex-trading-features)
8. [Security & Best Practices](#security--best-practices)
9. [Common Use Cases](#common-use-cases)
10. [FAQ & Troubleshooting](#faq--troubleshooting)

---

## What is Conxian?

Conxian is a production-ready DeFi platform built on the Stacks blockchain that brings Bitcoin-native decentralized finance to users worldwide. The platform combines traditional DeFi primitives with innovative Bitcoin integration and enterprise-level security.

### Key Benefits

- **Bitcoin-Native**: Built on Stacks, inheriting Bitcoin's security while enabling smart contracts
- **Community-Governed**: Fully decentralized governance through CXVG token holders
- **Multi-Asset Support**: Supports various cryptocurrencies with automatic yield optimization
- **Enterprise Security**: Multiple safety mechanisms:
                           - Circuit breakers and emergency controls
- **Revenue Sharing**: CXD holders receive 80% of protocol revenue
- **Automated Operations**: Self-managing system with minimal manual intervention required

### Platform Status

✅ **51 Smart Contracts** - All compiled and deployed  
✅ **130/131 Tests Passing** - Comprehensive test coverage  
✅ **Testnet Deployed** - Fully operational on Stacks Testnet  
✅ **Mainnet Ready** - Production deployment ready  

---

## Getting Started

### Step 1: Set Up Your Stacks Wallet

1. **Install a Stacks Wallet**:
   - [Hiro Wallet](https://wallet.hiro.so/) (Recommended)
   - [Xverse Wallet](https://www.xverse.app/)
   - [Leather Wallet](https://leather.io/)

2. **Fund Your Wallet**:
   - Acquire STX tokens for transaction fees
   - Obtain supported tokens for deposits (STX, sBTC when available)

### Step 2: Connect to Conxian

1. Navigate to the Conxian platform
2. Click "Connect Wallet"
3. Select your wallet and approve the connection
4. You're now ready to use Conxian!

### Step 3: Your First Deposit

1. **Choose Amount**: Enter the amount you want to deposit
2. **Select Token**: Choose from supported assets
3. **Review Fees**: Check deposit fee (default 0.30%)
4. **Confirm Transaction**: Approve in your wallet
5. **Receive Shares**: Get vault shares representing your ownership

---

## Core Features Overview

### 🏦 Yield Vault

The core Conxian feature that automatically optimizes yield on your deposited assets.

**Key Features:**

- Multi-asset support
- Automated yield strategies
- Precise share accounting
- Dynamic fee optimization
- Flash loan capabilities

### 🏛️ DAO Governance

Community-driven decision making for all platform parameters and upgrades.

**Key Features:**

- Proposal creation and voting
- Time-weighted voting power
- Execution delays for security
- Emergency pause capabilities
- Cross-contract governance

### 🪙 Token Economics

Multi-token system designed for sustainable growth and fair distribution.

**Tokens:**

- **CXVG**: Governance token (100M max supply)
- **CXD**: Revenue token (soft cap 1B; DAO-controlled emissions)
- **CXLP**: Liquidity provider token (50M max supply)
- **Creator**: Merit-based rewards for contributors

### 💱 DEX Integration

Built-in decentralized exchange for seamless token swapping and liquidity provision.

**Features:**

- Multi-hop routing
- Stable and weighted pools
- Liquidity mining rewards
- Automated market making

### 🛡️ Security Systems

Multiple layers of protection for user funds and platform stability.

**Security Features:**

- Circuit breakers for volatility protection
- Emergency pause mechanisms
- Multi-signature treasury controls
- Rate limiting for large transactions

---

## Vault Operations

### Making Deposits

#### Standard Deposit Process

1. **Navigate to Vault**: Go to the main vault interface
2. **Enter Amount**: Specify how much you want to deposit
3. **Select Asset**: Choose from supported tokens
4. **Review Details**:
   - Deposit amount
   - Current fee rate (0.30% default)
   - Expected shares received
   - Current vault APY
5. **Confirm Transaction**: Approve wallet transaction
6. **Track Progress**: Monitor transaction confirmation

#### Fee Structure

- **Deposit Fee**: 0.30% (adjustable by governance)
- **Fee Distribution**: 50% to treasury, 50% to protocol reserves
- **Dynamic Fees**: May adjust based on utilization (if enabled)

#### What You Receive

- **Vault Shares**: Represent proportional ownership of vault assets
- **Share Value**: Increases over time as vault generates yield
- **Governance Rights**: Shares may provide voting power in governance decisions

### Making Withdrawals

#### Standard Withdrawal Process

1. **Access Withdrawal**: Navigate to withdraw section
2. **Enter Amount**: Specify shares or underlying assets to withdraw
3. **Review Details**:
   - Withdrawal amount
   - Current fee rate (0.10% default)
   - Expected tokens received
   - Impact on your position
4. **Confirm Transaction**: Approve wallet transaction
5. **Receive Assets**: Tokens sent to your wallet

#### Withdrawal Options

- **Partial Withdrawal**: Withdraw portion of your position
- **Full Withdrawal**: Exit entire position
- **Emergency Withdrawal**: Quick exit during emergency pause

#### Important Notes

- **Share Value**: Your shares automatically appreciate with vault performance
- **No Lock-up**: Withdraw anytime (subject to available liquidity)
- **Fee Optimization**: Fees may be lower during certain periods

### Monitoring Your Position

#### Key Metrics to Track

1. **Total Value**: Current USD value of your position
2. **Share Count**: Number of vault shares owned
3. **APY**: Annual percentage yield on your deposits
4. **Fees Paid**: Historical fees from deposits/withdrawals
5. **Yield Earned**: Total yield generated over time

#### Dashboard Features

- **Real-time Updates**: Live position tracking
- **Performance Charts**: Historical yield and performance
- **Transaction History**: Complete record of deposits/withdrawals
- **Fee Analytics**: Breakdown of all fees paid

---

## Token Economics Guide

### CXVG Token (Governance)

**Purpose**: Governance token providing voting rights (no direct revenue share)

**Key Features:**

- **Max Supply**: 100,000,000 CXVG
- **Revenue Share**: None (protocol revenue accrues to CXD holders)
- **Voting Power**: Proportional to token balance and holding duration
- **Migration Path**: None; CXLP migrates to CXD (revenue token)

**How to Earn CXVG:**

1. **DAO Programs**: Governance rewards or grants (if approved)
2. **Governance Rewards**: Earn through active participation
3. **Secondary Markets**: Purchase from other users (when available)

**Benefits of Holding:**

- Vote on governance proposals
- Influence platform direction
- Priority access to new features

### CXLP Token (Liquidity Provider)

**Purpose**: Rewards for providing liquidity to the platform

**Key Features:**

- **Max Supply**: 50,000,000 CXLP
- **Migration**: Can convert to CXD during defined epoch bands
- **Earning Mechanism**: Provided as rewards for vault deposits and DEX liquidity

**Migration Schedule:**

- **Epoch Bands**: Increasing CXLP→CXD conversion across 4 bands (1.0x → up to 2.0x)
- **Timelocked & Bounded**: DAO-governed within guardrails; emergency auto‑migrate after E4

**How to Earn CXLP:**

1. **Vault Deposits**: Receive CXLP rewards for vault participation
2. **DEX Liquidity**: Provide liquidity to trading pairs
3. **Long-term Staking**: Bonus rewards for extended deposits

### Creator Token

**Purpose**: Merit-based rewards for platform contributors

**Key Features:**

- **Merit-Based**: Awarded for valuable contributions
- **Quality Assurance**: Tied to contribution quality metrics
- **Bounty System**: Earned through development and community work

**Ways to Earn:**

1. **Development Bounties**: Code contributions and bug fixes
2. **Community Building**: Educational content and user support
3. **Quality Assurance**: Testing and feedback provision
4. **Governance Participation**: Active and constructive voting

### Revenue Distribution

#### How Revenue is Generated

1. **Vault Fees**: Deposit (0.30%) and withdrawal (0.10%) fees
2. **Performance Fees**: 5% of yield above benchmark
3. **DEX Trading**: Trading fees from swaps
4. **Flash Loans**: 0.30% fee on flash loan usage

#### Distribution Mechanism

- **80% to Token Holders**: Distributed proportionally to CXD holders
- **20% to Treasury**: Used for development and platform growth
- **Automated Buybacks**: Treasury funds used to buy and burn tokens

---

## DAO Governance Participation

### Understanding DAO Governance

Conxian is governed by its community through a decentralized autonomous organization (DAO). CXVG token holders can propose and vote on changes to the platform.

### Governance Process

#### 1. Proposal Creation

**Requirements:**

- Hold minimum 100,000 CXVG tokens
- Provide detailed proposal description
- Specify implementation parameters

**Proposal Types:**

- **Parameter Changes**: Adjust fees, caps, limits
- **Treasury Spending**: Allocate funds for development
- **Emergency Actions**: Critical security measures
- **Contract Upgrades**: Deploy new features
- **Bounty Creation**: Fund development initiatives

#### 2. Voting Process

**Voting Period**: ~1 week (1,008 blocks)
**Quorum Requirement**: 20% of total CXVG supply must participate
**Voting Options**: For, Against, Abstain

**Time-Weighted Voting:**

- Longer holding periods = more voting power
- Prevents last-minute token accumulation for votes
- Rewards committed community members

#### 3. Execution

**Execution Delay**: ~1 day (144 blocks) after vote passes
**Automatic Execution**: Successful proposals execute automatically
**Timelock Protection**: Critical changes have additional delays

### How to Participate

#### Creating Proposals

1. **Prepare Proposal**: Draft detailed description and implementation plan
2. **Meet Requirements**: Ensure you hold enough CXVG tokens
3. **Submit Proposal**: Use governance interface to submit
4. **Community Discussion**: Engage with community for feedback
5. **Voting Campaign**: Advocate for your proposal

#### Voting on Proposals

1. **Review Proposals**: Read description and implementation details
2. **Assess Impact**: Consider effects on platform and users
3. **Cast Vote**: Choose For, Against, or Abstain
4. **Track Results**: Monitor voting progress and outcomes

#### Best Practices

- **Stay Informed**: Regular participation in community discussions
- **Long-term Thinking**: Consider platform sustainability
- **Research Thoroughly**: Understand proposal implications
- **Engage Constructively**: Provide thoughtful feedback

### Governance Topics

#### Common Governance Decisions

1. **Fee Adjustments**: Modify deposit/withdrawal fees
2. **Yield Strategies**: Approve new investment strategies
3. **Security Parameters**: Adjust risk controls
4. **Treasury Management**: Allocate development funds
5. **Partnership Approvals**: Integration with other protocols

#### Emergency Governance

- **Emergency Pause**: Immediate system shutdown if needed
- **Security Responses**: Rapid response to threats
- **Multi-sig Actions**: Critical treasury operations

---

## DEX Trading Features

### Overview

Conxian includes an integrated decentralized exchange (DEX) that enables seamless token swapping and liquidity provision without leaving the platform.

### Trading Features

#### Simple Swaps

1. **Select Tokens**: Choose input and output tokens
2. **Enter Amount**: Specify how much to swap
3. **Review Rate**: Check exchange rate and fees
4. **Execute Trade**: Confirm transaction in wallet

#### Multi-Hop Routing

- **Optimal Paths**: Automatically finds best trading routes
- **Lower Slippage**: Reduces price impact on large trades
- **Gas Efficiency**: Minimizes transaction costs

#### Pool Types

1. **Stable Pools**: For stablecoins with minimal slippage
2. **Weighted Pools**: For standard token pairs
3. **Liquidity Mining**: Earn rewards for providing liquidity

### Providing Liquidity

#### How to Provide Liquidity

1. **Select Pool**: Choose trading pair
2. **Add Tokens**: Deposit both tokens in proper ratio
3. **Receive LP Tokens**: Get pool shares representing ownership
4. **Earn Rewards**: Collect trading fees and mining rewards

#### Benefits

- **Trading Fees**: Earn from every trade in your pool
- **CXLP Rewards**: Receive liquidity provider tokens
- **Yield Farming**: Additional rewards for long-term liquidity

#### Risks

- **Impermanent Loss**: Value changes between paired tokens
- **Smart Contract Risk**: Technical risks of DEX contracts
- **Liquidity Risk**: Potential difficulty withdrawing during volatility

---

## Security & Best Practices

### Platform Security Features

#### Circuit Breakers

**Purpose**: Automatically pause operations during extreme market conditions

**Triggers:**

- High price volatility (>10% in short period)
- Unusual trading volume spikes
- Liquidity drops below safety thresholds

**User Impact:**

- Temporary pause of deposits/withdrawals
- Protection from adverse market conditions
- Automatic resume when conditions normalize

#### Emergency Controls

**Multi-Signature Treasury**: Requires multiple approvals for large treasury operations
**Emergency Pause**: Immediate shutdown capability for critical issues
**Rate Limiting**: Prevents flash attacks and protects against rapid capital movements

### User Security Best Practices

#### Wallet Security

1. **Use Hardware Wallets**: When possible, store keys on hardware devices
2. **Backup Seed Phrases**: Securely store wallet recovery phrases
3. **Verify Addresses**: Always double-check contract addresses
4. **Regular Updates**: Keep wallet software updated

#### Transaction Safety

1. **Start Small**: Begin with small amounts to test functionality
2. **Check Gas Fees**: Understand transaction costs before confirming
3. **Verify Details**: Review all transaction parameters carefully
4. **Monitor Transactions**: Track confirmations and results

#### Platform Interaction

1. **Official Channels**: Only use official Conxian interfaces
2. **Verify URLs**: Ensure you're on the correct website
3. **Stay Informed**: Follow official announcements for updates
4. **Report Issues**: Immediately report suspicious activity

### Risk Management

#### Understanding Risks

1. **Smart Contract Risk**: Potential bugs in contract code
2. **Market Risk**: Cryptocurrency price volatility
3. **Liquidity Risk**: Potential withdrawal delays during stress
4. **Governance Risk**: Community decisions affecting platform

#### Mitigation Strategies

1. **Diversification**: Don't put all funds in single protocol
2. **Position Sizing**: Only invest what you can afford to lose
3. **Stay Updated**: Monitor platform health and governance
4. **Exit Planning**: Understand withdrawal processes and timing

---

## Common Use Cases

### 1. Passive Yield Generation

**Goal**: Earn yield on cryptocurrency holdings with minimal effort

**Process:**

1. Deposit supported tokens into vault
2. Receive shares that automatically appreciate
3. Earn from automated yield strategies
4. Withdraw anytime with accumulated gains

**Benefits:**

- No active management required
- Automated optimization
- Transparent fee structure
- Flexible withdrawal timing

### 2. Liquidity Mining

**Goal**: Earn additional rewards by providing trading liquidity

**Process:**

1. Provide liquidity to DEX pools
2. Receive LP tokens representing pool ownership
3. Earn trading fees from swaps
4. Receive CXLP token rewards

**Benefits:**

- Multiple revenue streams
- Higher potential returns
- Support platform growth
- Access to governance rewards

### 3. Governance Participation

**Goal**: Influence platform direction and earn governance rewards

**Process:**

1. Acquire and hold CXVG tokens
2. Participate in proposal discussions
3. Review and vote on proposals
4. Track CXD revenue distributions

**Benefits:**

- Platform governance rights
- Revenue sharing (80% distribution)
- Long-term value alignment
- Community leadership opportunities

### 4. Dollar-Cost Averaging (DCA)

**Goal**: Regularly invest in DeFi with consistent strategy

**Process:**

1. Set up regular deposit schedule
2. Deposit fixed amounts at intervals
3. Accumulate shares over time
4. Benefit from compound growth

**Benefits:**

- Reduces timing risk
- Builds position systematically
- Leverages compound growth
- Minimizes emotional decision-making

### 5. Treasury Management

**Goal**: Manage organizational funds with DeFi yields

**Process:**

1. Deposit treasury funds to vault
2. Maintain liquidity for operations
3. Earn yield on idle funds
4. Withdraw as needed for expenses

**Benefits:**

- Treasury diversification
- Professional-grade security
- Transparent reporting
- Governance oversight

---

## FAQ & Troubleshooting

### Frequently Asked Questions

#### General Platform

**Q: Is Conxian safe to use?**
A: Conxian includes multiple security layers including circuit breakers, emergency controls, multi-signature treasury management, and comprehensive testing. However, all DeFi protocols carry smart contract and market risks.

**Q: What are the fees?**
A: Current fees are 0.30% for deposits, 0.10% for withdrawals, and 5% performance fees on yield above benchmark. Fees are adjustable through governance.

**Q: How do I earn CXVG tokens?**
A: CXLP migrates to CXD (revenue token), not to CXVG. Acquire CXVG via governance rewards/programs or secondary markets when available.

**Q: When will mainnet launch?**
A: Conxian is production-ready and deployed on testnet. Mainnet launch timing depends on final testing completion and community governance decisions.

#### Vault Operations

**Q: Can I withdraw my funds anytime?**
A: Yes, withdrawals are available anytime subject to available vault liquidity and current fee rates.

**Q: How is yield generated?**
A: Yield comes from automated strategies including DEX trading fees, lending protocols, and other DeFi opportunities, optimized by the platform.

**Q: What happens to my shares if the vault loses money?**
A: Share values can decrease during market downturns, but the platform includes circuit breakers and risk management to minimize losses.

#### Governance

**Q: How much CXVG do I need to vote?**
A: Any amount of CXVG provides voting power, but creating proposals requires 100,000 CXVG tokens.

**Q: How long do proposals take?**
A: Voting periods last about 1 week, with an additional 1-day execution delay for approved proposals.

**Q: Can governance decisions be reversed?**
A: New proposals can modify previous decisions, but implemented changes may have irreversible effects.

### Troubleshooting

#### Transaction Issues

**Problem**: Transaction failed or is stuck
**Solutions:**

1. Check gas fees and wallet balance
2. Verify transaction details are correct
3. Wait for network congestion to clear
4. Contact support if persistent issues

**Problem**: Cannot connect wallet
**Solutions:**

1. Refresh browser and try again
2. Check wallet is unlocked and on correct network
3. Clear browser cache and cookies
4. Try different browser or wallet

#### Platform Access

**Problem**: Cannot access platform features
**Solutions:**

1. Verify wallet connection is active
2. Check if platform is in emergency pause mode
3. Ensure sufficient gas for transactions
4. Review any error messages carefully

**Problem**: Incorrect balance or position display
**Solutions:**

1. Refresh page and wait for sync
2. Check transaction confirmations
3. Verify wallet address is correct
4. Contact support for persistent issues

### Getting Help

#### Support Channels

1. **Documentation**: Check this manual and technical docs
2. **Community Discord**: Join community discussions
3. **GitHub Issues**: Report bugs and technical issues
4. **Governance Forums**: Participate in governance discussions

#### Before Contacting Support

1. **Check Status Page**: Verify platform operational status
2. **Review Recent Transactions**: Check wallet transaction history
3. **Try Basic Troubleshooting**: Refresh, reconnect wallet, check gas
4. **Gather Information**: Screenshot errors, transaction hashes, timestamps

#### Emergency Situations

For critical issues affecting fund safety:

1. **Immediate Action**: Stop all platform interactions
2. **Emergency Contacts**: Use official emergency channels
3. **Document Everything**: Screenshots, transaction details, error messages
4. **Wait for Official Response**: Don't attempt unauthorized recovery methods

---

## Additional Resources

### Official Links

- **Platform Website**: [Conxian Official Site]
- **Documentation**: `/documentation/`
- **GitHub Repository**: [github.com/Anya-org/Conxian](https://github.com/Anya-org/Conxian)
- **Community Discord**: [Official Discord Link]

### Technical Documentation

- **[Architecture Guide](./ARCHITECTURE.md)**: Technical system design
- **[API Reference](./API_REFERENCE.md)**: Smart contract functions
- **[Security Documentation](./SECURITY.md)**: Security features and audits
- **[Developer Guide](./DEVELOPER_GUIDE.md)**: Development and integration
- **[Developer & Contract Guides](./contract-guides/README.md)**: Detailed guides for core smart contracts

### Educational Resources

- **[Tokenomics Guide](./TOKENOMICS.md)**: Complete economic model
- **[Roadmap](./ROADMAP.md)**: Development timeline and plans
- **[Status Reports](./STATUS.md)**: Current platform status

---

*This manual is maintained by the Conxian community. For suggestions or corrections, please submit issues or pull requests to the GitHub repository.*

**Version**: 1.0  
**Last Updated**: August 25, 2025  
**Next Review**: Quarterly or upon major platform updates
