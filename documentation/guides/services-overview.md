# Conxian Services & Unique Positioning

## Who this guide is for

This guide is written for protocol users, partners, and stakeholders who want a high-level view of **what Conxian offers** and **how it is different** from other DeFi platforms. It complements the technical whitepaper and architecture documents by focusing on services and market positioning rather than low-level implementation details.

---

## Core Protocol Services

### 1. Decentralized Exchange (DEX & Liquidity)

Conxian provides a modular DEX layer designed for **Bitcoin-secured DeFi on Stacks**:

- **Spot trading & liquidity pools** for key asset pairs (e.g. sBTC, stablecoins, protocol tokens)
- Architecture informed by leading designs such as **Uniswap V3**, **Alex**, and **Arkadiko**, adapted to the Conxian trait system
- Built to plug into the broader risk, oracle, and vault infrastructure

### 2. Dimensional Lending & Leverage

The lending layer is designed around a **dimensional engine** that can reason about collateral, risk, and strategy dimensions:

- **Over-collateralized lending** and borrowing on top of Bitcoin-secured assets
- Integration with **risk-manager** and **liquidation-engine** contracts for disciplined margin and liquidation logic
- Hooks into **oracle-aggregator-v2** for price and TWAP-like data

### 3. Yield & Protection NFTs

Conxian uses specialized NFTs as wrappers for yield and protection strategies:

- **Staking Yield NFT** – represents staked positions and associated reward flows
- **MEV-Protection NFT** – captures MEV-protection parameters and commitments
- **Insurance Protection NFT** – represents insurance coverage and proof-of-insurance state

These NFTs allow:

- Clear on-chain representation of rights and risk exposures
- Composable integration with marketplaces, vaults, and governance

### 4. Vaults & Yield Aggregation

The vault layer is designed to coordinate capital across strategies:

- **sBTC Vaults** – Bitcoin-secured vaults for structured strategies
- **Yield Aggregator** – aggregates yield opportunities across supported strategies and dimensions

The goal is to provide **configurable yield profiles** that can be tuned for different risk/return preferences.

### 5. Oracle & Risk Infrastructure

Reliable pricing and risk management are core to Conxian:

- **Oracle Aggregator v2**
  - Aggregates price data from multiple oracle sources
  - Provides helper logic for observation lookups and TWAP-style access patterns
- **Risk Manager & Liquidation Engine**
  - Centralizes risk assessment for positions
  - Coordinates liquidations with dimensional and oracle inputs

This infrastructure is designed to be **modular** so additional oracle sources and risk models can be integrated over time.

### 6. Cross-Chain & Interoperability

Conxian includes cross-chain building blocks such as **bridge NFTs**:

- Encodes cross-chain transfer metadata in NFTs
- Provides a pattern for representing cross-chain movements and state
- Aligns with the broader goal of **Bitcoin-first, multi-chain-aware** DeFi

### 7. Monitoring, Circuit Breakers & Governance

Operational safety and observability are first-class concerns:

- **System Monitor** – tracks key protocol events and state for monitoring
- **Enhanced Circuit Breaker** – allows controlled pauses or restrictions under abnormal conditions
- **Governance Modules** – support DAO-style configuration and parameter management

---

## What Makes Conxian Different

### 1. Trait-First Modular Architecture (15 Trait Files)
 
 Conxian is built around **15 modular trait files** that define protocol interfaces:

- Clear separation between **interfaces** (traits) and **implementations** (contracts)
- Easier auditing and reasoning about what each contract is allowed to do
- Improved upgrade paths and modularity as the protocol evolves

### 2. Nakamoto-Ready & Bitcoin-Native Orientation

The architecture is optimized for the **Stacks Nakamoto release**:

- Designed for **sub-second block times** and **Bitcoin finality**
- Focus on **Bitcoin-secured DeFi** rather than isolated, non-Bitcoin chains

### 3. Compliance-Aware Design (FSCA / IFWG Context)

While full regulatory analysis is handled off-chain, the on-chain architecture is:

- Structured to support **clear accounting of positions, risk, and flows**
- Designed so that audits and compliance reviews can trace **who holds what risk and why**
- Built with the intention of aligning to South African **FSCA / IFWG** guidance as the framework matures

### 4. Composability Across Services

All core services—DEX, lending, vaults, NFTs, oracles, risk, and monitoring—are designed to:

- **Compose via shared traits and interfaces**
- Allow higher-level products (e.g., structured vaults, institutional mandates) to be built by combining existing primitives

---

## Example Use Cases

- **Retail & Pro Users**
  - Trade assets on the DEX with clear visibility into risk and liquidity
  - Participate in yield strategies via staking and vault products

- **Institutional & Corporate Treasuries**
  - Deploy Bitcoin and stablecoin treasuries into **risk-constrained yield strategies**
  - Use Conxian’s monitoring and circuit-breaker frameworks as part of internal risk controls

- **Builders & Integrators**
  - Build new products on top of Conxian’s traits and contracts
  - Integrate external strategies, oracles, or monitoring systems via the modular trait system

---

## Where to Learn More

- **Project Overview & Status** – see the root [`README.md`](../../README.md)
- **Architecture & Design** – [`architecture/ARCHITECTURE.md`](../architecture/ARCHITECTURE.md)
- **Technical Whitepaper** – [`whitepaper/Conxian-Whitepaper.md`](../whitepaper/Conxian-Whitepaper.md)
- **Roadmap & Phased Goals** – root [`ROADMAP.md`](../../ROADMAP.md)
- **Operational Guides** –
  - [`guides/liquidation-flow.md`](./liquidation-flow.md)
  - [`guides/oracle-integration.md`](./oracle-integration.md)

This guide is intended to evolve as Conxian’s services and regulatory landscape mature.
