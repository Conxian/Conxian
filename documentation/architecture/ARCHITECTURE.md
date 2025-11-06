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

- `circuit-breaker.clar` – Automated circuit breaker for the system
- `protocol-invariant-monitor.clar` – Monitors the protocol for invariants
- `token-emission-controller.clar` – Controls the emission of new tokens
- `token-system-coordinator.clar` – Coordinates the token system

### Additional Infrastructure Framework

- `distributed-cache-manager.clar` – Basic distributed caching framework structure
- `memory-pool-management.clar` – Memory pool optimization framework
- `predictive-scaling-system.clar` – System scaling prediction framework
- `real-time-monitoring-dashboard.clar` – Monitoring framework structure
- `transaction-batch-processor.clar` – Transaction batch processing framework
  
Traits & Interfaces are defined in `contracts/traits/all-traits.clar`.

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

**Core Implementation**: `dex-factory`, `dex-pool`, `dex-router`, `math-lib-advanced`, `fixed-point-math`

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

## The Dimensional DeFi System: An Architectural Overview

A key innovation in the Conxian protocol is its "dimensional" architecture. This refers to a graph-based representation of the entire DeFi ecosystem, where:

- **Nodes** are tokens.
- **Edges** are liquidity pools or other connections between tokens.
- **Edge Weights** are calculated based on liquidity, fees, and other factors.

This allows for highly efficient trade routing. The `advanced-router-dijkstra.clar` contract uses Dijkstra's algorithm to find the optimal path for any given swap, minimizing slippage and fees.

### Integrating with the Dimensional Router

While retail users will interact with this router through the standard `dex-router.clar`, institutions can integrate directly with the `advanced-router-dijkstra.clar` contract to:

- **Query for optimal paths:** Use `find-optimal-path` to determine the best route for a trade before execution.
- **Execute complex swaps:** The `swap-optimal-path` function allows for the execution of a swap along the most efficient route.

Updated: Sep 09, 2025
