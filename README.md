# Conxian Protocol

[![Status](https://img.shields.io/badge/Status-Under_Review-orange)](https://github.com/Anya-org/Conxian)
[![Contracts](https://img.shields.io/badge/Contracts-100+-blue)](https://github.com/Anya-org/Conxian)
[![Network](https://img.shields.io/badge/Network-Nakamoto_Ready-green)](https://docs.hiro.so/)

## 🚀 A Multi-Dimensional DeFi Protocol on Stacks

The Conxian Protocol is a comprehensive DeFi protocol built on the Stacks blockchain, designed to be fully compatible with the Nakamoto release. It features a modular architecture that separates concerns into specialized smart contracts for security, scalability, and maintainability.

### Key Features

- **Modular by Design**: The protocol is architecturally divided into specialized, single-responsibility contracts.
- **Nakamoto-Ready**: The architecture is optimized for the sub-second block times and Bitcoin finality of the Stacks Nakamoto release.
- **Core DeFi Primitives**:
  - **Concentrated Liquidity**: A DEX with tick-based pools for capital efficiency.
  - **Multi-Hop Routing**: An advanced router for finding optimal trading paths.
  - **Lending Market**: A comprehensive system for supplying, borrowing, and liquidating assets.
  - **Decentralized Governance**: A proposal and voting system for protocol management.

## 📊 Current Status - Under Review

The Conxian Protocol is currently undergoing a **Critical Stabilization & Safety Review**. While the architectural foundation is strong, the codebase is **NOT currently production-ready**. Several key components, such as the lending market's health factor calculation, are not fully implemented, and the protocol has not yet undergone a formal security audit.

**⚠️ WARNING: Do not attempt to deploy this code to Mainnet.**

### ✅ Achievements

- **Modular Architecture**: The repository has been successfully restructured into a clear, module-based system.
- **Core Functionality Implemented**: The foundational contracts for the DEX, governance, and lending modules are in place.

## Quick Start

- Install dependencies: `npm install`
- Run tests (Vitest + Clarinet SDK): `npm test`
- Check manifests: `clarinet check`

## Contract Modules

The Conxian protocol is organized into a series of specialized modules, each with its own detailed `README.md`:

- **[Core](./contracts/core/README.md)**: The central dimensional engine and protocol-wide administrative controls.
- **[DEX](./contracts/dex/README.md)**: A concentrated liquidity AMM with a multi-hop router.
- **[Governance](./contracts/governance/README.md)**: The proposal and voting system for decentralized decision-making.
- **[Lending](./contracts/lending/README.md)**: A multi-asset lending market with a liquidation manager.
- **[Tokens](./contracts/tokens/README.md)**: The ecosystem of SIP-010 fungible tokens.
- **[Vaults](./contracts/vaults/README.md)**: Asset management vaults, including a dedicated sBTC vault.
- **[Security](./contracts/security/README.md)**: A suite of contracts for risk management, including circuit breakers and access control.

## Documentation

- **[Whitepaper](./documentation/whitepaper/Conxian-Whitepaper.md)**: The full technical vision and architecture of the protocol.
- **[Roadmap](./ROADMAP.md)**: The development phases and status tracking.
- **[Documentation Hub](./documentation/README.md)**: A central hub for all project documentation.

## Contributing

See `CONTRIBUTING.md` for contribution guidelines and policy checks.
