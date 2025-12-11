# Conxian Protocol

## Overview

Conxian is a sophisticated DeFi yield optimization protocol on Stacks,
designed to automate and enhance returns from liquidity provision and yield farming.
It introduces a dimensional architecture where yield sources (dimensions) are
aggregated and optimized.

## Core Features

* **Dimensional Yield Engine**: Aggregates yield from multiple sources
  (Lending, DEX, Stacking).
* **Concentrated Liquidity**: Efficient capital usage with tick-based liquidity provision.
* **MEV Protection**: Built-in protection against front-running and sandwich attacks.
* **Enterprise Integration**: Institutional-grade features for
  large-scale asset management.
* **Automated Vaults**: Hands-off yield farming with auto-compounding strategies.

## Architecture

The protocol is built on a modular architecture:

### 1. Core Layer

* `conxian-protocol.clar`: Main entry point and event coordinator.
* `conxian-token-factory.clar`: Manages token creation and standards compliance.

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

Or run specific test dimensions:

```bash
npm run test:dex-dimension
npm run test:lending-dimension
```

## Deployment

The protocol uses a staged deployment process:

1. **Devnet**: Local testing and validation.
2. **Testnet**: Public testing on Stacks testnet.
3. **Mainnet**: Production deployment.

See `deployment/` directory for detailed guides.

## Documentation

Full documentation is available in the `documentation/` directory.

* [Architecture Guide](documentation/architecture/ARCHITECTURE.md)
* [Developer Guide](documentation/developer/DEVELOPER_GUIDE.md)
* [User Guide](documentation/retail/USER_GUIDE.md)

## System Status & Reviews

* **[Comprehensive System Review (Dec 2025)](documentation/reports/SYSTEM_REVIEW_AND_ALIGNMENT.md)**: Detailed analysis of architecture, gaps, and roadmap.

