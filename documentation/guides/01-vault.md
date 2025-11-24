# Contract Guide: `sbtc-vault.clar`

**Primary Contract:** `contracts/vaults/sbtc-vault.clar`

## 1. Introduction

The `sbtc-vault.clar` contract serves as the main entry point for the Conxian Protocol's sBTC vault. It acts as a facade, delegating all core logic to a set of specialized, single-responsibility contracts. This modular design enhances security and maintainability.

## 2. Core Architecture

The `sbtc-vault` contract does not manage user funds or complex logic directly. Instead, it delegates calls to the following specialized contracts:

-   **`custody.clar`**: Manages the deposit, withdrawal, and accounting of user funds (sBTC).
-   **`yield-aggregator.clar`**: Handles the allocation of funds to various yield-generating strategies.
-   **`btc-bridge.clar`**: Manages the wrapping and unwrapping of BTC to and from sBTC.
-   **`fee-manager.clar`**: Calculates and applies fees for various vault operations.

This architecture separates the core accounting of the vault from the more complex logic of yield generation and cross-chain operations.

## 3. Key Functions

### User-Facing Functions

-   **`deposit`**: Deposits sBTC into the vault. This call is delegated to the `custody.clar` contract.
-   **`withdraw`**: Initiates a withdrawal of sBTC from the vault. This call is also delegated to `custody.clar`.
-   **`wrap-btc`**: Wraps BTC into sBTC. This call is delegated to the `btc-bridge.clar` contract.
-   **`unwrap-to-btc`**: Unwraps sBTC back into BTC. This call is also delegated to `btc-bridge.clar`.

### Admin and Owner Functions

-   **`set-custody-contract`**, **`set-yield-aggregator-contract`**, **`set-btc-bridge-contract`**, **`set-fee-manager-contract`**: These functions allow the contract owner to set the addresses of the specialized contracts.
-   **`allocate-to-strategy`**: Allows the contract owner to allocate funds to a yield strategy, via the `yield-aggregator.clar` contract.
-   **`harvest-yield`**: Allows the contract owner to harvest yield from a strategy, also via the `yield-aggregator.clar` contract.
-   **`set-vault-paused`**: Allows the contract owner to pause or unpause the vault.

## 4. Read-Only Functions

-   **`get-vault-stats`**: A placeholder function that will be updated to aggregate data from the various specialized contracts to provide a comprehensive overview of the vault's status.
