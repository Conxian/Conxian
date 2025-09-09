# Conxian

[![Tests](https://img.shields.io/badge/Tests-Comprehensive-green)](https://github.com/Anya-org/Conxian)
[![Contracts](https://img.shields.io/badge/Contracts-34%20Core%20%2B%2010%20Lending-blue)](https://github.com/Anya-org/Conxian)
[![Deployment](https://img.shields.io/badge/Deployment-Ready-green)](https://github.com/Anya-org/Conxian)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive DeFi platform on Stacks featuring advanced mathematical libraries, complete lending & flash loan system, automated governance, DEX infrastructure, and enterprise-grade monitoring.

## Status

✅ **Production Ready** – Complete system with 34 core contracts + 10 comprehensive lending contracts, advanced mathematical libraries (sqrt, pow, ln, exp), full flash loan implementation, and extensive test coverage.

[View Complete Status](./documentation/STATUS.md)

## 🚀 Features

### 💰 Comprehensive Lending & Flash Loan System

- **Enterprise Loan Manager**: Institution-grade loans with risk-based pricing
- **Bond Issuance System**: Tokenized bonds backing large enterprise loans  
- **Yield Distribution Engine**: Automated yield distribution to bond holders
- **Flash Loan Vault**: ERC-3156 compatible flash loans with reentrancy protection
- **Interest Rate Models**: Dynamic rates based on utilization and risk
- **Automated Liquidations**: Smart liquidation system with grace periods

### 🔬 Advanced Mathematical Libraries

- **Newton-Raphson Algorithm**: Precise square root calculations
- **Taylor Series Implementation**: Natural logarithm and exponential functions
- **Binary Exponentiation**: Efficient power calculations
- **18-decimal Precision**: Enterprise-grade mathematical accuracy

### 💹 Liquidity Optimization Engine

- **Automated Rebalancing**: Cross-pool liquidity optimization
- **Arbitrage Detection**: Real-time opportunity scanning
- **Capital Efficiency**: Maximum yield with minimal risk
- **Emergency Controls**: Circuit breakers and emergency reserves

### 🏦 Enterprise Financial Features

- **Credit Rating System**: Borrower risk assessment and scoring
- **Multi-asset Collateral**: Cross-collateralization support
- **Institutional Bonds**: Large loan backing via tokenized bonds
- **Yield Farming Integration**: Collateral yield optimization

[Complete Feature Documentation](./documentation/)

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

- ✅ 44 contracts checked (34 core + 10 lending system)
- ✅ Mathematical libraries: sqrt, pow, ln, exp functions
- ✅ Flash loan system: ERC-3156 compatible implementation
- ✅ Lending protocol: Supply, borrow, liquidation capabilities
- ✅ Comprehensive test coverage with integration validation

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

*Last updated: September 9, 2025. Comprehensive lending system implemented with advanced mathematical libraries.*
