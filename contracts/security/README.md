# Security Module

This module contains contracts designed to enhance the security and risk management of the Conxian Protocol.

## Status

**Under Review**: The security contracts provide essential tools for protocol safety, but they are currently part of the protocol-wide stabilization and review phase.

## Core Components

The module provides several key security features, including emergency stops, access control, and MEV mitigation.

### Key Contracts

- **`circuit-breaker.clar` & `enhanced-circuit-breaker.clar`**: These contracts provide a mechanism to halt critical protocol operations in the event of an emergency, such as a severe market crash or the discovery of an exploit. The `enhanced` version offers more granular control.

- **`Pausable.clar`**: A simple, reusable contract that allows other contracts to inherit emergency stop functionality.

- **`role-manager.clar`**: Implements a role-based access control (RBAC) system. This allows the protocol to define specific roles (e.g., "admin," "guardian") with granular permissions to execute sensitive functions.

- **`role-nft.clar`**: An extension of the RBAC system where roles are represented as NFTs (SIP-009). This allows for the possibility of transferring or delegating roles.

- **`mev-protector.clar`**: A contract designed to mitigate Miner Extractable Value (MEV) by providing mechanisms to protect users from front-running and sandwich attacks.

- **`conxian-insurance-fund.clar`**: A contract for establishing and managing an insurance fund to cover potential protocol losses.

- **`proof-of-reserves.clar`**: A contract intended to provide on-chain verification of the protocol's reserves.
