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

*   **Production Readiness**: 🟢 **READY (Core Components)**
*   **Security**: Hardened against common vectors (Slippage, Oracle Manipulation, Unauthorized Access).
*   **Performance**: Benchmarked at ~32ms per swap (Simulation).

## Architecture

The protocol is built on a modular architecture:

### 1. Core Layer

* `conxian-protocol.clar`: Main entry point and event coordinator.
* `conxian-token-factory.clar`: Manages token creation and standards compliance.
* `protocol-fee-switch.clar`: Centralized fee routing (Treasury, Staking, Insurance).

### 2. DEX Layer

* `concentrated-liquidity-pool.clar`: Advanced AMM with concentrated liquidity.
* `multi-hop-router-v3.clar`: Intelligent routing engine for optimal trade execution.
* `mev-protector.clar`: Transaction ordering and protection mechanism.

### 3. Lending Layer

* `comprehensive-lending-system.clar`: Main lending logic and pool management.
* `liquidation-manager.clar`: Automated liquidation engine for protocol solvency.

### 4. Governance

* `governance-token.clar`: CXG token for voting and protocol control.
* `proposal-engine.clar`: Management of protocol improvement proposals.

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
