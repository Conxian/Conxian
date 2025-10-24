# Conxian Protocol

[![Tests](https://img.shields.io/badge/Tests-Comprehensive-green)](https://github.com/Anya-org/Conxian)
[![Contracts](https://img.shields.io/badge/Contracts-65%2B-blue)](https://github.com/Anya-org/Conxian)
[![Status](https://img.shields.io/badge/Status-Core%20System%20Implemented-blue)](https://github.com/Anya-org/Conxian)
[![Network](https://img.shields.io/badge/Network-Testnet%2FMainnet-9cf)](https://docs.hiro.so/)

A comprehensive DeFi platform on Stacks featuring 65+ smart contracts with advanced mathematical libraries, lending & flash loan system framework, governance infrastructure, DEX components, and monitoring systems.

## Status

🔄 **Core Framework Implemented** – The core lending and DEX systems are implemented and near production quality. The repository also contains experimental and in-development contracts for advanced features like sBTC integration, which are not yet part of the deployable system.

[View Complete Status](./documentation/architecture/ARCHITECTURE.md)

## Development Setup

### Git Hooks

This repository includes pre-commit hooks to help prevent accidental commits of sensitive information. To set up the hooks:

1. Run the setup script:

   ```powershell
   .\setup-git-hooks.ps1
   ```

2. The pre-commit hook will now check for:
   - Private keys
   - Mnemonic phrases
   - AWS credentials
   - API keys

### System Account

The protocol uses a dedicated system account for privileged operations. The current system account details are:

- **Address**: `SP2ED6H1EHHTZA1NTWR2GKBMT0800Y6F081EEJ45R`
- **Public Key**: `0321397ade90f85e6d634bba310633f442cef6f9dae4df054c7a3a244e78192573`
- **Private Key**: (Stored in `.env` as `SYSTEM_PRIVKEY`)
- **Mnemonic**: (Stored in `.env` as `SYSTEM_MNEMONIC`)

### Security Notes

1. The system account should be secured with the highest level of protection.
2. For production, generate a new mnemonic and private key.
3. Never commit the actual private key or mnemonic to version control.
4. Consider using a hardware wallet for the production system account.

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
- **Liquidity Provider**: Unified liquidity provisioning for DEX integration.
- **Price Impact Calculator**: Calculates price impact for token swaps.

### 🏭 Position Management

- **Position Factory**: Manages the creation and tracking of user positions.

### 🛡️ Risk Framework

- **Insurance Fund**: Manages the protocol's insurance fund for risk mitigation.

### 🔗 Integration Points

- **Chainlink Adapter**: Adapts Chainlink oracle data for Clarity.
- **TWAP Oracle**: Provides Time-Weighted Average Price (TWAP) data.

### 🏦 Financial System Components

- **Risk Assessment Framework**: Basic borrower evaluation structures
- **Multi-asset Support**: Framework for cross-collateralization
- **Bond System**: Tokenized bond contracts with basic functionality
- **Yield Framework**: Structure for yield optimization strategies

[Complete Feature Documentation](./documentation/README.md)

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

**New to Conxian?** → [**User Manual**](./documentation/retail/USER_MANUAL.md) | [Quick Start Guide](./documentation/retail/QUICK_START.md)

### For Developers

#### Requirements

- Node.js (v18+)
- Clarinet CLI v3.7.0 (install locally or use `bin/clarinet`); CI installs on runners

Note: This repo uses Clarinet SDK v3.8.0. Local development can use `npx clarinet` or the Clarinet CLI; deployment uses the Clarinet binary in CI.

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

[Complete Setup Guide](./documentation/developer/DEVELOPER_GUIDE.md)

📚 **[Complete Documentation](./documentation/README.md)**

## 📚 Documentation (Updated September 23, 2025)

### 📖 Complete Documentation Hub

All documentation has been reorganized into a clear, structured system:

| Audience | Location | Description |
|----------|----------|-------------|
| **🛍️ Retail Users** | [`./documentation/retail/`](./documentation/retail/) | User guides and quick start |
| **🏢 Enterprise** | [`./documentation/enterprise/`](./documentation/enterprise/) | Guides for institutions |
| **👨‍💻 Developers** | [`./documentation/developer/`](./documentation/developer/) | Development setup and standards |
| **🏗️ Architecture** | [`./documentation/architecture/`](./documentation/architecture/) | System design and specifications |

**[📚 View Complete Documentation](./documentation/)**

### Quick Access

- [**Retail User Onboarding**](./documentation/retail/ONBOARDING.md) - Complete user guide
- [**Enterprise Onboarding**](./documentation/enterprise/ONBOARDING.md) - Technical guide for institutions
- [**Developer Guide**](./documentation/developer/DEVELOPER_GUIDE.md) - Development setup
- [**Dimensional System Architecture**](./documentation/architecture/DIMENSIONAL_SYSTEM.md) - System design

## License

MIT License

## Links

- **Repository**: [github.com/Anya-org/Conxian](https://github.com/Anya-org/Conxian)
- **Issues**: [Report bugs or request features](https://github.com/Anya-org/Conxian/issues)
- **Documentation**: [Complete documentation](./documentation/)

*Last updated: September 10, 2025. DeFi framework implemented with mathematical libraries and basic lending system structures.*
