# Pools Module

Liquidity pool implementations for the Conxian Protocol supporting various automated market maker (AMM) designs including concentrated liquidity and tiered pool structures.

## Overview

The pools module provides flexible liquidity pool infrastructure supporting:

- **Concentrated Liquidity**: Tick-based pricing with capital efficiency
- **Tiered Pool Structures**: Multi-tier liquidity with different fee structures
- **NFT Position Management**: Non-fungible tokens representing LP positions
- **Yield Optimization**: Automated fee collection and compounding
- **Cross-Pool Integration**: Seamless liquidity migration and optimization

## Key Contracts

### Concentrated Liquidity Pool (`concentrated-liquidity-pool.clar`)

**Core Features:**

- **Tick-based pricing** with sqrt-price-x96 calculations
- **NFT position management** for LP tokens
- **Dynamic fee collection** based on position size and duration
- **Automatic compounding** of trading fees
- **Slippage protection** with customizable tolerance

**Key Functions:**

```clarity
;; Create liquidity position
(create-position tick-lower tick-upper amount-0 amount-1 recipient)

;; Add liquidity to existing position
(add-liquidity position-id amount-0 amount-1 recipient)

;; Remove liquidity
(remove-liquidity position-id liquidity-amount recipient)

;; Collect accrued fees
(collect-fees position-id recipient)
```

**Position Management:**

- **NFT-backed positions** with unique identifiers
- **Metadata storage** for position parameters
- **Transferable positions** between users
- **Merge/split operations** for position management

### Tiered Pools (`tiered-pools.clar`)

**Pool Structure:**

- **Multiple fee tiers** (0.01%, 0.05%, 0.30%, 1.00%)
- **Dynamic tier selection** based on market conditions
- **Liquidity incentives** for higher fee tiers
- **Automatic rebalancing** between tiers

**Tier Benefits:**

- **Fee Tier 0.01%**: Best for stable pairs, low fees
- **Fee Tier 0.05%**: Balanced for most pairs
- **Fee Tier 0.30%**: Higher fees for volatile pairs
- **Fee Tier 1.00%**: Maximum fees for exotic pairs

## Pool Economics

### Fee Structure

```
Fee Tiers:
├── 0.01% → Stable pairs (USDC/USDT)
├── 0.05% → Standard pairs (WBTC/WETH)
├── 0.30% → Volatile pairs (MEME/WETH)
└── 1.00% → High-risk pairs (NEW/WETH)
```

### Reward Distribution

- **Trading fees** distributed to liquidity providers
- **Protocol fees** collected for ecosystem development
- **Incentive rewards** for providing liquidity in low-liquidity pools
- **Boost multipliers** for concentrated positions

## Usage Examples

### Creating Concentrated Positions

```clarity
;; Create a new concentrated liquidity position
(contract-call? .concentrated-liquidity-pool create-position
  token-a token-b
  tick-lower tick-upper
  amount-0-desired amount-1-desired
  amount-0-min amount-1-min
  recipient deadline)
```

### Managing Positions

```clarity
;; Add more liquidity to existing position
(contract-call? .concentrated-liquidity-pool add-liquidity
  position-id
  amount-0 amount-1
  recipient)

;; Collect accumulated fees
(contract-call? .concentrated-liquidity-pool collect-fees
  position-id recipient)

;; Remove liquidity partially
(contract-call? .concentrated-liquidity-pool remove-liquidity
  position-id liquidity-amount recipient)
```

### Tiered Pool Operations

```clarity
;; Initialize a tiered pool
(contract-call? .tiered-pools create-pool
  token-a token-b fee-tier)

;; Add liquidity to specific tier
(contract-call? .tiered-pools add-liquidity
  pool-id tier-id amount-a amount-b recipient)

;; Swap with tier selection
(contract-call? .tiered-pools swap
  pool-id amount-in token-in token-out
  min-amount-out recipient)
```

## Position NFT Standard

### NFT Metadata Structure

```json
{
  "tokenId": "12345",
  "pool": "0x...",
  "tickLower": "-887272",
  "tickUpper": "887272",
  "liquidity": "1234567890123456789",
  "feeGrowthInside0LastX128": "0",
  "feeGrowthInside1LastX128": "0",
  "tokensOwed0": "0",
  "tokensOwed1": "0"
}
```

### NFT Functions

- **Minting**: Automatic on position creation
- **Transferring**: Standard NFT transfers supported
- **Burning**: On complete liquidity removal
- **Querying**: Position data via NFT metadata

## Integration Features

### With DEX Router

- **Optimal routing** through pool liquidity
- **Multi-hop swaps** across different pool types
- **Slippage optimization** using concentrated liquidity
- **Gas optimization** through efficient path finding

### With Yield Farming

- **LP token staking** for additional rewards
- **Fee compounding** through automation
- **Incentive alignment** between LPs and protocol
- **Dynamic fee distribution** based on position performance

### With Governance

- **Fee tier voting** for pool parameters
- **Incentive program** approval and management
- **Emergency controls** for pool pausing
- **Upgrade coordination** for pool improvements

## Security Features

### Access Controls

- **Position ownership** verification for all operations
- **Slippage protection** with minimum output guarantees
- **Deadline enforcement** to prevent stale transactions
- **Reentrancy guards** for complex operations

### Economic Security

- **Impermanent loss protection** through diversified positions
- **Liquidity depth monitoring** to prevent manipulation
- **Circuit breakers** for extreme market conditions
- **Gradual liquidity changes** to prevent flash crashes

## Performance Optimizations

### Gas Efficiency

- **Batch operations** for multiple position updates
- **Optimized tick traversal** for price calculations
- **Lazy fee collection** to minimize on-chain operations
- **Compact storage** patterns for position data

### Scalability

- **Tiered fee structure** for different use cases
- **Position chunking** for large liquidity operations
- **Event-driven updates** for external integrations
- **Caching mechanisms** for frequently accessed data

## Monitoring & Analytics

### Pool Metrics

- **TVL tracking** across all positions
- **Volume analysis** by pool and time period
- **Fee generation** and distribution tracking
- **Liquidity distribution** across price ranges

### Position Analytics

- **PnL calculations** for individual positions
- **Fee earnings** over time periods
- **Impermanent loss** assessments
- **Optimal range** recommendations

## Migration & Upgrades

### LP Token Migration

- **Seamless upgrades** from v1 to v2 pools
- **Position preservation** during protocol updates
- **Fee continuity** across migration periods
- **Incentive alignment** through migration bonuses

### Pool Type Transitions

- **Migration tools** between pool types
- **Liquidity conversion** with optimal pricing
- **Position merging** for concentrated liquidity
- **Fee tier optimization** based on market conditions

## Related Documentation

- [Concentrated Liquidity Guide](../documentation/guides/CONCENTRATED_LIQUIDITY.md)
- [Pool Architecture](../documentation/architecture/POOL_ARCHITECTURE.md)
- [LP Token Standard](../documentation/standards/LP_TOKEN_STANDARD.md)
- [Yield Farming Guide](../documentation/guides/YIELD_FARMING.md)
