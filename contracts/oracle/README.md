# Oracle Module

Decentralized price feed and data oracle system for the Conxian Protocol providing reliable price data for DeFi operations, lending protocols, and liquidation management.

## Overview

The oracle module delivers comprehensive price feed infrastructure supporting:

- **Multi-Source Aggregation**: Multiple price feed sources for reliability
- **Cross-Chain Data**: Bitcoin and external blockchain price feeds
- **Dimensional Pricing**: Multi-dimensional asset pricing models
- **Manipulation Resistance**: Time-weighted averages and outlier detection
- **Real-Time Updates**: Live price feeds with freshness guarantees

## Key Contracts

### Core Oracle Infrastructure

#### Oracle Aggregator V2 (`oracle-aggregator-v2.clar`)

- **Primary aggregation engine** combining multiple price sources
- **Time-weighted average prices** (TWAP) for stability
- **Outlier detection** and manipulation resistance
- **Fallback mechanisms** for source failures
- **Configurable update intervals** and deviation thresholds

#### Base Oracle (`oracle.clar`)

- **Fundamental oracle interface** and data structures
- **Price storage and retrieval** with timestamp tracking
- **Basic validation** and freshness checks
- **Emergency pause** functionality

### Specialized Oracles

#### External Oracle Adapter (`external-oracle-adapter.clar`)

- **Integration with external price feeds** (Chainlink, Pyth, etc.)
- **Cross-chain price data** from multiple blockchains
- **Adapter pattern** for different oracle providers
- **Security validations** and signature verification
- **Gas-efficient updates** through batched operations

#### Dimensional Oracle (`dimensional-oracle.clar`)

- **Multi-dimensional asset pricing** beyond simple spot prices
- **Volatility surfaces** and implied volatility calculations
- **Time-decay functions** for temporal pricing analysis
- **Cross-chain price correlations** and arbitrage detection
- **Advanced statistical analysis** for risk assessment

## Oracle Architecture

### Price Feed Sources

```
┌─────────────────┐    ┌─────────────────┐
│   Chainlink     │    │      Pyth       │
│   Price Feeds   │    │   Price Feeds   │
└─────────┬───────┘    └─────────┬───────┘
          │                      │
          └──────────┬───────────┘
                     │
          ┌─────────────────────┐
          │  Oracle Aggregator  │
          │   V2 (Primary)      │
          └─────────┬───────────┘
                    │
          ┌─────────────────────┐
          │  Protocol Contracts │
          │  (DEX, Lending, etc)│
          └─────────────────────┘
```

### Data Flow

1. **Source Updates**: External oracles push price updates
2. **Validation**: Freshness, deviation, and signature checks
3. **Aggregation**: Multiple sources combined with TWAP
4. **Distribution**: Clean price feeds to consuming contracts
5. **Fallback**: Emergency price feeds if primary sources fail

## Usage Examples

### Querying Prices

```clarity
;; Get aggregated price for a token pair
(contract-call? .oracle-aggregator-v2 get-price token-a token-b)

;; Get dimensional price data
(contract-call? .dimensional-oracle get-dimensional-price token dimensions)

;; Check price freshness
(contract-call? .oracle-aggregator-v2 get-last-update-time token)
```

### Oracle Management

```clarity
;; Update price feeds (admin only)
(contract-call? .oracle-aggregator-v2 update-price token price)

;; Configure oracle sources
(contract-call? .oracle-aggregator-v2 add-price-source source-address)

;; Emergency pause
(contract-call? .oracle-aggregator-v2 emergency-pause true)
```

### Advanced Features

```clarity
;; Get volatility surface
(contract-call? .dimensional-oracle get-volatility-surface token expiry strike)

;; Calculate time-weighted average
(contract-call? .oracle-aggregator-v2 get-twap token time-window)

;; Cross-chain price correlation
(contract-call? .external-oracle-adapter get-cross-chain-price token chain-id)
```

## Security Features

### Manipulation Resistance

- **Multi-source validation** prevents single-point failures
- **Time-weighted averaging** smooths price manipulation attempts
- **Deviation thresholds** reject extreme price movements
- **Outlier detection** using statistical analysis

### Reliability Guarantees

- **Freshness checks** ensure recent price updates
- **Fallback mechanisms** for oracle failures
- **Circuit breakers** for extreme market conditions
- **Emergency controls** for protocol protection

### Audit Compliance

- **Comprehensive logging** of all price updates
- **Access controls** for administrative functions
- **Upgrade mechanisms** with timelocks
- **Invariant monitoring** for data consistency

## Integration Points

### DEX Integration

- **Price feeds** for swap calculations and slippage protection
- **Liquidation prices** for concentrated liquidity positions
- **MEV protection** through accurate price discovery

### Lending Protocols

- **Collateral valuation** for loan-to-value calculations
- **Liquidation triggers** based on accurate price feeds
- **Interest rate adjustments** based on market conditions

### Risk Management

- **Portfolio valuation** for dimensional positions
- **VaR calculations** using volatility surfaces
- **Stress testing** with historical price data

## Performance Optimizations

### Gas Efficiency

- **Batch updates** for multiple price feeds
- **Optimized storage** patterns for frequent access
- **Caching mechanisms** for hot data paths
- **Event-driven updates** to minimize on-chain calls

### Scalability

- **Multi-oracle support** for increased throughput
- **Parallel processing** of price feed updates
- **Distributed validation** across multiple nodes
- **Layered caching** for different data freshness requirements

## Oracle Economics

### Incentive Structure

- **Reporter rewards** for timely price updates
- **Slashing penalties** for incorrect or late submissions
- **Stake requirements** for oracle participation
- **Reputation system** for quality-based weighting

### Fee Model

- **Protocol fees** for oracle usage
- **Premium feeds** for high-frequency traders
- **Bulk discounts** for heavy users
- **Cross-subsidization** between free and premium tiers

## Monitoring & Analytics

### Real-Time Monitoring

- **Price deviation alerts** for market anomalies
- **Source health checks** for oracle reliability
- **Latency monitoring** for update timeliness
- **Volume analysis** for market impact assessment

### Historical Data

- **Price history** for TWAP calculations
- **Volatility tracking** for risk assessment
- **Correlation analysis** for portfolio optimization
- **Arbitrage detection** across multiple markets
