# DEX Module

## Overview

The DEX Module provides the core functionality for decentralized exchange operations within the Conxian Protocol. It is designed to be modular and gas-efficient, with a focus on providing robust and secure swapping capabilities. The primary contract in this module is the `multi-hop-router-v3.clar`, which serves as the main entry point for executing trades.

## Contracts

- **`multi-hop-router-v3.clar`**: The central routing engine for the DEX. It supports 1-hop, 2-hop, and 3-hop swaps, allowing for efficient trading across multiple liquidity pools. The router relies on off-chain clients to discover the optimal trading routes, which are then executed on-chain.

- **`concentrated-liquidity-pool.clar`**: Implements a concentrated liquidity AMM, allowing for greater capital efficiency. This contract is currently under review and is not yet considered production-ready.

- **`dijkstra-pathfinder.clar`**: A contract intended to implement Dijkstra's algorithm for on-chain route discovery. This contract is not yet fully implemented and is not integrated with the `multi-hop-router-v3.clar`.

- **`dex-factory.clar`**: A factory contract for creating and managing liquidity pools. This contract is currently under review.

## Architecture

The DEX Module is designed to be flexible and extensible. The `multi-hop-router-v3.clar` is the core component, providing the execution logic for swaps. The router is designed to be agnostic to the underlying pool implementation, allowing it to be used with a variety of pool types.

## Status

**Under Review**: The contracts in this module are currently undergoing a comprehensive review to ensure correctness, security, and alignment with the modular trait architecture. While the core swapping functionality is implemented in the `multi-hop-router-v3.clar`, other contracts in this module are not yet considered production-ready.
