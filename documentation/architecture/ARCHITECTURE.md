# Conxian Protocol Architecture

This document provides a high-level overview of the Conxian protocol's architecture. The protocol is a comprehensive DeFi system built on the Stacks blockchain.

**Last Updated**: December 03, 2025

## Architecture Principles

- **Modular Design**: The protocol is architecturally divided into a series of specialized modules, each with a clearly defined responsibility (e.g., DEX, Lending, Governance). This separation of concerns enhances security, maintainability, and clarity.
- **Facade Pattern**: Many of the core modules utilize a facade pattern, where a primary contract serves as the main entry point and delegates calls to more specialized, single-responsibility contracts.
- **Nakamoto-Ready**: The protocol is designed to be fully compatible with the Stacks Nakamoto release, taking advantage of its fast block times and Bitcoin finality.
- **sBTC Integration**: The protocol is designed to be Bitcoin-native, with a strong focus on integrating sBTC as a primary form of collateral and liquidity.

## Core Contract Modules

The Conxian protocol is organized into a series of specialized modules, each located in its own subdirectory within the `contracts` directory. For a detailed description of each module, please refer to its respective `README.md` file.

- **`core`**: Contains the `dimensional-engine`, which acts as a central facade for DeFi operations, and the `conxian-protocol` contract, which handles administrative functions like contract authorization and emergency pauses.

- **`dex`**: A decentralized exchange featuring a `concentrated-liquidity-pool` for capital-efficient trading and a `multi-hop-router-v3` for finding optimal trade routes.

- **`governance`**: A decentralized governance system built around a `proposal-engine` that manages the lifecycle of proposals, from creation to execution.

- **`lending`**: A multi-asset lending market, centered around the `comprehensive-lending-system.clar` contract, which handles supplying, borrowing, and repaying assets. A `liquidation-manager` contract is responsible for handling under-collateralized positions.

- **`tokens`**: The collection of SIP-010 fungible tokens that power the Conxian ecosystem.

- **`vaults`**: A system for asset management, including a dedicated `sbtc-vault` for earning yield on sBTC deposits.

- **`security`**: A suite of contracts designed to enhance protocol safety, including a `circuit-breaker` for emergencies and a `role-manager` for access control.

## Security Architecture

The protocol includes a multi-layered security architecture to protect user funds and ensure system stability.

- **Circuit Breakers**: An emergency pause mechanism that can be triggered to halt protocol operations under extreme market conditions.
- **Access Controls**: A role-based access control system to manage permissions for sensitive functions.
- **MEV Protection**: Mechanisms to mitigate the effects of Maximal Extractable Value (MEV).

## Current Status

The Conxian protocol has a strong, modular architectural foundation. However, the protocol is currently in a **stabilization and safety review phase** and is not yet production-ready. An external security audit is required before any mainnet deployment.
