# Conxian

[![Tests](https://img.shields.io/badge/Tests-50%20Passing-yellow)](https://github.com/Anya-org/Conxian)
[![Contracts](https://img.shields.io/badge/Contracts-44%20Compiled-blue)](https://github.com/Anya-org/Conxian)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-ready DeFi platform on Stacks with enhanced tokenomics, automated DAO governance, DEX subsystem groundwork, circuit breaker & enterprise monitoring, and Bitcoin-aligned principles.

## Status

⚠️ **Partial System Health** – 44 contracts compile successfully with 50 TypeScript tests passing. Clarity tests are currently unable to run due to a test environment issue.

[View Complete Status](./documentation/STATUS.md)

## Features

- **Enhanced Tokenomics**: 100M CXVG governance token, 50M CXLP liquidity token with progressive migration & revenue sharing
- **Automated DAO**: Time-weighted voting, timelock, automation & buybacks
- **DEX Foundations**: Factory, pool, router, math-lib, multi-hop & pool variants (design + partial impl)
- **Circuit Breaker & Monitoring**: Structured numeric event codes for volatility, volume & liquidity safeguards
- **Creator Economy**: Merit & automation-driven bounty systems
- **Security & Precision**: Multi-sig treasury, emergency pause, precision math, enterprise monitoring

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
  
Note: This repo pins Clarinet SDK v3.5.0 via npm. Always use `npx clarinet`.

#### Setup

```bash
git clone https://github.com/Anya-org/Conxian.git
cd Conxian
npm run ci
```

This will:
1.  Install all dependencies.
2.  Run the Clarity contract checker (`npx clarinet check`).
3.  Run all TypeScript tests (`npx vitest run`).

Expected output:
- ✅ 44 contracts checked
- ✅ 50 tests passed (TypeScript)
- ⚠️ Clarity tests currently failing to run

#### Deploy

```bash
# Testnet
../scripts/deploy-testnet.sh

# Production  
../scripts/deploy-mainnet.sh
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

*Counts reflect repository state as of Aug 26, 2025.*
