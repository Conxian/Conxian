# Governance Module

## Overview

The Governance Module provides the framework for decentralized decision-making and protocol upgrades. It is designed to be secure, transparent, and flexible, enabling the community to propose, vote on, and execute changes. The module also features the **Conxian Operations Engine**, an automated on-chain agent that participates in governance.

## Architecture: Facade with Specialized Managers

Following the protocol's standard architectural pattern, the Governance Module is built around a central **facade**. The `proposal-engine.clar` contract acts as this single, secure entry point for all governance-related actions, delegating specific tasks to a set of specialized manager contracts.

This facade design ensures a clear and secure process for protocol governance, from proposal creation to execution.

### Control Flow Diagram

```
[User/DAO] -> [proposal-engine.clar] (Facade)
    |
    |-- (submit-proposal) --> [proposal-registry.clar]
    |-- (cast-vote) --> [voting.clar]
    |-- (execute-proposal) --> [upgrade-controller.clar]

[Metrics] -> [conxian-operations-engine.clar] -> [proposal-engine.clar] (Automated Vote)
```

## Core Contracts

### Facade

-   **`proposal-engine.clar`**: The primary **facade** for the governance module. It provides a unified interface for creating proposals, casting votes, and executing the outcomes, delegating the underlying logic to the appropriate manager contracts.

### Manager Contracts

-   **`proposal-registry.clar`**: A specialized contract for storing and managing all governance proposals, ensuring data integrity from creation to execution.
-   **`voting.clar`**: Manages the entire voting process, including recording votes, calculating results, and enforcing voting rules.
-   **`upgrade-controller.clar`**: A dedicated contract for managing protocol upgrades, incorporating security features like timelocks and multi-signature requirements.

### Automated Governance Agent

-   **`conxian-operations-engine.clar`**: An automated agent that holds a formal seat in the DAO. It consumes on-chain metrics from core protocol modules, aggregates them into policy-constrained votes, and participates in governance by calling the `proposal-engine.clar`.

### Supporting Contracts

-   **`enhanced-governance-nft.clar`**: Implements the NFT-based council and role system, allowing for sophisticated, on-chain representation of governance powers and responsibilities.

## Status

**Under Review**: The contracts in this module are currently undergoing a comprehensive review. While the core governance functionality is implemented, the contracts are not yet considered production-ready and are being hardened to ensure full security and alignment with the protocol's architecture.
