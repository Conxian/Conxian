# Conxian Protocol

[![Tests](https://img.shields.io/badge/Tests-Comprehensive-green)](https://github.com/Anya-org/Conxian)
[![Contracts](https://img.shields.io/badge/Contracts-292-blue)](https://github.com/Anya-org/Conxian)
[![Implementations](https://img.shields.io/badge/Implementations-207-blue)](https://github.com/Anya-org/Conxian)
[![Traits](https://img.shields.io/badge/Traits-85-orange)](https://github.com/Anya-org/Conxian)
[![Status](https://img.shields.io/badge/Status-In%20Development-yellow)](https://github.com/Anya-org/Conxian)
[![Network](https://img.shields.io/badge/Network-Nakamoto-9cf)](https://docs.hiro.so/)
[![Traits](https://img.shields.io/badge/Traits-Modular%20Architecture-orange)](https://github.com/Anya-org/Conxian)

## 🚀 A New Era of Decentralized Architecture

The Conxian Protocol has undergone a significant architectural overhaul to create a more modular, decentralized, and Nakamoto-compliant system. This new architecture is built on a foundation of specialized, single-responsibility contracts and a robust set of standardized traits.

### Key Innovations:
- **Modular by Design**: The protocol is now architecturally divided into specialized, single-responsibility contracts, enhancing security, maintainability, and reusability.
- **Trait-Driven Development**: A comprehensive set of standardized traits ensures that all components interact in a predictable and reliable manner.
- **Nakamoto-Ready**: The new architecture is optimized for the sub-second block times and Bitcoin finality of the Stacks Nakamoto release.

## 📊 Current Status - IN DEVELOPMENT (Updated Nov 22, 2025)

See [`DOCUMENTATION_VS_IMPLEMENTATION_REVIEW.md`](./DOCUMENTATION_VS_IMPLEMENTATION_REVIEW.md) for comprehensive gap analysis.

### ✅ Major Achievements
- **Phase 1 Foundation (90%)**: Core infrastructure including architectural refactoring of `core`, `dex`, and `governance` modules
- **292 Total Contracts**: 207 implementations + 85 trait definitions
- **Comprehensive Documentation**: 54+ documentation files with detailed technical specs
- **Enterprise Integration Framework**: Robust framework for institutional integration
- **Security Infrastructure**: Circuit breakers and MEV protection implemented
- **Cross-Chain sBTC Integration**: 9 sBTC-related contracts across modules
- **DLC Manager**: Trait and implementation contracts exist

### 🔄 Critical Next Steps (Deployment Blockers)
- **Fix Compilation Issues**: Resolve line ending errors in trait files (IN PROGRESS - Nov 22)
- **Complete Trait Migration**: Finish consolidation of 85 legacy traits → 10 modular modules
- **Verify Test Coverage**: Run full test suite and document actual coverage percentages
- **Expand BTC Adapter**: Enhance from stub (1.9KB) to production-ready finality verification
- **External Security Audit**: Required before mainnet deployment

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
