# Core Module

This module contains the core logic for the Conxian Protocol, including the dimensional engine for managing user positions and the central protocol coordinator for administrative control.

## Contracts

- **`dimensional-engine.clar`**: The primary entry point for DeFi operations. This contract acts as a facade, delegating calls to specialized managers for positions, collateral, funding rates, and risk management. It utilizes several traits from the `.dimensional-traits` and `.core-traits` modules.

- **`position-manager.clar`**: Manages the lifecycle of user positions, including opening, closing, and updating.

- **`funding-rate-calculator.clar`**: Calculates the funding rate for perpetual markets.

- **`collateral-manager.clar`**: Handles the deposit and withdrawal of user collateral.

- **`conxian-protocol.clar`**: The main protocol governance contract. It manages protocol-wide configurations, a registry of authorized contracts, and emergency pause functionality. It serves as the administrative backbone of the entire system.

- **`economic-policy-engine.clar`**: Manages protocol-wide economic policies, such as fee structures and interest rate models.

- **`operational-treasury.clar`**: Handles the collection and distribution of protocol fees and other operational funds.

## Status

**Under Review**: The contracts in this module form a strong architectural foundation and are compatible with Stacks Nakamoto. However, the module is currently in a stabilization and review phase. It should not be considered production-ready until the full protocol audit is complete.
