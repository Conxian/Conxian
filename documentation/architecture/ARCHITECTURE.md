# Conxian Stacks DeFi — Design

This document outlines the Conxian on-chain DeFi framework architecture (current framework implementation + development roadmap) on Stacks, leveraging Bitcoin anchoring and future BTC bridges (e.g., sBTC) for differentiation.  

## Principles

- Minimal, composable core: single vault primitive with predictable accounting
- Parameterized via DAO (fees, caps, allowlists), not code changes
- Safety-first: explicit invariants, post-conditions, and conservative fee/limit defaults
- Sustainable economics: fee capture to protocol reserve, transparent emissions (if any)
- BTC-native differentiation: accept BTC-derivatives (e.g., sBTC) and anchor state to Bitcoin

## Core Contracts (Framework Level)

### Foundation Layer
- `vault.clar` – Core user asset vault with an internal, metrics-driven yield engine.
- `math-lib-advanced.clar` – Advanced mathematical functions (sqrt, pow, ln, exp) using Newton-Raphson and Taylor series
- `fixed-point-math.clar` – Precise arithmetic operations with proper rounding modes for 18-decimal precision
- `precision-calculator.clar` – Validation and benchmarking tools for mathematical operations

### Lending & Flash Loan Framework
- `comprehensive-lending-system.clar` – Framework lending protocol with supply, borrow, liquidation, and flash loans
- `flash-loan-vault.clar` – A specialized vault for executing ERC-3156 compatible flash loans.
- `interest-rate-model.clar` – Dynamic interest rate calculation framework based on utilization curves
- `loan-liquidation-manager.clar` – Basic liquidation framework with keeper incentive structure
- `lending-protocol-governance.clar` – Community governance framework for protocol parameters
- `flash-loan-receiver-trait.clar` – Interface for flash loan callback implementations
- `lending-system-trait.clar` – Comprehensive lending protocol interface definitions

### Token System
- `cxd-staking.clar` – Staking contract for CXD tokens
- `cxd-token.clar` – The main token contract for CXD
- `CXLP-migration-queue.clar` – Manages the migration of CXLP tokens
- `CXLP-token.clar` – The liquidity pool token
- `cxs-token.clar` – A secondary token in the system
- `cxtr-token.clar` – A tertiary token in the system
- `cxvg-token.clar` – The governance token
- `cxvg-utility.clar` – Utility contract for the governance token

### DEX Infrastructure
- `dex-factory.clar` – Factory for creating DEX pools with advanced math integration
- `dex-pool.clar` – Standard DEX pool with precision mathematics
- `dex-router.clar` – Router for the DEX with multi-hop capabilities

### Monitoring & Security
- `automated-circuit-breaker.clar` – Automated circuit breaker for the system
- `protocol-invariant-monitor.clar` – Monitors the protocol for invariants
- `revenue-distributor.clar` – Distributes revenue to stakeholders
- `token-emission-controller.clar` – Controls the emission of new tokens
- `token-system-coordinator.clar` – Coordinates the token system

### Additional Infrastructure Framework
- `distributed-cache-manager.clar` – Basic distributed caching framework structure
- `memory-pool-management.clar` – Memory pool optimization framework
- `predictive-scaling-system.clar` – System scaling prediction framework
- `real-time-monitoring-dashboard.clar` – Monitoring framework structure
- `transaction-batch-processor.clar` – Transaction batch processing framework
  
Traits & Interfaces: `vault-trait`, `vault-admin-trait`, `pool-trait`, `sip-010-trait`.

## Differentiation via Bitcoin Layers (Planned / Partially Enabled)

- Accept sBTC (or wrapped BTC) as primary collateral asset
- Anchor protocol state to Bitcoin via Stacks settlement
- BTC-native strategies (e.g., BTC LSTs or staking derivatives) when available

## Security & Upgrades

- No code upgrade in-place; deploy new versions and migrate via proxy/dispatcher pattern
- Use Clarity post-conditions for critical user flows
- Use events for all state-changing actions; support off-chain indexing
- Exhaustive input checks; prefer u* operations and explicit bounds

## Gas/Cost Optimization

- Minimize map writes; write only when balances change
- Batch parameter updates; avoid per-user loops
- Use read-only calls for getters and price queries
- Compact events; avoid oversized payloads

## Oracles & Pricing (Planned)

- Prefer on-chain TWAPs or signed-oracle updates with minimal cadence
- Price-dependent logic behind caps/limits rather than per-tx dynamic heavy math

## Roadmap

Framework Implemented:

1. **Mathematical Foundation**: Advanced mathematical function framework (sqrt, pow, ln, exp) with Newton-Raphson and Taylor series algorithms
2. **Lending System Framework**: Supply, borrow, liquidation framework with basic ERC-3156 compatible flash loans
3. **Interest Rate Framework**: Utilization-based rate calculation framework with kink models
4. **Risk Management Framework**: Health factor monitoring framework, basic liquidation structure, keeper incentive framework
5. **Governance Framework**: Community-driven parameter management framework and upgrade structure
6. **Token Integration**: Basic SIP-010 token framework (governance & auxiliary tokens)
7. **Test Framework**: Unit, integration, and basic validation framework, circuit breaker testing
8. **DEX Framework**: AMM core framework, router structure, mathematical library foundation
9. **Monitoring Framework**: Basic monitoring structure with event framework

Current Development:

