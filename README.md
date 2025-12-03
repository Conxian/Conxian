# Conxian Protocol

[![Tests](https://img.shields.io/badge/Tests-Under_Review-yellow)](https://github.com/Anya-org/Conxian)
[![Contracts](https://img.shields.io/badge/Contracts-91-blue)](https://github.com/Anya-org/Conxian)
[![Compilation](https://img.shields.io/badge/Compile-Passing-brightgreen)](https://github.com/Anya-org/Conxian)
[![Traits](https://img.shields.io/badge/Traits-15%20Modular%20Files-brightgreen)](https://github.com/Anya-org/Conxian/tree/main/contracts/traits)
[![Status](https://img.shields.io/badge/Status-Stabilization_Phase-orange)](https://github.com/Anya-org/Conxian)
[![Network](https://img.shields.io/badge/Network-Nakamoto%20Active-green)](https://docs.hiro.so/)

## 🚀 A New Era of Decentralized Architecture

The Conxian Protocol is a comprehensive Bitcoin‑anchored, multi‑dimensional DeFi
protocol deployed on Stacks (Nakamoto). It features a modular, decentralized
architecture designed for security, scalability, and enterprise adoption.

### Key Innovations

- **Modular by Design**: Protocol architecturally divided into specialized,
  single-responsibility contracts for security, maintainability, and
  reusability.
- **Official Stacks Trait System**: All contract interfaces defined in **15
  modular trait files** following official Stacks SIP standards.
- **Nakamoto-Ready**: Architecture optimized for sub-second block times and
  Bitcoin finality of Stacks Nakamoto release.
- **Enhanced Features**:
  - **Concentrated Liquidity**: Capital efficiency with tick-based pools.
  - **MEV Protection**: Commit-reveal schemes and sandwich defense.
  - **Advanced Routing**: Dijkstra-based multi-hop pathfinding.
  - **Enterprise Suite**: Compliance hooks and tiered account management.

## 📊 Current Status - STABILIZATION PHASE (Updated Dec 03, 2025)

The Conxian Protocol is currently undergoing a **Critical Stabilization & Safety Review**.
While the architectural foundation is strong, the codebase is **NOT currently production-ready** due to pending compilation fixes and safety standard alignments.

**⚠️ WARNING: Do not attempt to deploy to Mainnet.**

### 🔄 Ongoing Work (Phase 1 & 2)

- **Compilation**: Resolving syntax blockers in `concentrated-liquidity-pool` and dependency resolution.
- **Safety Hardening**: Systematically removing `unwrap-panic` calls (180+ identified) to prevent runtime state freezing.
- **Oracle Integration**: Replacing development stubs with functional Chainlink/Pyth adapter mocks for valid testing.
- **Test Unification**: Deduplicating test suites between `tests/` and `stacks/tests/`.

Detailed status reports:
- **[Latest Readiness Review](./documentation/reports/SYSTEM_READINESS_LATEST.md)**: Detailed breakdown of blockers and remediation plan.
- **[Architecture Specification](./documentation/ARCHITECTURE_SPEC.md)**: The target vision and design patterns.

### ✅ Major Achievements

- **Modular Trait System (COMPLETE)**: Implemented **15 modular trait files**
  following official Stacks standards.
- **Architectural Reorganization**: Repository restructured with clear
  separation of concerns.
- **Critical Fixes**: Resolved access control gaps in `multi-hop-router-v3` and `enhanced-circuit-breaker`.

## Quick Start

- Install dependencies: `npm install`
- Run tests (Vitest + Clarinet SDK): `npm test`
- Check manifests: `clarinet check`

## Contract Modules

The Conxian protocol is organized into a series of specialized modules:

- **[Core Module](./contracts/core/README.md)**: Dimensional engine and
  position management.
- **[DEX Module](./contracts/dex/README.md)**: Concentrated liquidity AMM and
  routing.
- **[Governance Module](./contracts/governance/README.md)**: Proposal and voting
  system.
- **[Lending Module](./contracts/lending/README.md)**: Multi-asset lending and
  flash loans.
- **[Tokens Module](./contracts/tokens/README.md)**: Token ecosystem management.
- **[Vaults Module](./contracts/vaults/README.md)**: Asset custody and sBTC
  integration.
- **[Security Module](./contracts/security/README.md)**: Circuit breakers and
  MEV protection.

## Documentation

**[Whitepaper]
(./documentation/whitepaper/Conxian-Whitepaper.md)**:

- Full technical vision and architecture.
  
**[Roadmap](./ROADMAP.md)**:

- Development phases and status tracking.
**[System Index](./system-index.md)**:
- Technical fix log and component index.

## Contributing

See `CONTRIBUTING.md` for contribution guidelines and policy checks.
