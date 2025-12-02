# Conxian Protocol

[![Tests](https://img.shields.io/badge/Tests-Comprehensive-green)](https://github.com/Anya-org/Conxian)
[![Contracts](https://img.shields.io/badge/Contracts-292-blue)](https://github.com/Anya-org/Conxian)
[![Implementations](https://img.shields.io/badge/Implementations-207-blue)](https://github.com/Anya-org/Conxian)
[![Traits](https://img.shields.io/badge/Traits-15%20Modular%20Files-brightgreen)](https://github.com/Anya-org/Conxian/tree/main/contracts/traits)
[![Status](https://img.shields.io/badge/Status-In%20Development-yellow)](https://github.com/Anya-org/Conxian)
[![Network](https://img.shields.io/badge/Network-Nakamoto%20Active-green)](https://docs.hiro.so/)
[![Architecture](https://img.shields.io/badge/Architecture-Modular-blue)](https://github.com/Anya-org/Conxian)

## 🚀 A New Era of Decentralized Architecture

The Conxian Protocol has undergone a significant architectural overhaul to create a more modular, decentralized, and Nakamoto-compliant system. This new architecture is built on a foundation of specialized, single-responsibility contracts and a robust, modular trait system.

### Key Innovations

- **Modular by Design**: Protocol architecturally divided into specialized, single-responsibility contracts for security, maintainability, and reusability.
- **Official Stacks Trait System**: All contract interfaces defined in **15 modular trait files** following official Stacks SIP standards and best practices from major DeFi protocols (Uniswap V3, Alex, Arkadiko).
- **Nakamoto-Ready**: Architecture optimized for sub-second block times and Bitcoin finality of Stacks Nakamoto release.

## 📊 Current Status - NAKAMOTO READY (Updated Dec 02, 2025)

The Conxian Protocol has completed its major architectural refactoring and is now **Nakamoto-Ready**. The core modules (DEX, Governance, Lending) are architecturally feature-complete, wired into the modular trait system, and compatible with Stacks Epoch 3.0. As of Dec 2025, the global manifest is **syntactically clean** and critical compile blockers have been resolved. The focus is now on final verification, gas optimization for fast blocks, and mainnet deployment preparation.

### ✅ Major Achievements

- **Architectural Reorganization**: Repository restructured with clear separation of concerns between modules.
- **✅ Modular Trait System (COMPLETE)**: Implemented **15 modular trait files** following official Stacks standards:
  - `sip-standards`: SIP-010 FT, SIP-009 NFT (official Stacks SIPs).
  - `core-traits` & `core-protocol`: Ownable, Pausable, RBAC patterns, Upgradeable.
  - `defi-primitives` & `defi-traits`: Pool, Factory, Router, Vault interfaces.
  - `dimensional-traits`: Multi-dimensional position management.
  - `oracle-pricing`: Price feed and TWAP interfaces.
  - `risk-management`: Liquidation and risk assessment.
  - `cross-chain-traits`: Bridge and cross-chain interfaces.
  - `governance-traits`: Proposal and voting interfaces.
  - `security-monitoring`: Circuit breaker and monitoring.
  - `math-utilities`: Math library interfaces.
  - `trait-errors`: Standardized error codes.
- **Trait References**: All 84 contracts updated to use `.contract-name.trait-name` pattern per official Stacks documentation.
- **Modular Core Components**: DEX, Governance, and Lending modules built on single-responsibility contracts.
- **Enterprise & sBTC Frameworks**: Institutional integration and cross-chain sBTC functionality in place.

### 🔄 Current Status (Dec 02, 2025)

- **Network Alignment**: Fully aligned with **Stacks Nakamoto (Epoch 3.0)** and **Clarinet SDK 3.9.0**. Fast block tenure support is enabled.
- **Compilation Status**: Critical compile errors in Keeper Coordinator, Oracle Aggregator, Position Manager, and Lending System have been resolved. The system is in the final "Zero-Error Gate" verification phase.
- **Architecture Migration**: 100% complete; modules run on the new trait-driven architecture.
- **Next Immediate Steps**:
  - Complete final integration test pass.
  - Achieve a clean `clarinet check` on the full manifest.
  - Finalize gas optimizations for production.
- **Testing**: A comprehensive Vitest + Clarinet SDK framework is in place (see `TESTING_FRAMEWORK.md`).
- **Security Audit**: Scheduled post-verification.

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

### Latest Sprint Log (Docs)

- See `CHANGELOG.md` (Unreleased) for additive, append-only change tracking.

## Contributing

See `CONTRIBUTING.md` for contribution guidelines and policy checks.
