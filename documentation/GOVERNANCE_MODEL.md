# Conxian Protocol: Governance Model

## 1. Overview

The governance model of the Conxian Protocol is designed to be secure, transparent, and progressively decentralized. Our philosophy is to begin with a secure, centralized model during the initial **Technical Alpha** phase and then transition, in clear, deliberate phases, to a robust, on-chain, multi-council DAO.

This document outlines both the current state of our governance and the target architecture we are actively building toward.

## 2. Current Governance Model: Technical Alpha

During the current Technical Alpha phase, the protocol is governed by a centralized, multi-signature committee composed of the core development team. This approach is a deliberate security measure, designed to allow for rapid responses to any potential issues that may arise during this early stage of development.

### 2.1 Key Characteristics

-   **Centralized Control**: Critical functions, such as upgrading contracts and adjusting system parameters, are controlled by a `contract-owner` address. This is typically a multi-signature wallet managed by the core team.
-   **Security Focus**: This model prioritizes security and the ability to intervene quickly in the event of an unforeseen bug or economic exploit.
-   **Off-Chain Coordination**: Decisions are made through off-chain coordination among the core development team, with a focus on stabilizing and hardening the protocol.

This centralized model is a temporary and necessary scaffold. It is not the long-term vision for the protocol.

## 3. Target Governance Model: The Multi-Council DAO

The long-term vision for the Conxian Protocol is a fully decentralized, on-chain governance system that is both robust and flexible enough to manage a sophisticated financial protocol. This model is based on a multi-council structure, where different aspects of the protocol are managed by specialized, elected bodies.

### 3.1 Core Components

-   **Proposal Engine Facade (`proposal-engine.clar`)**: The central entry point for all governance actions. It will manage the lifecycle of proposals, from submission to execution, and will be the single source of truth for all governance-related data.

-   **Multi-Council Structure**: Governance will be divided among several specialized councils, each with a distinct mandate. This ensures that decisions are made by individuals with the relevant expertise. The target councils include:
    -   **Protocol & Strategy Council**: Oversees high-level strategic direction and protocol upgrades.
    -   **Risk & Compliance Council**: Manages risk parameters, collateral types, and compliance-related matters.
    -   **Treasury & Investment Council**: Manages the protocol treasury and directs investment strategies.
    -   **Technology & Security Council**: Oversees technical development and security best practices.
    -   **Operations & Resilience Council**: Manages the day-to-day operational health of the protocol.

-   **NFT-Based Governance Roles**: Council membership and other governance roles will be represented by unique, non-fungible tokens (NFTs). This provides a clear, on-chain representation of governance power and allows for the transfer and delegation of roles in a secure and transparent manner.

-   **The Conxian Operations Engine (`conxian-operations-engine.clar`)**: A revolutionary, automated on-chain agent that will hold a formal seat on the Operations & Resilience Council. This "DAO Seat" will:
    -   Consume on-chain metrics from across the protocol (e.g., risk parameters, treasury balances, system utilization).
    -   Aggregate these metrics into policy-constrained votes.
    -   Participate directly in governance, providing an unbiased, data-driven perspective.

## 4. Phased Transition to Decentralization

The transition from our current centralized model to the target decentralized model will occur in a series of clear, publicly communicated phases.

-   **Phase 0: Technical Alpha (Current Phase)**: Governance is centralized with the core team to ensure stability and security during initial development and testing.

-   **Phase 1: Governance Scaffolding**: The on-chain `proposal-engine.clar` will be deployed, and the multi-council NFT contracts will be created. The core team will still hold the majority of council seats, but the technical framework for the DAO will be in place.

-   **Phase 2: Community Council Delegation**: The core team will begin to delegate council seats to trusted community members and external experts. This will begin the process of distributing governance power.

-   **Phase 3: Launch of the Conxian Operations Engine**: The automated "DAO Seat" will be deployed and activated, bringing its data-driven perspective to the governance process.

-   **Phase 4: Full Decentralization**: The core team will relinquish its remaining council seats, and the protocol will be fully governed by the decentralized, multi-council DAO.

This phased approach ensures a smooth and secure transition to a truly decentralized governance model, building a foundation of trust and transparency with our community and partners.
