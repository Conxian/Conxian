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

See [`documentation/project-management/STATUS.md`](./documentation/project-management/STATUS.md) for a detailed breakdown of the project's current status.

### ✅ Major Achievements
- **Phase 1 Foundation Completed**: The core infrastructure of the protocol has been completed, including the architectural refactoring of the `core`, `dex`, `sbtc-vaults`, and `governance` modules.
- **Comprehensive Documentation**: All new and modified contracts have been thoroughly documented with high-quality docstrings, and a comprehensive set of user guides has been created.
- **Enterprise Integration Framework**: A robust framework for enterprise and institutional integration has been established.
- **Security Infrastructure**: The protocol's security has been enhanced with the implementation of circuit breakers and MEV protection.
- **Cross-Chain sBTC Integration**: The protocol has been successfully integrated with the sBTC cross-chain bridge.

### 🔄 Next Steps
- **Complete Phase 2 Token Economics**: The token economics implementation will be completed, including the token emission controller enhancements.
- **Finalize Cross-Chain Integrations**: The cross-chain integrations will be finalized, including the implementation of Wormhole message validation and the completion of cross-chain asset transfers.
- **Update Contract Documentation**: The accuracy of the contract documentation will be improved, and any misalignments with the actual implementation will be corrected.
- **Enhance Test Coverage**: The test coverage for newer contracts will be enhanced to ensure that all new features are thoroughly tested.

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
