# DEX Module

This module provides the decentralized exchange (DEX) functionality for the Conxian Protocol, focusing on efficient trading and liquidity provision.

## Status

**Under Review**: This module contains a functional foundation for a modern DEX, including concentrated liquidity and multi-hop swaps. However, like the rest of the protocol, it is undergoing a stabilization and safety review and is not yet production-ready.

## Core Components

The DEX is built around a few key contracts that handle liquidity, routing, and pool management.

### Key Contracts

- **`concentrated-liquidity-pool.clar`**: The primary liquidity pool implementation. It allows liquidity providers to "concentrate" their capital in specific price ranges (ticks), increasing capital efficiency. Each liquidity position is represented as a unique NFT (SIP-009).

- **`multi-hop-router-v3.clar`**: The main entry point for executing trades. This router can perform swaps across one, two, or three different liquidity pools to find the best possible price for the user, utilizing base tokens as intermediaries.

- **`dijkstra-pathfinder.clar`**: A contract designed for optimal route discovery. **Note**: The current implementation is a simplified version. Instead of performing a full on-chain Dijkstra's algorithm, it queries a configured DEX factory to find the best *direct, single-hop* route between two tokens.

- **`dex-factory-v2.clar`**: A factory contract responsible for deploying and registering new liquidity pools within the protocol.

### Supporting Contracts

The module also includes various other contracts for features like MEV protection (`mev-protector.clar`), sBTC integration, and oracle price feeds, which are in various stages of implementation and review.
