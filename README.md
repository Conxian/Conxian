# Conxian Protocol

> **For a comprehensive overview of our vision, business goals, and strategic roadmap, please see our [Strategic Overview](./documentation/STRATEGIC_OVERVIEW.md).**

## Overview

Conxian is a sophisticated, multi-dimensional DeFi protocol on Stacks, designed to provide a unified, secure, and efficient ecosystem for advanced financial operations. It has been architected from the ground up to be modular, decentralized, and compliant with the latest Stacks (Nakamoto) standards.

The protocol aggregates yield from multiple sources (Lending, DEX, Stacking), provides institutional-grade features for asset management, and is hardened against common security threats like MEV exploitation.

## System Status

-   **Maturity Level**: 🔵 **Technical Alpha (Testnet)**
-   **Architectural Pattern**: Facade-Based & Trait-Driven
-   **Next Steps**: Comprehensive testing, third-party security audits, and preparation for mainnet.

## Core Architecture: The Facade Pattern

The Conxian Protocol is built on a **facade pattern**. This modern, modular architecture ensures security, maintainability, and clarity by separating concerns. Core contracts act as unified, secure entry points (**facades**) that route all user-facing calls to a network of specialized, single-responsibility **manager contracts**.

-   **User Interaction**: Users and external systems interact only with the facade contracts, which provide a simplified and secure API.
-   **Delegated Logic**: Facades contain minimal business logic. Their primary role is to validate inputs and delegate the actual work to the appropriate manager contract via `contract-call?`.
-   **Trait-Driven Interfaces**: The connections between facades and manager contracts are defined by a standardized set of traits located in the `/contracts/traits/` directory. This enforces a clean, consistent, and maintainable interface system across the entire protocol.

### 1. Core Module (`contracts/core/`)

The Core Module is the heart of the protocol's dimensional trading and risk management capabilities.

-   **`dimensional-engine.clar`**: The central **facade** for the Core Module. It routes all calls related to position management, collateral, and risk assessment to the specialized contracts below.
-   **Manager Contracts**:
    -   **Position Manager**: Handles the lifecycle of trading positions (open, close, modify).
    -   **Collateral Manager**: Manages the deposit, withdrawal, and accounting of user collateral.
    -   **Risk Manager**: Assesses position health and manages the liquidation process.
    -   **Funding Rate Calculator**: Calculates and applies funding rates to open positions.

### 2. DEX Module (`contracts/dex/`)

The DEX Module provides a highly efficient and capital-aware trading environment.

-   **`multi-hop-router-v3.clar`**: The **facade** for the DEX. It finds the optimal trading path and executes swaps across multiple liquidity pools, including 1-hop, 2-hop, and 3-hop routes.
-   **Manager Contracts**:
    -   **`concentrated-liquidity-pool.clar`**: Implements the concentrated liquidity AMM for maximum capital efficiency.
    -   **`dex-factory.clar`**: A factory contract for creating and managing liquidity pools.

### 3. Lending Module (`contracts/lending/`)

The Lending Module provides a fully collateralized and secure lending market.

-   **`comprehensive-lending-system.clar`**: The primary **facade** for the lending module. It manages user deposits, loans, and collateral, and delegates complex operations like liquidations to specialized contracts.
-   **Manager Contracts**:
    -   **`liquidation-manager.clar`**: A dedicated contract responsible for managing the liquidation process for under-collateralized loans, ensuring the solvency of the protocol.

### 4. Governance Module (`contracts/governance/`)

The Governance Module facilitates decentralized control over the protocol.

-   **`proposal-engine.clar`**: The **facade** for all governance-related actions, including proposal creation, voting, and execution.
-   **Manager Contracts**:
    -   **`conxian-operations-engine.clar`**: An automated "DAO Seat" that programmatically participates in governance by consuming on-chain metrics and casting policy-constrained votes.

## Modules

For more detailed information about each module's architecture and function, please refer to the `README.md` files in the `contracts` directory:

-   [Core Module](./contracts/core/README.md)
-   [DEX Module](./contracts/dex/README.md)
-   [Lending Module](./contracts/lending/README.md)
-   [Governance Module](./contracts/governance/README.md)
-   [Tokens Module](./contracts/tokens/README.md)
-   [Vaults Module](./contracts/vaults/README.md)
-   [Security Module](./contracts/security/README.md)
-   [Monitoring Module](./contracts/monitoring/README.md)

## Project Documentation

For a deeper understanding of the protocol's vision, architecture, and operational procedures, we recommend starting with these documents:

-   **[Strategic Overview](./documentation/STRATEGIC_OVERVIEW.md)**: Our vision, business goals, current status, and strategic roadmap.
-   **[Whitepaper](./documentation/whitepaper/Conxian-Whitepaper.md)**: The complete technical vision and protocol design.
-   **[Architecture Specification](./documentation/guides/ARCHITECTURE_SPEC.md)**: A high-level overview of the system design and module interactions.
-   **[Developer Guide](./documentation/developer/DEVELOPER_GUIDE.md)**: A comprehensive guide for developers.

## Development Setup

### Prerequisites

1.  Clarinet 2.0+
2.  Node.js 18+
3.  Git

### Installation

```bash
git clone https://github.com/anyachainlabs/Conxian.git
cd Conxian
npm install
```

### Testing

Run the comprehensive test suite:

```bash
npm test
```

**Advanced Testing Suites:**

-   **System End-to-End**: `npm run test:system`
-   **Performance Benchmark**: `npm run test:performance`
-   **Fuzz Testing**: `npm run test:fuzz`
-   **Security Audit**: `npm run test:security`

## Deployment

The protocol uses a staged deployment process managed by the `scripts/deploy-core.ts` script.

### Verified Principal Placeholders

When deploying to mainnet, ensure the following principals are used or replaced with your specific addresses:

| Role                      | Principal / Placeholder             | Notes                                  |
| ------------------------- | ----------------------------------- | -------------------------------------- |
| **Devnet Deployer**       | `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM` | Standard Clarinet Devnet Address       |
| **Mainnet Deployer**      | `SP1CONXIANPROTOCOLDEPLOYERADDRESS` | **ACTION REQUIRED**: Replace with your mainnet deployer address |
| **SIP-010 Trait**         | `SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE` | Standard Mainnet SIP-010 Trait Contract |
| **POX Contract**          | `SP000000000000000000002Q6VF78`     | Stacks Mainnet POX Contract            |

### Deployment Commands

**1. Devnet Deployment**

```bash
# Deploys to local Clarinet devnet
npm run deploy:core
```

**2. Mainnet Deployment**

Refer to `settings/Mainnet.toml` and ensure you have a valid deployer key.
