# Vaults Module

## Overview

The Vaults Module provides the core infrastructure for yield-generating vaults within the Conxian Protocol. The primary implementation is the `sbtc-vault.clar`, which allows users to deposit sBTC and earn yield through a variety of automated strategies.

## Architecture: Facade with Specialized Managers

The Vaults Module follows the protocol's standard **facade pattern**. The `sbtc-vault.clar` contract acts as the central **facade**, providing a single, secure entry point for all user interactions with the sBTC vault. It delegates specialized tasks, such as custody, yield aggregation, and fee management, to a set of dedicated manager contracts.

### Control Flow Diagram

```
[User] -> [sbtc-vault.clar] (Facade)
    |
    |-- (deposit) --> [custody.clar]
    |-- (earn) --> [yield-aggregator.clar]
    |-- (claim-fees) --> [fee-manager.clar]
    |-- (bridge-in) --> [btc-adapter.clar]
```

## Core Contracts

### Facade

-   **`sbtc-vault.clar`**: The main **facade** for the sBTC vault. It handles all core user operations, including deposits, withdrawals, and yield collection, delegating the underlying logic to the appropriate manager contracts.

### Manager Contracts

-   **`custody.clar`**: Manages the secure custody of the sBTC and other assets deposited in the vault.
-   **`yield-aggregator.clar`**: The core of the yield generation logic. It aggregates yield from various strategies (e.g., lending, liquidity provision) and allocates the vault's assets to optimize returns.
-   **`fee-manager.clar`**: Manages the collection and distribution of performance and management fees for the vault.
-   **`btc-adapter.clar`**: (Located in `contracts/sbtc/`) A specialized contract that handles the trustless verification of Bitcoin transactions, providing a seamless bridge for users to enter and exit the Stacks ecosystem.

### Registry

-   **`vault-registrar.clar`**: A central registry for all vaults within the Conxian Protocol. It stores the addresses and metadata of all official vaults, allowing for easy discovery and integration.

## Status

**Under Review**: The contracts in this module are currently under review. While the core functionality is implemented, the integration with the yield-aggregator and the fee-manager is still being hardened. These contracts are not yet considered production-ready.
