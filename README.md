# Conxian Protocol

[![Tests](https://img.shields.io/badge/Tests-Comprehensive-green)](https://github.com/Anya-org/Conxian)
[![Contracts](https://img.shields.io/badge/Contracts-255%2B-blue)](https://github.com/Anya-org/Conxian)
[![Status](https://img.shields.io/badge/Status-In%20Development-yellow)](https://github.com/Anya-org/Conxian)
[![Network](https://img.shields.io/badge/Network-Nakamoto-9cf)](https://docs.hiro.so/)
[![Traits](https://img.shields.io/badge/Traits-Modular%20Architecture-orange)](https://github.com/Anya-org/Conxian)

## 🚀 A New Era of Decentralized Architecture

The Conxian Protocol has undergone a significant architectural overhaul to create a more modular, decentralized, and Nakamoto-compliant system. This new architecture is built on a foundation of specialized, single-responsibility contracts and a robust set of standardized traits.

### Key Innovations:
- **Modular by Design**: The protocol is now architecturally divided into specialized, single-responsibility contracts, enhancing security, maintainability, and reusability.
- **Trait-Driven Development**: A comprehensive set of standardized traits ensures that all components interact in a predictable and reliable manner.
- **Nakamoto-Ready**: The new architecture is optimized for the sub-second block times and Bitcoin finality of the Stacks Nakamoto release.

## 📊 Current Status - IN DEVELOPMENT

### ✅ Major Achievements
- **Architectural Refactoring**: The `core`, `dex`, `sbtc-vaults`, and `governance` modules have been successfully refactored into a more modular and decentralized architecture.
- **Comprehensive Documentation**: All new and modified contracts have been thoroughly documented with high-quality docstrings.
- **Clear Roadmap**: A detailed roadmap has been created to guide future development.
- **Updated Whitepaper**: The project whitepaper has been updated to reflect the new architecture and vision.

### 🔄 Next Steps
- **Lending Module Implementation**: The core lending functionality will be implemented from scratch, following the new modular architecture.
- **Tokenomics and Governance Enhancement**: The tokenomics infrastructure and governance module will be completed.
- **Dimensional Finance and Cross-Chain Integration**: The protocol's capabilities will be expanded with advanced DeFi and cross-chain features.

## Quick Start

- Install dependencies: `npm install`
- Run tests (Vitest + Clarinet SDK): `npm test`
- Check manifests: `clarinet check`

## Contract Modules

The Conxian protocol is organized into a series of specialized modules, each with a well-defined responsibility.

- **[Core Module](./contracts/core/README.md)**: The core logic of the dimensional engine, now decentralized into specialized components.
- **[DEX Module](./contracts/dex/README.md)**: Decentralized exchange functionality with a modular router and factory.
- **[Governance Module](./contracts/governance/README.md)**: A modular proposal and voting system.
- **[Lending Module](./contracts/lending/README.md)**: Multi-asset lending and borrowing (under development).
- **[Tokens Module](./contracts/tokens/README.md)**: A comprehensive token ecosystem.
- **[Vaults Module](./contracts/vaults/README.md)**: A decentralized sBTC vault.

## Documentation

All documentation for the Conxian Protocol can be found in the [`documentation`](./documentation) directory. The project's vision and future plans are outlined in the [`ROADMAP.md`](./ROADMAP.md) and the updated [`Conxian-Whitepaper.md`](./documentation/whitepaper/Conxian-Whitepaper.md).

## Contributing

See `CONTRIBUTING.md` for contribution guidelines and policy checks.
