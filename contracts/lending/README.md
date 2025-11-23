# Lending Module

Decentralized lending and borrowing infrastructure for the Conxian Protocol supporting multi-asset collateral, algorithmic interest rates, and enterprise-grade lending operations.

## Status

**Migration In Progress**: The contracts in this module are in a transitional state. While they use traits for some interactions, they still rely on the legacy, non-modular trait system. A full migration to the new 10-module trait system is required to align this module with the target architecture.

## Overview

The lending module provides the foundational infrastructure for DeFi lending and borrowing within the Conxian ecosystem. It is a robust, secure, and feature-rich system designed for integration with other protocol components.

### Core Features
- **Multi-Asset Support**: Allows for a variety of assets to be used as collateral for borrowing.
- **Over-Collateralization**: Enforces strict over-collateralization to ensure protocol solvency.
- **Health Factor Monitoring**: Continuously tracks the health of loan positions to mitigate risk.
- **Automated Liquidations**: Provides mechanisms for liquidating under-collateralized positions.
- **Dynamic Interest Rates**: Integrates with a modular interest rate model to respond to market conditions.
- **Protocol Security**: Includes features like an emergency pause function and integration with a circuit breaker.

## Architecture and Dependencies

The `comprehensive-lending-system.clar` contract is the central component of the lending module, but it relies on several other contracts to function correctly. Understanding these dependencies is key to understanding the module's design.

### Key Contracts & Dependencies
- **`comprehensive-lending-system.clar`**: The main contract containing the core logic for supply, borrow, repay, and liquidation operations.
- **`interest-rate-model.clar`**: A separate contract that calculates interest rates based on utilization and other factors. This contract is a dependency and must be set by the admin.
- **Oracle Contract**: A dependency that provides price feeds for all supported assets. This is essential for calculating collateral value and health factors.
- **`liquidation-manager.clar`**: A specialized contract responsible for managing the liquidation process. Liquidations are initiated through this contract, not directly on the core lending contract.
- **`access-control.clar`**: A role-based access control contract that manages permissions for administrative functions like setting contract dependencies and pausing the protocol.
- **`circuit-breaker.clar` (Optional)**: An optional dependency that can halt protocol operations under extreme market conditions to protect user funds.
- **Proof of Reserves Contract (Optional)**: An optional dependency to verify the reserves of underlying assets, adding an extra layer of security.

## Lending Mechanics

### Health Factor
A user's "health factor" represents the safety of their loan. It is calculated based on the value of their supplied collateral against the value of their borrowed assets. A health factor below a certain threshold (typically 1.0) makes a position eligible for liquidation.

### Interest Rate Model
Interest rates are not calculated within the core lending contract. Instead, the contract calls the `interest-rate-model.clar` contract, which implements a specific model (e.g., based on utilization).

```
Interest Rate = f(Utilization Rate)
```

### Collateral Requirements
- **Liquidation Threshold**: The percentage at which a loan is defined as under-collateralized (e.g., 80%).
- **Liquidation Bonus**: A discount on the price of collateral offered to liquidators as an incentive.
- **Health Factor**: A real-time score representing the safety of a user's position.

## Usage Examples

### Basic Lending Operations

```clarity
;; Note: The following examples illustrate the function calls, but the exact trait usage
;; is subject to change pending the completion of the trait migration.

;; Deposit collateral
(contract-call? .comprehensive-lending-system supply .ft-token u1000)

;; Borrow against collateral
(contract-call? .comprehensive-lending-system borrow .ft-token u500)

;; Repay loan
(contract-call? .comprehensive-lending-system repay .ft-token u500)

;; Withdraw collateral
(contract-call? .comprehensive-lending-system withdraw .ft-token u1000)
```

## Risk Management

### Liquidation System
- **Health Factor Monitoring**: The contract provides a public `get-health-factor` function for monitoring position health.
- **Managed Liquidation**: Liquidations are handled by the `liquidation-manager` contract, which provides a structured environment for this critical process.
- **Liquidation Incentives**: The system includes a liquidation bonus to incentivize third parties to liquidate unhealthy positions promptly.

### Protocol-Level Safeguards
- **Emergency Pause**: The contract owner (typically a governance contract) can pause all supply, borrow, and withdraw functions in case of an emergency.
- **Circuit Breaker Integration**: The contract can be connected to a `circuit-breaker` contract to automatically halt operations during periods of high volatility or market instability.

## Ecosystem Integrations

The lending module is designed to be a core building block of the Conxian Protocol. While the features below are not implemented *within* this contract, it provides the necessary hooks and functionality to support them.

### DEX Module
- **Flash Loans**: Other contracts can use the lending module's liquidity to perform flash loans.
- **Price Feeds**: The lending module relies on an oracle, which can be powered by a DEX, for accurate asset pricing.

### Oracle Module
- **Real-time Price Feeds**: The lending module requires a robust oracle to provide real-time, reliable price data for all supported assets.

### Governance Module
- **Risk Parameter Management**: Governance can vote to change risk parameters like collateral factors and liquidation thresholds by calling the admin functions on this contract.
- **Emergency Controls**: Governance can execute the `pause` and `resume` functions.

## Future Directions & Ecosystem Capabilities

The following features are part of the broader Conxian vision and can be built on top of this foundational lending module, but are not implemented in this contract itself.

- **Enterprise Integration**: Building specialized contracts that interact with this module to offer features like KYC/AML, custom loan terms, and regulatory reporting.
- **Advanced Yield Strategies**: Developing vaults and other contracts that use the lending module as a source of leverage or yield.
- **Performance Optimizations**: Implementing batching or other gas-saving measures in wrapper contracts that interact with the core lending system.