1. **Framework Integration**: Connecting lending framework with existing vault infrastructure
2. **Pool Support Framework**: Leveraging mathematical foundation for concentrated liquidity structure
3. **Protocol Optimization Framework**: Flash loan arbitrage framework and yield optimization structure

Upcoming:

1. **Concentrated Liquidity**: Full Uniswap V3 style implementation using existing math foundation
2. **Cross-Chain Flash Loans**: Bridge integration for cross-chain arbitrage opportunities  
3. **Advanced Risk Models**: VaR calculations and portfolio optimization using implemented math functions
4. **sBTC Integration**: BTC-native strategies and collateral support

## DEX Subsystem (Enhanced with Advanced Mathematics)

**Core Implementation**: `dex-factory`, `dex-pool`, `dex-router`, `math-lib-advanced`, `fixed-point-math`, `pool-trait`

**Mathematical Capabilities**: 
- Newton-Raphson square root for liquidity calculations
- Binary exponentiation for weighted pool invariants  
- Taylor series ln/exp for compound interest and advanced pricing models
- 18-decimal precision arithmetic with proper rounding modes

**Framework Features Available**:
- Concentrated liquidity pool mathematics framework implemented
- Weighted pool invariant calculation framework supported
- TWAP oracle integration framework structure prepared
- Multi-hop routing framework with slippage calculation structure

**Prototypes / Experimental**: `stable-pool`, `weighted-pool`, `multi-hop-router`, `mock-dex`

## The Dimensional DeFi System: An Architectural Overview

### Introduction

The "Dimensional DeFi System" is the core architectural innovation of the Conxian protocol. It is a graph-based model of the entire DeFi ecosystem, designed to facilitate highly efficient trade routing and provide a framework for analyzing risk and liquidity. This document provides a detailed overview of this system.

### Core Concepts

The dimensional system is built on a few core concepts:

*   **Dimensions:** These are the nodes in our graph. A "dimension" can represent a token, a liquidity pool, a vault, or any other component of the DeFi ecosystem.
*   **Edges:** These are the connections between dimensions. An edge represents a possible interaction, such as a swap in a liquidity pool.
*   **Flow:** This is a metric associated with each edge, representing the amount of liquidity or other resources that can move between two dimensions.
*   **Weight:** This is a calculated value for each edge, representing the "cost" of traversing that edge. For a token swap, the weight is typically a function of the liquidity and the fee, with lower weights being more desirable.

### The System as a Graph

The entire Conxian protocol can be visualized as a directed graph, where the contracts and assets are the nodes and the possible interactions are the edges. This is managed by a suite of smart contracts in the `stacks/contracts/dimensional/` directory.

*   **`dim-graph.clar`:** This contract is the core of the system, storing the graph's structure (adjacency lists) and the "flow" metrics between dimensions. It provides a low-level interface for setting and querying the connections in the graph.
*   **`dim-registry.clar`:** (Note: This contract is currently empty, but its intended purpose is to provide a human-readable registry of all the dimensions in the system.)
*   **`advanced-router-dijkstra.clar`:** This is the most critical application of the dimensional graph. It uses Dijkstra's algorithm to find the shortest path between any two token dimensions, which corresponds to the most efficient trade route (i.e., the best price).

### Architectural Diagram (Text-Based)

`
       +------------------+
       |   dim-graph.clar | (Stores Edges & Flow)
       +------------------+
              ^
              | (Reads Graph Structure)
              |
+---------------------------------+      +------------------------+
| advanced-router-dijkstra.clar   |----->|   Liquidity Pools      | (Executes Swaps)
+---------------------------------+      | (e.g., dex-pool.clar)  |
              ^                        +------------------------+
              | (Finds Optimal Path)
              |
       +------------------+
       |   User/Client    |
       +------------------+
`

### How It Works in Practice: A Trade Routing Example

1.  **Graph Construction:** The system administrator or a designated writer contract populates the `dim-graph.clar` contract with the current state of the protocol. This includes adding all supported tokens as dimensions and all liquidity pools as edges between them.
2.  **Trade Initiation:** A user initiates a trade from Token A to Token D.
3.  **Pathfinding:** The `advanced-router-dijkstra.clar` contract is called. It reads the graph structure from `dim-graph.clar` and calculates the edge weights for all possible paths. It then uses Dijkstra's algorithm to find the shortest path, which might be A -> B -> C -> D.
4.  **Execution:** The router then executes the series of swaps along the optimal path: A -> B in one pool, B -> C in another, and C -> D in a third.

### Benefits of the Dimensional System

*   **Efficiency:** By finding the globally optimal path for a trade, the system can offer better prices and lower slippage than a simple multi-hop router.
*   **Extensibility:** New liquidity sources, vaults, or other DeFi primitives can be easily added to the graph as new dimensions and edges.
*   **Risk Analysis:** The graph structure and "flow" metrics can be used for advanced risk analysis, such as modeling risk contagion between different parts of the system.
*   **Gas Optimization:** While the pathfinding algorithm has a computational cost, it can lead to more gas-efficient trades by avoiding unnecessary hops.

### Future Applications

The dimensional system is a flexible framework that can be extended beyond trade routing. Future applications could include:

*   **Yield Optimization:** Finding the optimal path for capital to flow to generate the highest yield.
*   **Liquidation Routing:** Determining the most efficient way to liquidate a large position with minimal market impact.
*   **Cross-Chain Operations:** Modeling cross-chain bridges as dimensions in the graph to find the best routes for moving assets between blockchains.
