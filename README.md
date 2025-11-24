# Conxian Protocol

[![Tests](https://img.shields.io/badge/Tests-Comprehensive-green)](https://github.com/Anya-org/Conxian)
[![Contracts](https://img.shields.io/badge/Contracts-292-blue)](https://github.com/Anya-org/Conxian)
[![Implementations](https://img.shields.io/badge/Implementations-207-blue)](https://github.com/Anya-org/Conxian)
[![Traits](https://img.shields.io/badge/Traits-11%20Modular%20Files-brightgreen)](https://github.com/Anya-org/Conxian/tree/main/contracts/traits)
[![Status](https://img.shields.io/badge/Status-In%20Development-yellow)](https://github.com/Anya-org/Conxian)
[![Network](https://img.shields.io/badge/Network-Nakamoto-9cf)](https://docs.hiro.so/)
[![Architecture](https://img.shields.io/badge/Architecture-Modular-blue)](https://github.com/Anya-org/Conxian)

## 🚀 A New Era of Decentralized Architecture

The Conxian Protocol has undergone a significant architectural overhaul to create a more modular, decentralized, and Nakamoto-compliant system. This new architecture is built on a foundation of specialized, single-responsibility contracts and a robust, modular trait system.

### Key Innovations:
- **Modular by Design**: Protocol architecturally divided into specialized, single-responsibility contracts for security, maintainability, and reusability
- **Official Stacks Trait System**: All contract interfaces defined in **11 modular trait files** following official Stacks SIP standards and best practices from major DeFi protocols (Uniswap V3, Alex, Arkadiko)
- **Nakamoto-Ready**: Architecture optimized for sub-second block times and Bitcoin finality of Stacks Nakamoto release

## 📊 Current Status - IN DEVELOPMENT (Updated Nov 23, 2025)

The Conxian Protocol is currently undergoing a major architectural refactoring. While the core modules (DEX, Governance, Lending) are feature-complete, the protocol's trait system is in the process of being migrated to a new, modular architecture.

### ✅ Major Achievements
- **Architectural Reorganization**: Repository restructured with clear separation of concerns between modules
- **✅ Modular Trait System (COMPLETE)**: Implemented **11 modular trait files** following official Stacks standards:
  - `sip-standards` - SIP-010 FT, SIP-009 NFT (official Stacks SIPs)
  - `core-protocol` - Ownable, Pausable, RBAC patterns
  - `defi-primitives` - Pool, Factory, Router interfaces  
  - `dimensional-traits` - Multi-dimensional position management
  - `oracle-pricing` - Price feed and TWAP interfaces
  - `risk-management` - Liquidation and risk assessment
  - `cross-chain-traits` - Bridge and cross-chain interfaces
  - `governance-traits` - Proposal and voting interfaces
  - `security-monitoring` - Circuit breaker and monitoring
  - `math-utilities` - Math library interfaces
  - `trait-errors` - Standardized error codes
- **Trait References**: All 84 contracts updated to use `.contract-name.trait-name` pattern per official Stacks documentation
- **Modular Core Components**: DEX, Governance, and Lending modules built on single-responsibility contracts
- **Enterprise & sBTC Frameworks**: Institutional integration and cross-chain sBTC functionality in place

### 🔄 Current Status (Nov 24, 2025)
- **Compilation Errors**: 29 remaining (down from 31)
  - Contract resolution issues being addressed
  - Trait declaration cleanup in progress
  - Type safety improvements ongoing
- **Architecture Migration**: 90% complete
  - 25+ contracts updated to use standardized contract references
  - Dynamic contract calls eliminated
  - Modular trait system fully implemented
- **Next Immediate Steps**:
  - Complete trait declaration fixes (7 undeclared trait errors)
  - Resolve remaining contract resolution issues (4 contracts)
  - Fix type path mismatches in interest-rate-model and proposal-engine
- **Testing**: Framework ready, awaiting error-free compilation
- **Security Audit**: Planned after successful compilation

## Quick Start

- Install dependencies: `npm install`
- Run tests (Vitest + Clarinet SDK): `npm test`
- Check manifests: `clarinet check`

## Contract Modules

The Conxian protocol is organized into a series of specialized modules, each with a well-defined responsibility.

- **[Core Module](./contracts/core/README.md)**: The core logic of the dimensional engine, now decentralized into specialized components.
- **[DEX Module](./contracts/dex/README.md)**: Decentralized exchange functionality with a modular router and factory.
- **[Governance Module](./contracts/governance/README.md)**: A modular proposal and voting system.
- **[Lending Module](./contracts/lending/README.md)**: A feature-complete, multi-asset lending and borrowing system.
- **[Tokens Module](./contracts/tokens/README.md)**: A comprehensive token ecosystem.
- **[Vaults Module](./contracts/vaults/README.md)**: A decentralized sBTC vault.

## Documentation

All documentation for the Conxian Protocol can be found in the [`documentation`](./documentation) directory. The project's vision and future plans are outlined in the [`ROADMAP.md`](./ROADMAP.md) and the updated [`Conxian-Whitepaper.md`](./documentation/whitepaper/Conxian-Whitepaper.md).

## Contributing

See `CONTRIBUTING.md` for contribution guidelines and policy checks.
