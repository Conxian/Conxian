# Conxian Protocol

## Overview

Conxian is a sophisticated DeFi yield optimization protocol on Stacks, designed to automate and enhance returns from liquidity provision and yield farming. It introduces a dimensional architecture where yield sources (dimensions) are aggregated and optimized.

## Core Features

* **Dimensional Yield Engine**: Aggregates yield from multiple sources (Lending, DEX, Stacking).
* **Concentrated Liquidity**: Efficient capital usage with tick-based liquidity provision.
* **MEV Protection**: Built-in protection against front-running and sandwich attacks.
* **Enterprise Integration**: Institutional-grade features for large-scale asset management.
* **Automated Vaults**: Hands-off yield farming with auto-compounding strategies.

## System Status

*   **Production Readiness**: 🟡 **UNDER REVIEW**
*   **Security**: Hardened against common vectors (Slippage, Oracle Manipulation, Unauthorized Access).
*   **Performance**: Benchmarked at ~32ms per swap (Simulation).

## Architecture

The protocol is built on a modular architecture:

### 1. Core Layer

* **`dimensional-engine.clar`**: The central facade for the Core Module. It routes all calls to the specialized manager contracts, ensuring a single, secure entry point for position management, collateral handling, and risk assessment.
* **`conxian-protocol.clar`**: The main protocol coordinator, responsible for managing protocol-wide configurations, authorized contracts, and emergency controls.
* **`protocol-fee-switch.clar`**: A centralized switch for routing protocol fees to various destinations, such as the treasury, staking rewards, and insurance funds.

### 2. DEX Layer

* **`multi-hop-router-v3.clar`**: The central routing engine for the DEX. It supports 1-hop, 2-hop, and 3-hop swaps, allowing for efficient trading across multiple liquidity pools.
* **`concentrated-liquidity-pool.clar`**: Implements a concentrated liquidity AMM, allowing for greater capital efficiency.
* **`dex-factory.clar`**: A facade for creating and managing liquidity pools.

### 3. Lending Layer

* **`comprehensive-lending-system.clar`**: The main contract for the lending module. It manages user deposits, loans, and collateral, and integrates with other contracts to handle interest rates and liquidations.
* **`liquidation-manager.clar`**: A contract responsible for managing the liquidation process for under-collateralized loans.

### 4. Governance

* **`proposal-engine.clar`**: The core of the governance module, this contract acts as a facade for all governance-related actions.
* **`conxian-operations-engine.clar`**: An automated Operations & Resilience governance seat that reads metrics from core subsystems and casts policy-constrained votes.

### 5. Tokens

* **`cxd-token.clar`**: The primary token of the Conxian ecosystem, this contract implements the Conxian Revenue Token (CXD).
* **`token-system-coordinator.clar`**: A contract for coordinating the interactions between the various tokens in the ecosystem.

## Modules

For more detailed information about each module, please refer to the `README.md` files in the `contracts` directory:

* [Core Module](./contracts/core/README.md)
* [DEX Module](./contracts/dex/README.md)
* [Lending Module](./contracts/lending/README.md)
* [Governance Module](./contracts/governance/README.md)
* [Tokens Module](./contracts/tokens/README.md)

## Development Setup

### Prerequisites

1. Clarinet 2.0+
2. Node.js 18+
3. Git

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

*   **System End-to-End**: `npm run test:system`
*   **Performance Benchmark**: `npm run test:performance`
*   **Fuzz Testing**: `npm run test:fuzz`
*   **Security Audit**: `npm run test:security`

## Deployment

The protocol uses a staged deployment process managed by the `scripts/deploy-core.ts` script.

### Verified Principal Placeholders

When deploying to mainnet, ensure the following principals are used or replaced with your specific addresses:

| Role | Principal / Placeholder | Notes |
|------|------------------------|-------|
| **Devnet Deployer** | `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM` | Standard Clarinet Devnet Address |
| **Mainnet Deployer** | `SP1CONXIANPROTOCOLDEPLOYERADDRESS` | **ACTION REQUIRED**: Replace with your mainnet deployer address |
| **SIP-010 Trait** | `SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE` | Standard Mainnet SIP-010 Trait Contract |
| **POX Contract** | `SP000000000000000000002Q6VF78` | Stacks Mainnet POX Contract |

### Deployment Commands

**1. Devnet Deployment**

```bash
# Deploys to local Clarinet devnet
npm run deploy:core
```

**2. Mainnet Deployment**

Refer to `settings/Mainnet.toml` and ensure you have a valid deployer key.
