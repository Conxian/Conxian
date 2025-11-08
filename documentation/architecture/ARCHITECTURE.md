# Conxian Stacks DeFi — Architecture: The Multi-Dimensional System

This document outlines the Conxian on-chain DeFi framework architecture, which is centered around the "Multi-Dimensional System." This system is a graph-based model of the entire DeFi ecosystem, designed to facilitate highly efficient trade routing and provide a framework for analyzing risk and liquidity.

## Principles

- **Unified Core:** A single, consolidated `dimensional-engine` contract serves as the central hub for all protocol functionality, including position management, risk assessment, lending, and DEX operations.
- **Composable & Extensible:** The system is designed to be highly composable and extensible, with new functionalities and assets registered in the `dim-registry`.
- **Safety-First:** Explicit invariants, post-conditions, and conservative fee/limit defaults are enforced by the `dimensional-engine`.
- **Sustainable Economics:** Fee capture to the protocol reserve and transparent emissions are managed by the core system.
- **BTC-Native Differentiation:** The system is designed to leverage Bitcoin anchoring and future BTC bridges (e.g., sBTC) for differentiation.

## Core Contracts

### The Multi-Dimensional System

- **`dimensional-engine.clar`**: The heart of the protocol. This contract consolidates all core functionalities, including:
    - **Position Management:** Creation, closing, and management of all position types.
    - **Risk Management:** Leverage, margin, and liquidation checks.
    - **Lending:** Supplying, borrowing, and interest rate calculations.
    - **DEX Operations:** Core swap and liquidity provision logic.
- **`dim-graph.clar`**: Manages the relationships and flow of value between different "dimensions" (i.e., system components).
- **`dim-registry.clar`**: The central nervous system of the protocol. It registers and weights all components within the dimensional architecture, including tokens, pools, and oracles.
- **`advanced-router-dijkstra.clar`**: A specialized routing engine that uses Dijkstra's algorithm to find the optimal path for any given swap, minimizing slippage and fees.

### Foundational Libraries

- `math-lib-advanced.clar` – Advanced mathematical functions (sqrt, pow, ln, exp) using Newton-Raphson and Taylor series
- `fixed-point-math.clar` – Precise arithmetic operations with proper rounding modes for 18-decimal precision
- `precision-calculator.clar` – Validation and benchmarking tools for mathematical operations

Traits & Interfaces are defined in `contracts/traits/all-traits.clar`.

## Roadmap

With the successful consolidation of the core protocol into the Multi-Dimensional System, the roadmap is now focused on expanding the capabilities of the system and integrating new features.

1. **Integrate DEX & Routing Logic:** Refactor the remaining DEX-related contracts, merging routing logic into the `advanced-router-dijkstra` and other core DEX functionalities into the `dimensional-engine`.
2. **Incorporate Lending System:** Consolidate the remaining lending functionalities into the multi-dimensional framework, ensuring seamless interaction with the core trading and risk engine.
3. **sBTC Integration**: BTC-native strategies and collateral support.
4. **Advanced Risk Models**: VaR calculations and portfolio optimization using implemented math functions.
5. **Cross-Chain Flash Loans**: Bridge integration for cross-chain arbitrage opportunities.

Updated: Nov 07, 2025
