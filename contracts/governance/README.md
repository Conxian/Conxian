# Governance Module

This module provides the decentralized governance framework for the Conxian Protocol, enabling token holders to propose, vote on, and execute changes.

## Status

**Under Review**: The governance contracts provide a solid foundation for decentralized decision-making. However, they are part of the protocol-wide stabilization and safety review and should not be considered production-ready.

## Core Components

The governance system is designed around a proposal lifecycle that is managed by a few key contracts.

### Key Contracts

- **`proposal-engine.clar`**: The central entry point for all governance activities. This contract acts as a facade, coordinating the proposal and voting processes. It delegates the detailed logic to the `proposal-registry` and `voting` contracts.

- **`proposal-registry.clar`**: Responsible for creating, storing, and tracking the state of all governance proposals.

- **`voting.clar`**: Manages the voting process. It records votes cast by token holders for specific proposals and can only be called by the `proposal-engine`.

- **`timelock.clar`**: A contract that imposes a mandatory delay between the time a governance proposal is approved and when it can be executed. This provides a window for users to react to changes they may disagree with.

### Supporting Contracts

- **`governance-token.clar`**: The SIP-010 fungible token that represents voting power within the system.
- **`upgrade-controller.clar`**: A contract designed to manage the process of upgrading the protocol's smart contracts.

## Governance Flow

1.  **Propose**: A token holder calls `propose` on the `proposal-engine.clar` contract to create a new proposal, which is then stored in the `proposal-registry.clar`.
2.  **Vote**: Other token holders call `vote` on the `proposal-engine.clar` contract to cast their votes, which are recorded in the `voting.clar` contract.
3.  **Execute**: Once the voting period ends and if the proposal passes, the `execute` function can be called on the `proposal-engine.clar`. For critical changes, the execution might be routed through the `timelock.clar` contract to enforce a delay.
