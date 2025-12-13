# DEX Module

## Overview

The DEX Module provides the core functionality for decentralized exchange operations within the Conxian Protocol. It is designed to be modular and gas-efficient, with a focus on providing robust and secure swapping capabilities. The primary contract in this module is the `multi-hop-router-v3.clar`, which serves as the main entry point for executing trades.

## Contracts

### Core Components

- **`multi-hop-router-v3.clar`**: The central routing engine for the DEX. It supports 1-hop, 2-hop, and 3-hop swaps, allowing for efficient trading across multiple liquidity pools. The router relies on off-chain clients to discover the optimal trading routes, which are then executed on-chain.

- **`dex-factory.clar`**: A facade for creating and managing liquidity pools. It delegates the logic for pool creation and registration to a suite of specialized registry contracts, providing a single entry point for pool management.

- **`on-chain-router-helper.clar`**: A helper contract that replaces the legacy pathfinder. It provides read-only functions to verify off-chain routes, check liquidity availability, and validate token connectivity before execution.

### Pool Implementations

- **`concentrated-liquidity-pool.clar`**: Implements a concentrated liquidity AMM, allowing for greater capital efficiency. This contract is the primary pool implementation for volatile asset pairs.

- **`stable-swap-pool.clar`**: An implementation of a stable swap AMM, designed for low-slippage trades between stablecoins and other similarly priced assets.

- **`weighted-swap-pool.clar`**: A flexible pool implementation that supports up to eight tokens with custom weights, allowing for the creation of token baskets and other unique liquidity pools.

### Oracles

- **`oracle-aggregator-v2.clar`**: A sophisticated oracle aggregator that provides reliable price feeds for a variety of assets. It is a critical component of the DEX, providing the price information necessary for swaps and other operations.

### Other Important Contracts

- **`vault.clar`**: A contract for creating and managing token vaults. Vaults can be used for a variety of purposes, such as yield farming and liquidity provision.

- **`auto-compounder.clar`**: A contract that automates the process of compounding rewards from liquidity provision and other yield-bearing activities.

- **`bond-factory.clar`**: A factory for creating and managing bond tokens. Bond tokens can be used to represent a variety of debt instruments.

## Architecture

The DEX Module is designed to be flexible and extensible. The `multi-hop-router-v3.clar` is the core component, providing the execution logic for swaps. The router is designed to be agnostic to the underlying pool implementation, allowing it to be used with a variety of pool types. The `dex-factory.clar` provides a unified interface for creating and managing pools, while the various pool implementations provide the specific logic for different types of liquidity pools.

## Status

**Under Review**: The contracts in this module are currently undergoing a comprehensive review to ensure correctness, security, and alignment with the modular trait architecture. While the core swapping functionality is implemented in the `multi-hop-router-v3.clar`, other contracts in this module are not yet considered production-ready.
