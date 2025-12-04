# Lending Module

This module provides the core components for a decentralized lending and borrowing market within the Conxian Protocol.

## Status

**Under Review**: The lending module has a solid architectural foundation but is currently in a stabilization and review phase. Key components, such as the health factor calculation, are not fully implemented, and the module should not be considered production-ready.

## Core Components

The lending functionality is primarily handled by a main system contract, with specialized contracts for liquidations and interest rate models.

### Key Contracts

- **`comprehensive-lending-system.clar`**: The central contract for the lending market. It handles all core user-facing functions: `supply`, `withdraw`, `borrow`, and `repay`. It also includes hooks for integrating with other protocol features like circuit breakers and fee managers.

- **`liquidation-manager.clar`**: A specialized contract responsible for managing the process of liquidating under-collateralized positions. It includes functions to check if a position is eligible for liquidation and to execute the liquidation itself.

- **`interest-rate-model.clar`**: A contract that would typically calculate interest rates based on market utilization. The current implementation provides the structure for such a model.

- **`lending-position-nft.clar`**: An NFT (SIP-009) contract designed to represent user positions within the lending protocol, though its integration is still under development.

## Important Notes

### Health Factor

The `comprehensive-lending-system.clar` contract contains a `get-health-factor` function, which is critical for determining when a position can be liquidated. **It is important to note that the current implementation of this function is a placeholder and returns a static, high value.** A robust, production-ready implementation would require a price oracle to accurately calculate the value of a user's collateral and debt.

### Liquidation Process

Liquidations are initiated through the `liquidation-manager.clar` contract. This contract is designed to check a borrower's health factor (via the lending system) and, if it is below the required threshold, allow a liquidator to repay a portion of the borrower's debt in exchange for a discounted amount of their collateral.
