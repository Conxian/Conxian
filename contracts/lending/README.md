# Lending Module

Decentralized lending and borrowing infrastructure for the Conxian Protocol supporting multi-asset collateral, algorithmic interest rates, and enterprise-grade lending operations.

## Status

**Nakamoto Ready**: This module is feature-complete and fully integrated with the Conxian modular trait system. It supports Stacks Epoch 3.0 fast blocks and Bitcoin finality.

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
- **`interest-rate-model.clar`**: A separate contract that calculates interest rates based on utilization and other factors.
- **Oracle Contract**: A dependency that provides price feeds for all supported assets. This is essential for calculating collateral value and health factors.
- **`liquidation-manager.clar`**: A specialized contract responsible for managing the liquidation process.
- **`lending-position-nft.clar`**: A comprehensive NFT system for lending protocol positions, representing borrower positions, lender positions, and liquidation events.
- **`circuit-breaker.clar`**: An optional dependency that can halt protocol operations under extreme market conditions to protect user funds.

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
- **Circuit Breaker Integration**: The contract is connected to a `circuit-breaker` contract to automatically halt operations during periods of high volatility or market instability.
