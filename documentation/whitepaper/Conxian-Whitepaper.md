# Conxian Protocol — A Multi‑Dimensional DeFi System on Stacks (Nakamoto)

Version: 1.1 (Updated November 2025)
Status: In Development (Architectural Refactoring in Progress)

## Abstract

Conxian is a comprehensive Bitcoin‑anchored, multi‑dimensional DeFi protocol deployed on Stacks (Nakamoto). The protocol is undergoing a significant architectural refactoring to create a more modular, decentralized, and Nakamoto-compliant system. This new architecture unifies concentrated liquidity pools, advanced Dijkstra routing, multi-source oracle aggregation, enterprise-grade lending, comprehensive MEV protection, and real-time monitoring analytics into a cohesive and extensible ecosystem.

The system is architecturally divided into specialized, single-responsibility contracts, governed by a robust set of standardized traits. This modular design enhances security, maintainability, and future extensibility, ensuring that the Conxian protocol remains at the forefront of decentralized finance.

## 1. Motivation

- **Fragmented liquidity** across isolated DEXes prevents efficient capital utilization
- **Monolithic architectures** create complexity, hinder modularity, and increase security risks.
- **MEV exploitation** drains liquidity providers without adequate protection mechanisms
- **Cross-chain complexity** requires unified settlement with Bitcoin finality guarantees
- **Institutional adoption** demands enterprise compliance without compromising retail accessibility
- **Monitoring gaps** leave protocols vulnerable to manipulation and operational failures

Conxian addresses these challenges by delivering a unified, deterministic, and auditable DeFi platform where Bitcoin finality, multi-dimensional risk management, and institutional-grade controls are built upon a foundation of modular, decentralized contracts.

## 2. Design Principles

- **Modularity and Decentralization**: The protocol is architecturally designed to be highly modular, with each component encapsulated in its own contract. This separation of concerns improves security, maintainability, and reusability.
- **Trait-Driven Development**: A comprehensive set of standardized traits ensures that all components interact in a predictable and reliable manner.
- **Determinism by construction**: Centralized trait imports/implementations, canonical encoding, and deterministic token ordering ensure predictable behavior.
- **Bitcoin finality & Nakamoto integration**: The protocol leverages the security and finality of the Bitcoin blockchain through the Stacks Nakamoto release.
- **Safety‑first defaults**: Pausable guards, circuit-breakers, and explicit error codes are used throughout the system to protect against unforeseen events.
- **Compliance without compromise**: Modular enterprise controls allow for institutional adoption without compromising the permissionless nature of the retail-facing components.

## 3. System Architecture Overview

The Conxian protocol is organized into a series of specialized modules, each with a well-defined responsibility. This modular architecture is a key feature of the re-architected system.

### Module Architecture

#### Core DEX Infrastructure
- **Decentralized Routing & Swaps**: The `multi-hop-router-v3` has been refactored into a facade that delegates to specialized contracts for pathfinding (`dijkstra-pathfinder`) and route management (`route-manager`).
- **Modular Pool Management**: The `dex-factory` has been decentralized into a facade that interacts with specialized registries for pool types (`pool-type-registry`), implementations (`pool-implementation-registry`), and pool data (`pool-registry`).

#### Governance & Security
- **Modular Governance**: The `proposal-engine` has been refactored into a facade that delegates to a `proposal-registry` for data storage and a `voting` contract for vote management.
- **MEV Protection**: The protocol will include a dedicated MEV protection layer with commit-reveal schemes and batch auctions.

#### sBTC Vaults
- **Decentralized Vault**: The monolithic `sbtc-vault` has been broken down into four specialized contracts: `custody` for deposits and withdrawals, `yield-aggregator` for yield strategies, `btc-bridge` for wrapping/unwrapping, and `fee-manager` for fee handling.

#### Lending & Borrowing
- **Modular Lending**: The lending module is being built from the ground up with a modular architecture, including a `lending-pool-core` for central logic, a user-facing `lending-pool`, and a `lending-pool-rewards` contract.
- **Dimensional Vault**: The `dimensional-vault` has been refactored to use a separate `interest-rate-model` contract.

#### Token Economics
- **Comprehensive Token System**: The protocol features a comprehensive token system with a primary token (CXD), a treasury token (CXTR), a liquidity provider token (CXLP), a governance token (CXVG), and a stability token (CXS).

## 4. Roadmap & Implementation Status

The Conxian Protocol is currently undergoing a significant architectural refactoring. The following provides a high-level overview of the work completed and the roadmap for future development. For a more detailed breakdown, please refer to the `ROADMAP.md` file in the root directory.

### Completed Work
- **Architectural Refactoring**: The `core`, `dex`, `sbtc-vaults`, and `governance` modules have been successfully refactored into a more modular and decentralized architecture.
- **Comprehensive Documentation**: All new and modified contracts have been thoroughly documented with high-quality docstrings.

### Future Work
- **Lending Module Implementation**: The core lending functionality will be implemented from scratch, following the new modular architecture.
- **Tokenomics and Governance Enhancement**: The tokenomics infrastructure and governance module will be completed.
- **Dimensional Finance and Cross-Chain Integration**: The protocol's capabilities will be expanded with advanced DeFi and cross-chain features.
- **Community and Ecosystem Growth**: A grant program, hackathons, and user incentive programs will be established to grow the Conxian community.

## 5. Conclusion

The Conxian Protocol is poised to become a leading DeFi ecosystem on the Stacks blockchain. By embracing a modular, decentralized architecture, we are building a protocol that is secure, maintainable, and extensible. We are confident that this new architecture will enable us to deliver on our vision of a comprehensive, multi-dimensional DeFi system.
