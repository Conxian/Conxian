# Core Module

## Overview

The Core Module is the foundational layer of the Conxian Protocol, responsible for dimensional trading, position management, and system-wide risk assessment. It is designed around a secure, modular **facade pattern** where the `dimensional-engine.clar` contract serves as the single, unified entry point for all user-facing operations.

This architecture enhances security by abstracting the underlying complexity and ensures maintainability by routing calls to a set of specialized, single-responsibility manager contracts.

## Architecture: Facade Pattern

The Core Module's architecture is a clear implementation of the facade pattern. All external calls are directed to the `dimensional-engine.clar` contract, which contains minimal business logic. Its primary function is to validate inputs and delegate the actual work to the appropriate manager contract.

This interaction is governed by a set of standardized interfaces defined in `/contracts/traits/dimensional-traits.clar`.

### Control Flow Diagram

```
[User] -> [dimensional-engine.clar] (Facade)
    |
    |-- (open-position) --> [position-manager.clar]
    |-- (deposit-funds) --> [collateral-manager.clar]
    |-- (update-funding-rate) --> [funding-rate-calculator.clar]
    |-- (check-position-health) --> [risk-manager.clar]
```

## Core Contracts

### Facade

-   **`dimensional-engine.clar`**: The central **facade** for the Core Module. It acts as the single, secure entry point for all position management, collateral, and risk-related calls. It implements no core logic itself; instead, it delegates every call to the specialized manager contracts.

### Manager Contracts (Single-Responsibility)

-   **`position-manager.clar`**: Manages the entire lifecycle of user trading positions, including opening, closing, and modifying them. It implements the `position-manager-trait`.
-   **`collateral-manager.clar`**: Handles all operations related to user collateral, including deposits, withdrawals, and balance tracking. It implements the `collateral-manager-trait`.
-   **`funding-rate-calculator.clar`**: Responsible for calculating and applying funding rates for perpetual markets, ensuring market balance. It implements the `funding-rate-calculator-trait`.
-   **`risk-manager.clar`** (Located in `contracts/risk/`): Assesses the health of all open positions and manages the liquidation process for those that are under-collateralized. It implements the `risk-manager-trait`.

### Protocol-Wide Contracts

-   **`conxian-protocol.clar`**: The main protocol coordinator, responsible for managing system-wide configurations, authorized contract addresses, and emergency controls.
-   **`protocol-fee-switch.clar`**: A centralized switch for routing protocol fees to their designated destinations, such as the treasury, staking rewards, or insurance funds.

## Status

**Under Review**: The contracts in this module are currently undergoing a comprehensive review to ensure correctness, security, and full alignment with the modular trait architecture. While the core functionality is implemented, the contracts are not yet considered production-ready.
