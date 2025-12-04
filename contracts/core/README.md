# Core Module

## Overview

The Core Module forms the foundational layer of the Conxian Protocol, orchestrating the interactions between various specialized components. It is designed around a modular, facade-based architecture where the `dimensional-engine.clar` contract serves as the central entry point for all user-facing operations. This design enhances security and simplifies user interactions by routing calls to the appropriate single-responsibility contracts.

## Contracts

- **`dimensional-engine.clar`**: The central facade for the Core Module. It routes all calls to the specialized manager contracts, ensuring a single, secure entry point for position management, collateral handling, and risk assessment.

- **`position-manager.clar`**: Manages the lifecycle of user positions, including opening, closing, and liquidations. It implements the `.dimensional-traits.position-manager-trait`.

- **`funding-rate-calculator.clar`**: Responsible for calculating and applying funding rates for perpetual markets. It implements the `.dimensional-traits.funding-rate-calculator-trait` and uses the `.core-protocol.rbac-trait` for access control.

- **`collateral-manager.clar`**: Handles the deposit, withdrawal, and management of user collateral. It implements the `.dimensional-traits.collateral-manager-trait`.

- **`conxian-protocol.clar`**: The main protocol coordinator, responsible for managing protocol-wide configurations, authorized contracts, and emergency controls.

- **`economic-policy-engine.clar`**: Manages the economic parameters of the protocol, including fee structures and incentives.

- **`operational-treasury.clar`**: Handles the protocol's operational funds, ensuring transparency and proper use of resources.

- **`tier-manager.clar`**: Manages user tiers and associated benefits, providing a framework for rewarding user loyalty and engagement.

## Architecture

The Core Module follows a modular, trait-driven architecture. The `dimensional-engine.clar` contract acts as a facade, delegating all calls to the specialized contracts that implement the required traits. This separation of concerns enhances security, simplifies maintenance, and allows for greater flexibility in upgrading individual components.

## Status

**Under Review**: The contracts in this module are currently undergoing a comprehensive review to ensure correctness, security, and alignment with the modular trait architecture. While the core functionality is implemented, the contracts are not yet considered production-ready.
