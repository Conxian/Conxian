# Lending Module

## Overview

The Lending Module provides the core infrastructure for decentralized lending and borrowing within the Conxian Protocol. It is designed as a secure, multi-asset system for managing collateral, algorithmic interest rates, and orderly liquidations.

## Architecture: Facade with Specialized Managers

The Lending Module follows the same **facade pattern** as the other core components of the protocol. The `comprehensive-lending-system.clar` contract acts as the central **facade**, providing a single, secure entry point for all lending and borrowing operations. It delegates specialized tasks, such as interest rate calculations and liquidations, to dedicated manager contracts.

This design simplifies user interaction, enhances security by centralizing entry points, and improves maintainability by separating distinct business logic into modular components.

### Control Flow Diagram

```
[User] -> [comprehensive-lending-system.clar] (Facade)
    |
    |-- (calculate-interest) --> [interest-rate-model.clar]
    |-- (liquidate-loan) --> [liquidation-manager.clar]
    |-- (mint-position) --> [lending-position-nft.clar]
```

## Core Contracts

### Facade

-   **`comprehensive-lending-system.clar`**: The main **facade** for the lending module. It manages all core user operations, including deposits, loans, and collateral management. It integrates with the manager contracts below to handle specialized logic.

### Manager Contracts

-   **`interest-rate-model.clar`**: A specialized contract that calculates borrowing interest rates based on market conditions, primarily the utilization rate of a given asset pool.
-   **`liquidation-manager.clar`**: A dedicated contract responsible for managing the entire liquidation process for under-collateralized loans, ensuring the solvency of the protocol.
-   **`lending-position-nft.clar`**: An NFT contract that represents user positions in the lending protocol as unique SIP-009 NFTs. This enhances the composability and transferability of lending and borrowing positions.

## Status

**Under Review**: The contracts in this module are currently under review and are not yet considered production-ready. The core functionality is implemented, including a conservative `get-health-factor` check and optional guardrails (`borrow-checked` and `withdraw-checked`). These metrics are also wired into the Conxian Operations Engine for monitoring, but parameters and cross-module tests are still being hardened.
