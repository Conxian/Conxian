# Conxian Protocol - Trait System

## Overview

The Conxian Protocol utilizes a comprehensive trait system to define interfaces for modularity, interoperability, and standard compliance. The system comprises **15 trait files**, organized into core modules and specialized definitions.

For a detailed architectural breakdown and import patterns, please see the [`README-TRAIT-ARCHITECTURE.md`](./README-TRAIT-ARCHITECTURE.md) file.

## Trait File Index

The trait system includes the following files:

### Core & Standards

- **`sip-standards.clar`**: SIP-009 (NFT), SIP-010 (Fungible Token), and SIP-018 (Metadata).
- **`core-traits.clar`**: Foundational traits including `ownable`, `pausable`, `rbac` (Role-Based Access Control), and `reentrancy-guard`.
- **`core-protocol.clar`**: Protocol-level traits like `upgradeable`, `revenue-distributor`, and `token-coordinator`.
- **`trait-errors.clar`**: Standardized error code constants used across the protocol.

### DeFi Primitives

- **`defi-primitives.clar`**: Core DeFi building blocks including `pool-trait`, `pool-factory-trait`, `router-trait`.
- **`defi-traits.clar`**: Comprehensive DeFi interfaces including `vault-trait`, `flash-loan-trait`, and legacy pool definitions.
- **`queue-traits.clar`**: Interfaces for queue operations in token transfers.
- **`controller-traits.clar`**: Token minting control and authorization interfaces.

### Dimensional Engine

- **`dimensional-traits.clar`**: Multi-dimensional position management, `position-manager`, `collateral-manager`.
- **`oracle-pricing.clar`**: Price feed interfaces, `oracle-trait`, `oracle-aggregator-v2-trait`.
- **`risk-management.clar`**: Risk assessment, liquidation engines, and funding calculators.

### Governance & Security

- **`governance-traits.clar`**: DAO, proposal engine, and voting interfaces.
- **`security-monitoring.clar`**: Circuit breakers, MEV protection, and protocol monitoring.

### Cross-Chain & Utilities

- **`cross-chain-traits.clar`**: Bitcoin integration, DLC management, and sBTC bridges.
- **`math-utilities.clar`**: Fixed-point math, financial metrics, and general utilities.

## Usage

To use a trait in your contract, import it from the appropriate file using the `.filename.trait-name` syntax.

### Example 1: Import RBAC Trait

```clarity
(use-trait rbac-trait .core-traits.rbac-trait)
```

### Example 2: Import Position Manager Trait

```clarity
(use-trait position-manager-trait .dimensional-traits.position-manager-trait)
```
