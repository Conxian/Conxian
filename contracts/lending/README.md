# Lending Module

## Overview

The Lending Module provides the core infrastructure for decentralized lending and borrowing within the Conxian Protocol. It is designed to be a secure and robust system for managing multi-asset collateral, algorithmic interest rates, and enterprise-grade lending operations. The central component of this module is the `comprehensive-lending-system.clar` contract, which handles all the core logic for supply, borrow, repay, and liquidation operations.

## Contracts

- **`comprehensive-lending-system.clar`**: The main contract for the lending module. It manages user deposits, loans, and collateral, and integrates with other contracts to handle interest rates and liquidations. It includes a robust health factor check system to ensure the solvency of the protocol, and it provides hook-enabled functions for extensibility.

- **`interest-rate-model.clar`**: A specialized contract that calculates interest rates based on market conditions, such as the utilization rate of a given asset. It uses a dynamic model with a "kink" to adjust rates based on borrowing demand.

- **`liquidation-manager.clar`**: A contract responsible for managing the liquidation process for under-collateralized loans. It provides a set of public functions for checking the health of a position and initiating liquidations.

- **`lending-position-nft.clar`**: A system for representing user positions in the lending protocol as NFTs. This allows for greater flexibility and composability. The contract supports a variety of NFT types, including borrower positions, lender positions, and liquidation events.

## Architecture

The Lending Module is designed with a modular architecture, where the `comprehensive-lending-system.clar` contract acts as the central hub, coordinating with other specialized contracts to perform its functions. This separation of concerns enhances security and allows for greater flexibility in upgrading individual components.

## Status

**Under Review**: The contracts in this module are currently under review and are not yet considered production-ready. The core functionality is implemented, including a conservative `get-health-factor` implementation and optional health-factor-based guardrails (`borrow-checked` and `withdraw-checked`). These metrics are also wired into the Conxian Operations Engine for monitoring, but parameters and cross-module tests are still being hardened.
