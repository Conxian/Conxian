# Conxian Protocol - Modular Trait System

## Overview

The Conxian Protocol has adopted a modular trait architecture to enhance organization, readability, and compilation efficiency. All contract interfaces are now defined within **10 modular trait files**, which are then aggregated in a central registry. This system provides a clear, consistent, and gas-efficient way for contracts to interact.

For a detailed overview of the architecture and the contents of each module, please see the [`README-TRAIT-ARCHITECTURE.md`](./README-TRAIT-ARCHITECTURE.md) file.

## Trait Module Index

The trait system is organized into the following 10 modules:

- **[01-sip-standards.clar](./01-sip-standards.clar)**: SIP-009 (NFT), SIP-010 (Fungible Token), and SIP-018 (Metatada).
- **[02-core-protocol.clar](./02-core-protocol.clar)**: Core protocol functionality like `ownable`, `pausable`, and `upgradeable`.
- **[03-defi-primitives.clar](./03-defi-primitives.clar)**: Essential DeFi building blocks like pools, factories, and routers.
- **[04-dimensional.clar](./04-dimensional.clar)**: Traits for the multi-dimensional DeFi engine, including position and collateral management.
- **[05-oracle-pricing.clar](./05-oracle-pricing.clar)**: Oracle and price feed interfaces.
- **[06-risk-management.clar](./06-risk-management.clar)**: Risk management, liquidation, and funding traits.
- **[07-cross-chain.clar](./07-cross-chain.clar)**: Interfaces for cross-chain functionality, including DLCs and sBTC.
- **[08-governance.clar](./08-governance.clar)**: Governance, proposals, and voting traits.
- **[09-security-monitoring.clar](./09-security-monitoring.clar)**: Security and monitoring interfaces, including the circuit breaker and MEV protection.
- **[10-math-utilities.clar](./10-math-utilities.clar)**: Shared math and utility traits.

## Usage

### Example Contract Implementation

To use a trait in your contract, import it from the appropriate module file.

#### Example 1: Import SIP-010 Fungible Token Trait
```clarity
(use-trait sip-010-ft-trait .01-sip-standards.sip-010-ft-trait)
```

#### Example 2: Import Position Manager Trait
```clarity
(use-trait position-manager-trait .04-dimensional.position-manager-trait)
```

## Development Guidelines

### Adding New Traits

1.  **Identify the correct module** for the new trait. If a suitable module does not exist, consider whether a new one is warranted.
2.  **Add the trait definition** to the appropriate module file.
3.  **Update the documentation** in the module file and the `README-TRAIT-ARCHITECTURE.md` to reflect the change.

### Trait Standards

-   Use consistent naming conventions.
-   Include comprehensive error handling.
-   Provide both read-only and state-changing functions.
-   Follow Clarity best practices.
-   Include proper documentation comments.
-   Consider gas optimization for frequently called functions.
