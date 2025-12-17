# DEX Module

## Overview

The DEX Module provides a highly efficient and capital-aware decentralized exchange. It is architected to be flexible and extensible, supporting multiple pool types and optimized trading routes. The module separates the concerns of trade execution, pool creation, and liquidity management into distinct, specialized contracts.

## Architecture: Execution Facade & Factories

The DEX module uses a variation of the facade pattern. The `multi-hop-router-v3.clar` acts as the **execution facade**, providing a single, secure entry point for all swap operations. The creation and management of liquidity pools are handled by dedicated **factory** and **registry** contracts.

This separation ensures that the core trading logic remains clean and gas-efficient, while the administrative overhead of pool management is handled by a separate set of contracts.

### Control Flow Diagram

```
[User] -> [multi-hop-router-v3.clar] (Execution Facade)
    |
    |-- (swap) --> [concentrated-liquidity-pool.clar]
    |-- (swap) --> [stable-swap-pool.clar]
    |-- (swap) --> [weighted-swap-pool.clar]

[LP] -> [dex-factory.clar] (Admin Facade)
    |
    |-- (create-pool) --> [pool-registry.clar]
```

## Core Contracts

### Execution Facade

-   **`multi-hop-router-v3.clar`**: The central **facade** for trade execution. It provides a unified interface for performing swaps across one or more liquidity pools (1-hop, 2-hop, and 3-hop). It is responsible for routing the trade through the correct sequence of pools to achieve the optimal price.

### Administrative Facades & Factories

-   **`dex-factory.clar`**: The primary **facade** for creating and managing liquidity pools. It provides a single entry point for liquidity providers to create new pools, and it delegates the registration logic to the appropriate registry contracts.
-   **`pool-registry.clar`**: A central registry that stores the addresses and metadata of all official liquidity pools, ensuring the router can discover and interact with them.

### Pool Implementations

The DEX supports multiple AMM models to cater to different asset types and liquidity strategies:

-   **`concentrated-liquidity-pool.clar`**: The primary implementation for volatile asset pairs. It allows for greater capital efficiency by enabling liquidity providers to concentrate their capital within specific price ranges.
-   **`stable-swap-pool.clar`**: An AMM designed for low-slippage trades between stablecoins and other similarly priced assets.
-   **`weighted-swap-pool.clar`**: A flexible pool that supports up to eight tokens with custom weights, ideal for creating index-like token baskets.

## Status

**Under Review**: The contracts in this module are currently undergoing a comprehensive review. While the core swapping functionality in `multi-hop-router-v3.clar` is stable, the surrounding factory and registry contracts are being refined to ensure full alignment with the protocol's modular architecture. These contracts are not yet considered production-ready.
