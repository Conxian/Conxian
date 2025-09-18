# Conxian Protocol

[![Tests](https://img.shields.io/badge/Tests-Comprehensive-green)](https://github.com/Anya-org/Conxian)
[![Contracts](https://img.shields.io/badge/Contracts-65%2B-blue)](https://github.com/Anya-org/Conxian)
[![Status](https://img.shields.io/badge/Status-Core%20System%20Implemented-blue)](https://github.com/Anya-org/Conxian)
[![Network](https://img.shields.io/badge/Network-Testnet%2FMainnet-9cf)](https://docs.hiro.so/)

A comprehensive DeFi platform on Stacks featuring 65+ smart contracts with advanced mathematical libraries, lending & flash loan system framework, governance infrastructure, DEX components, and monitoring systems.

## Status

🔄 **Core Framework Implemented** – The core lending and DEX systems are implemented and near production quality. The repository also contains experimental and in-development contracts for advanced features like sBTC integration, which are not yet part of the deployable system.

[View Complete Status](./documentation/STATUS.md)

## 🚀 Features

### 💰 Lending & Flash Loan Framework

- **Loan Management Framework**: Contract structures for enterprise lending
- **Bond System Components**: Tokenized bond contracts and basic functionality
- **Yield Distribution Structure**: Framework for automated yield distribution
- **Flash Loan Implementation**: ERC-3156 compatible flash loans with reentrancy protection
- **Interest Rate Framework**: Dynamic rate calculation foundations
- **Liquidation System**: Basic liquidation mechanisms implemented

### 🔬 Mathematical Libraries (Implemented)

- **Newton-Raphson Algorithm**: Square root calculations with 18-decimal precision
- **Taylor Series Implementation**: Natural logarithm and exponential functions
- **Binary Exponentiation**: Power calculations for DeFi operations
- **Fixed-Point Math**: Precision mathematical operations for financial calculations

### 💹 Liquidity Infrastructure

- **Rebalancing Framework**: Structure for cross-pool optimization
- **DEX Components**: Basic pool and router implementations
- **Capital Management**: Framework for efficient capital allocation
- **Security Controls**: Circuit breakers and emergency mechanisms

### 🏦 Financial System Components

- **Risk Assessment Framework**: Basic borrower evaluation structures
- **Multi-asset Support**: Framework for cross-collateralization
- **Bond System**: Tokenized bond contracts with basic functionality
- **Yield Framework**: Structure for yield optimization strategies

[Complete Feature Documentation](./documentation/)

## 🚀 Deployment

### Prerequisites

1. Install [Clarinet](https://docs.hiro.so/smart-contracts/clarinet)
2. Set up your Stacks wallet with testnet STX (for testnet deployment)
3. Set environment variables for sensitive information

### Testnet Deployment

1. Configure your testnet settings in `deployments/staging-config.yaml`
2. Deploy to testnet:
   ```bash
   clarinet deployment apply -n testnet
   ```
3. Verify deployment:
   ```bash
   clarinet deployment list -n testnet
   ```

### Mainnet Deployment

1. Update production settings in `deployments/production-config.yaml`
2. Set required environment variables:
   ```bash
   export DEPLOYER_MNEMONIC="your-mnemonic-here"
   export GOVERNANCE_ADDRESS="your-governance-address"
   ```
3. Deploy to mainnet:
   ```bash
   clarinet deployment apply -n mainnet
   ```
4. Verify deployment:
   ```bash
   clarinet deployment list -n mainnet
   ```

## 🔧 Development

### Testing

Run the test suite:
```bash
clarinet test
```

### Environment Setup

1. Copy `.env.example` to `.env`
2. Update environment variables as needed
3. Run tests with:
   ```bash
   source .env && clarinet test
   ```

## Core Principles

- **Security-First & Bitcoin-Aligned**: Every contract is designed with the highest level of security and certainty in mind, reflecting the robustness expected from a Bitcoin-aligned system.
- **High-Value Asset Management**: The platform is built as a financial-grade system for high-value assets, ensuring all logic is sound, transparent, and aligns with best practices in asset management.
- **Code-Rooted Financial Engineering**: All complex financial logic is implemented directly and transparently on-chain in Clarity, ensuring the system's core value is derived from verifiable code, not off-chain processes.

## Quick Start

### For Users

**New to Conxian?** → [**User Manual**](./documentation/USER_MANUAL.md) | [Quick Start Guide](./documentation/QUICK_START.md)

### For Developers

#### Requirements

- Node.js (v18+)
- Clarinet CLI v3.5.0 (install locally or use `bin/clarinet`); CI installs on runners

Note: This repo uses Clarinet SDK v3.5.0. Local development can use `npx clarinet` or the Clarinet CLI; deployment uses the Clarinet binary in CI.

#### Setup

```bash
git clone https://github.com/Anya-org/Conxian.git
cd Conxian
# Install deps and validate docs
npm ci
npm run validate:docs
# Run tests
npx vitest run
```

This will:

1. Install all dependencies.
1. Validate docs and naming (`scripts/validate-docs.js`).
1. Run all TypeScript tests (`npx vitest run`).

Expected output:

- ✅ 65+ contracts validated for syntax and basic functionality
- ✅ Mathematical libraries: sqrt, pow, ln, exp functions implemented
- ✅ Flash loan framework: ERC-3156 compatible structure
- ✅ Lending protocol: Basic supply, borrow, liquidation framework
- 🔄 Test coverage for core functionality (comprehensive testing needed)

#### Deploy

**GitHub Actions (Recommended)**:

```bash
# Testnet deployment (dry run)
gh workflow run deploy-testnet.yml --field dry_run=true

# Testnet deployment (live)
gh workflow run deploy-testnet.yml --field dry_run=false
```

**Local Testing**:

```bash
# Generate deployment plan
clarinet deployments generate --testnet

# Local validation
bash scripts/deploy-testnet.sh
```

[Complete Setup Guide](./documentation/DEVELOPER_GUIDE.md)

📚 **[Complete Architecture Documentation](./documentation/)**

## Documentation (Updated Sep 06, 2025)

### For Users

| Guide | Description |
|-------|-------------|
| [**User Manual**](./documentation/USER_MANUAL.md) | **Complete user guide and onboarding** |
| [Quick Start](./documentation/QUICK_START.md) | 5-minute getting started guide |

### For Developers & Stakeholders

| Topic | Description |
|-------|-------------|
| [Architecture](./documentation/ARCHITECTURE.md) | System design (incl. DEX, breaker, monitoring) |
| [Tokenomics](./documentation/TOKENOMICS.md) | Economic model and token mechanics |
| [Security](./documentation/SECURITY.md) | Security features and audit information |
| [API Reference](./documentation/API_REFERENCE.md) | Smart contract functions |
| [Deployment](./documentation/DEPLOYMENT.md) | Production deployment guide |
| [Developer Guide](./documentation/DEVELOPER_GUIDE.md) | Development setup and contributing |
| [Status](./documentation/STATUS.md) | Current contract & test inventory |

[View All Documentation](./documentation/)

## License

MIT License

## Links

- **Repository**: [github.com/Anya-org/Conxian](https://github.com/Anya-org/Conxian)
- **Issues**: [Report bugs or request features](https://github.com/Anya-org/Conxian/issues)
- **Documentation**: [Complete documentation](./documentation/)

*Last updated: September 10, 2025. DeFi framework implemented with mathematical libraries and basic lending system structures.*
