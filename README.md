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

### Key Innovations

- **Modular by Design**: Protocol architecturally divided into specialized, single-responsibility contracts for security, maintainability, and reusability
- **Official Stacks Trait System**: All contract interfaces defined in **11 modular trait files** following official Stacks SIP standards and best practices from major DeFi protocols (Uniswap V3, Alex, Arkadiko)
- **Nakamoto-Ready**: Architecture optimized for sub-second block times and Bitcoin finality of Stacks Nakamoto release

## 📊 Current Status - IN DEVELOPMENT (Updated Nov 27, 2025)

The Conxian Protocol is in the final stages of a major architectural refactoring. The core modules (DEX, Governance, Lending) are architecturally feature-complete and wired into the modular trait system. As of the latest `clarinet check` run (Nov 27, 2025), the global manifest is **syntactically clean (0 syntax errors)** but still has **20 semantic/trait/config errors** concentrated in risk, lending, enterprise, token, and MEV-helper contracts. Remaining work focuses on resolving these errors, tightening tests, and preparing for audit.

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

### 🔄 Current Status (Nov 27, 2025)

- **Compilation Status**: The global `Clarinet.toml` manifest is syntactically clean (0 syntax errors). `clarinet check` currently reports **20 remaining semantic/trait/config errors**, primarily in risk, lending, enterprise, token, and MEV-helper contracts. Most core DEX/governance/lending flows compile, but several supporting contracts still need alignment before any testnet or mainnet deployment.
- **Syntax vs Semantics**: All known Clarity syntax issues (parentheses, `match` wildcards, comment formatting, use of `=` vs `is-eq`) have been fixed across the repository. Remaining issues are **trait implementation and type/response mismatches, missing/undeclared trait parameters, and a small number of control-flow/type inconsistencies**.
- **Architecture Migration**: 90%+ complete; modules now run on the new trait-driven architecture, and dynamic contract calls have been removed or minimized.
- **Next Immediate Steps**:
  - Finish resolving remaining trait/semantic mismatches.
  - Achieve a clean `clarinet check` on the full manifest.
  - Expand Vitest coverage and dimensional integration tests.
- **Testing**: A comprehensive Vitest + Clarinet SDK framework and dimension-based test commands are in place (see `TESTING_FRAMEWORK.md`), but **coverage and pass rates are still being expanded** and are **not yet at target levels**.
- **Security Audit**: To be scheduled once compilation is clean and core tests are stable.

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
