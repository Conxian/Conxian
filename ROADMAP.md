# Roadmap

## Overview

This roadmap outlines the development phases and status of the Conxian Protocol. The project is currently in the **Stabilization Phase**, with a focus on ensuring the correctness, security, and alignment of all contracts and documentation.

## Phase 1: Stabilization and Documentation (In Progress)

- **Objective**: To create a solid foundation for the protocol by ensuring that all existing code is well-documented, secure, and aligned with the modular architecture.
- **Key Activities**:
  - Comprehensive documentation of all smart contracts.
  - Alignment of all `README.md` files with the current state of the code.
  - Identification and remediation of any critical security vulnerabilities.
  - Implementation of a comprehensive test suite.

## Phase 2: Feature Completion and Testing (Planned)

- **Objective**: To complete the implementation of all core features and to conduct thorough testing to ensure the protocol is production-ready.
- **Key Activities**:
  - **Lending Module**:
    - Implement the `get-health-factor` function in the `comprehensive-lending-system.clar` contract.
    - Complete the implementation of the `liquidation-manager.clar` contract.
  - **DEX Module**:
    - Complete the implementation of the `concentrated-liquidity-pool.clar` contract.
    - Integrate the `dijkstra-pathfinder.clar` contract with the `multi-hop-router-v3.clar`.
  - **Tokens Module**:
    - Enable the integration hooks in the `cxd-token.clar` contract.
    - Complete the implementation of the `token-system-coordinator.clar` contract.
  - **Security Audit**: Conduct an external security audit of the entire codebase.

## Phase 3: Mainnet Launch (Planned)

- **Objective**: To launch the Conxian Protocol on the Stacks mainnet.
- **Key Activities**:
  - **Deployment**: Deploy all smart contracts to the mainnet.
  - **Web Application**: Launch the official web application.
  - **Bug Bounty**: Initiate a bug bounty program to incentivize community involvement in securing the protocol.
