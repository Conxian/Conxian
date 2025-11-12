# Dimensional Module

Multi-dimensional DeFi system implementing spatial, temporal, risk, cross-chain, and institutional dimensions for advanced financial operations.

## Overview

This module provides a comprehensive multi-dimensional DeFi framework with:

- Dimensional staking with variable yields
- Revenue distribution and optimization
- Metrics tracking and analytics
- Cross-chain dimensional operations
- NFT-based position management
- Bond integration and tokenized debt instruments

## Key Contracts

### Core Dimensional System

- `dimensional-core.clar`: Main dimensional protocol coordinator with position management
- `dim-registry.clar`: Registry for dimensional components with deterministic token ordering
- `dim-graph.clar`: Graph-based dimensional routing and optimization

### Staking & Yield

- `dim-yield-stake.clar`: Dimensional staking with utilization-based yields
- `dim-revenue-adapter.clar`: Revenue collection and distribution across dimensions
- `dim-metrics.clar`: Multi-dimensional metrics tracking and analytics

### Advanced Features

- `position-nft.clar`: NFT-based position management for dimensional positions
- `tokenized-bond.clar`: Bond tokenization for dimensional debt instruments
- `tokenized-bond-adapter.clar`: Adapter for bond integration with dimensional system

### Integration & Routing

- `advanced-router-dijkstra.clar`: Advanced routing using Dijkstra's algorithm for optimal paths
- `dim-oracle-automation.clar`: Automated oracle updates for dimensional metrics

## Dimensions

### Spatial Dimension

Concentrated liquidity with tick-based pricing and sqrt-price-x96 calculations.

### Temporal Dimension

Time-weighted metrics and exponential moving averages for trend analysis.

### Risk Dimension

Volatility surfaces, implied volatility calculations, and VaR/CVaR metrics.

### Cross-Chain Dimension

Bitcoin-anchored finality with cross-chain verification and stacker validation.

### Institutional Dimension

Enterprise APIs with compliance integration and advanced order types.

## Usage

### Staking in Dimensions

```clarity
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(contract-call? .dim-yield-stake stake-dimension dim-id amount lock-period token-contract)
```

### Opening Dimensional Positions

```clarity
(use-trait dimensional-core-trait .all-traits.dimensional-core-trait)
(contract-call? .dimensional-core open-position collateral-amount leverage position-type slippage-tolerance token funding-interval tags metadata)
```

### Calculating Revenue Allocation

```clarity
(use-trait dim-revenue-adapter-trait .all-traits.dim-revenue-adapter-trait)
(contract-call? .dim-revenue-adapter calculate-dimensional-allocation total-budget)
```

## Security Features

- Multi-dimensional risk assessment
- Circuit breaker integration
- Emergency governance mechanisms
- Deterministic token ordering
- Cross-chain validation

## Related Documentation

- [Conxian Protocol Architecture](../architecture/ARCHITECTURE.md)
- [Multi-Hop Router Documentation](../dex/README.md)
- [Oracle Integration Guide](../guides/oracle-integration.md)
