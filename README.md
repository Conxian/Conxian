# Conxian Protocol

[![Tests](https://img.shields.io/badge/Tests-Comprehensive-green)](https://github.com/Anya-org/Conxian)
[![Contracts](https://img.shields.io/badge/Contracts-292-blue)](https://github.com/Anya-org/Conxian)
[![Implementations](https://img.shields.io/badge/Implementations-207-blue)](https://github.com/Anya-org/Conxian)
[![Traits](https://img.shields.io/badge/Traits-Migration%20In%20Progress-orange)](https://github.com/Anya-org/Conxian/tree/main/contracts/traits)
[![Status](https://img.shields.io/badge/Status-In%20Development-yellow)](https://github.com/Anya-org/Conxian)
[![Network](https://img.shields.io/badge/Network-Nakamoto-9cf)](https://docs.hiro.so/)
[![Architecture](https://img.shields.io/badge/Architecture-Modular-blue)](https://github.com/Anya-org/Conxian)

## 🚀 A New Era of Decentralized Architecture

The Conxian Protocol has undergone a significant architectural overhaul to create a more modular, decentralized, and Nakamoto-compliant system. This new architecture is built on a foundation of specialized, single-responsibility contracts and a robust, modular trait system.

### Key Innovations:
- **Modular by Design**: The protocol is architecturally divided into specialized, single-responsibility contracts, enhancing security, maintainability, and reusability.
- **Modular Trait System**: All contract interfaces are defined in a set of **10 modular trait files**, which are aggregated in a central registry. This provides a clear, consistent, and gas-efficient way for contracts to interact.
- **Nakamoto-Ready**: The new architecture is optimized for the sub-second block times and Bitcoin finality of the Stacks Nakamoto release.

## 📊 Current Status - IN DEVELOPMENT (Updated Nov 23, 2025)

The Conxian Protocol is currently undergoing a major architectural refactoring. While the core modules (DEX, Governance, Lending) are feature-complete, the protocol's trait system is in the process of being migrated to a new, modular architecture.

### ✅ Major Achievements
- **Architectural Reorganization**: The repository has been restructured for clarity and maintainability, with a clear separation of concerns between modules.
- **Modular Trait Architecture Design**: The design for a new, modular trait system has been finalized, consolidating the legacy system into **10 modular trait files**. The implementation of this migration is in progress.
- **Modular Core Components**: The DEX, Governance, and Lending modules are built on a foundation of modular, single-responsibility contracts.
- **Enterprise & sBTC Frameworks**: The foundational frameworks for institutional integration and cross-chain sBTC functionality are in place.

### 🔄 Critical Next Steps
- **Complete Trait Migration**: Refactor all smart contracts to import from the new **10 modular trait files** and remove the legacy, individual trait files.
- **Comprehensive Test Suite Audit**: Review and update the entire test suite to align with the new architecture and ensure adequate coverage.
- **External Security Audit**: Engage with a third-party security firm to conduct a full audit of the repository before mainnet deployment.
- **Expand BTC Adapter**: Enhance the `btc-adapter` from a stub to a production-ready component with full finality verification.

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
