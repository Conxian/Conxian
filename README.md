# Conxian Protocol

[![Tests](https://img.shields.io/badge/Tests-Comprehensive-green)](https://github.com/Anya-org/Conxian)
[![Contracts](https://img.shields.io/badge/Contracts-239%2B-blue)](https://github.com/Anya-org/Conxian)
[![Status](https://img.shields.io/badge/Status-Core%20System%20Implemented-blue)](https://github.com/Anya-org/Conxian)
[![Network](https://img.shields.io/badge/Network-Testnet%2FMainnet-9cf)](https://docs.hiro.so/)

## Documentation

All documentation for the Conxian Protocol can be found in the
[`documentation`](./documentation) directory.

## Quick Start

- Install dependencies: `npm install`
- Run tests (Vitest + Clarinet SDK): `npm test`
- Check manifests (if Clarinet CLI installed): `npx clarinet check`

## Contract Modules

The Conxian Protocol is organized into the following contract modules:

### Core DEX

- **[DEX Module](./contracts/dex/README.md)**: Decentralized exchange functionality
  with concentrated liquidity, routing, and MEV protection

### Governance & Security

- **[Governance Module](./contracts/governance/README.md)**: Proposal and voting
  with upgrade management and emergency governance
- **[Security Module](./contracts/security/README.md)**: Security controls and
  audit management

### Multi-Dimensional DeFi

- **[Dimensional Module](./contracts/dimensional/README.md)**: Multi-dimensional
  DeFi with spatial, temporal, risk, and cross-chain dimensions

### Lending & Borrowing

- **[Lending Module](./contracts/lending/README.md)**: Multi-asset lending and
  borrowing with enterprise integration

### Token Economics

- **[Tokens Module](./contracts/tokens/README.md)**: Token contracts and economic
  coordination

### Infrastructure & Utilities

- **[Pools Module](./contracts/pools/README.md)**: Liquidity pool management and
  concentrated liquidity
- **[Oracle Module](./contracts/oracle/README.md)**: Price feeds and data
  aggregation
- **[Monitoring Module](./contracts/monitoring/README.md)**: Analytics and
  performance monitoring
- **[Traits Module](./contracts/traits/README.md)**: Standard trait definitions

## Single Source of Truth

- Canonical manifest: `Clarinet.toml` at the repository root
- Canonical contracts: `contracts/`
- Deployment plans: `deployments/`
- Tests: `tests/` using the root manifest by default
- The `stacks/` directory is for test harnesses only and must reference root
  contracts (no production logic duplicates)

See `CONTRIBUTING.md` for contribution guidelines and policy checks.
