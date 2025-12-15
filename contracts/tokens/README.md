# Tokens Module

## Overview

The Tokens Module defines the entire suite of fungible (SIP-010) and non-fungible (SIP-009) tokens that power the Conxian Protocol. It includes the primary revenue token (CXD), governance tokens, and specialized NFTs for representing economic positions.

## Architecture: Coordinator Facade

The Tokens Module is built around a central **coordinator facade**. The `token-system-coordinator.clar` contract acts as this single, secure entry point for orchestrating actions across the various specialized token contracts. This ensures that complex, multi-token operations are handled in a consistent and secure manner.

### Control Flow Diagram

```
[User/System] -> [token-system-coordinator.clar] (Coordinator Facade)
    |
    |-- (distribute-revenue) --> [cxd-token.clar]
    |-- (update-reputation) --> [cxvg-token.clar]
    |-- (manage-lp-position) --> [cxlp-position-nft.clar]
```

## Core Contracts

### Coordinator Facade

-   **`token-system-coordinator.clar`**: The central **facade** for the token ecosystem. It provides a unified interface for tracking token operations, managing user reputations, and triggering revenue distribution events across the various specialized token contracts.

### Token Implementations

-   **`cxd-token.clar`**: The primary **Conxian Revenue Token (CXD)**. A SIP-010 fungible token that serves as the main utility and revenue-accruing asset of the protocol.
-   **`cxtr-token.clar`**: The **Conxian Treasury Token (CXTR)**. A SIP-010 fungible token used for internal accounting, creator economy incentives, and long-term protocol funding.
-   **`cxvg-token.clar`**: The **Conxian Voting Token (CXVG)**. A SIP-010 fungible token that represents voting power in the governance system.
-   **`cxlp-token.clar`**: The **Conxian LP Token (CXLP)**. A SIP-010 fungible token that represents a user's share of a standard liquidity pool.
-   **`cxs-token.clar`**: The **Conxian Staking Position (CXS)**. A SIP-009 non-fungible token where each NFT represents a unique staking position, with lock duration and reward tracking encoded per position.
-   **`cxlp-position-nft.clar`**: A SIP-009 non-fungible token representing a user's position in a concentrated liquidity pool, enabling granular accounting of range, fees, and ownership.

## Status

**Under Review**: The contracts in this module are currently under review. While the core token contracts are functionally complete, the `token-system-coordinator.clar` is being hardened to ensure full security and alignment with the protocol's event-driven architecture. These contracts are not yet considered production-ready.
