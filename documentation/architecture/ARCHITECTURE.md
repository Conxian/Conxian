# Conxian Protocol Architecture

This document outlines the current Conxian protocol architecture, a comprehensive multi-dimensional DeFi system deployed on the Stacks blockchain. The protocol has recently undergone a significant refactoring to improve modularity, clarity, and efficiency.

**Last Updated**: November 23, 2025

## Architecture Principles

- **Modular Design**: The protocol is divided into a series of specialized modules, each with a well-defined responsibility (e.g., DEX, Lending, Governance).
- **Modular Trait System**: All contract interfaces are defined in a set of **10 modular trait files**, which are aggregated in a central registry. This provides a clear, consistent, and gas-efficient way for contracts to interact.
- **Bitcoin-Native**: The protocol leverages Stacks' Bitcoin anchoring for security and finality, with a particular focus on sBTC integration.
- **Enterprise-Ready**: The architecture includes foundational frameworks for institutional features and compliance integration.
- **Multi-Dimensional**: The protocol is designed to support a multi-dimensional financial system, with distinct layers for spatial, temporal, risk, and cross-chain operations.

## Core Contract Modules

The Conxian protocol is organized into a series of specialized modules, each located in a dedicated subdirectory within the `contracts` directory.

### Core Modules
- **`core`**: Contains the core logic of the dimensional engine, which is responsible for coordinating the various dimensions of the protocol.
- **`dex`**: A feature-complete decentralized exchange with a modular router, a factory for creating liquidity pools, and support for concentrated liquidity.
- **`governance`**: A modular proposal and voting system that allows the community to manage the protocol.
- **`lending`**: A feature-complete, multi-asset lending and borrowing system, centered around the `comprehensive-lending-system.clar` contract.

### Supporting Modules
- **`access`**: Role-based access control and permissions management.
- **`audit-registry`**: A registry for audit information and security-related data.
- **`automation`**: Contracts for automating routine tasks and managing keepers.
- **`enterprise`**: Frameworks for institutional integration, including compliance and advanced loan management.
- **`oracle`**: Price feed and oracle aggregation services.
- **`sbtc`**: Integration with sBTC, including a BTC adapter and DLC manager.
- **`security`**: Security-related contracts, including the circuit breaker and MEV protection.
- **`tokens`**: The protocol's native tokens and token management utilities.
- **`traits`**: The modular trait system, which defines all contract interfaces.
- **`vaults`**: A decentralized sBTC vault and other asset management vaults.

## Trait Architecture

The protocol's trait system is organized into **10 modular files**, which provide a clear and efficient way to define contract interfaces. For a detailed overview of the trait architecture, please see the [`contracts/traits/README-TRAIT-ARCHITECTURE.md`](../traits/README-TRAIT-ARCHITECTURE.md) file.

## Security Architecture

The protocol includes a multi-layered security architecture to protect user funds and ensure system stability.

- **Circuit Breakers**: An emergency pause mechanism that can be triggered to halt protocol operations under extreme market conditions.
- **MEV Protection**: Mechanisms to mitigate the effects of Maximal Extractable Value (MEV), such as batch auctions.
- **Access Controls**: A role-based access control system to manage permissions for sensitive functions.
- **Invariant Monitoring**: A system for monitoring key protocol invariants to detect anomalies and potential security threats.

## Deployment Architecture

The protocol is deployed using a manifest-based system, with separate configurations for testnet and mainnet. The deployment plan is managed by the `Clarinet.toml` and `deployments/default.testnet-plan.yaml` files.

## Current Status

The Conxian protocol is in the final stages of a major architectural refactoring. The core modules are feature-complete, and the trait system has been migrated to a new, modular architecture. The next critical steps are to complete a comprehensive test suite audit and an external security audit.
