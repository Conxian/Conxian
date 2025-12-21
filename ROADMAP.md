# Roadmap

## Overview

This roadmap outlines the development phases and status of the Conxian Protocol.
The project is currently in the **Stabilization & Alignment Phase**, with a focus
on correctness, security, governance architecture, and alignment with
regulatory-style objectives.

The phases below incorporate the agreed recommendations around:

- Governance councils and role NFTs.
- The Conxian automated operations seat ("Conxian Operations Engine").
- Metrics and monitoring for LegEx / DevEx / OpEx / CapEx / InvEx style
  domains.
- NFT-based position representations and service vaults.

## Phase 0: Technical Alpha & Nakamoto Alignment (Current Phase)

- **Objective**: Solidify the protocol's foundation by aligning all core components with the modular, facade-based architecture and ensuring full compatibility with the upcoming Stacks Nakamoto upgrade. This phase is about building a stable, future-proof base for all subsequent development.

- **Key Activities**:
  - **Nakamoto Compatibility**:
    - Audit all contracts for dependencies on `block-height` for time-based logic and rescale constants to align with faster block times.
    - Transition long-term logic to `burn-block-height` where appropriate.
    - Deprecate the custom BTC bridge and integrate the official, native sBTC protocol.
  - **Architectural Alignment**:
    - Refactor the `enterprise-facade.clar` from a prototype into a true facade, delegating logic to specialized manager contracts.
    - Solidify the `proposal-engine.clar` as the central facade for governance and clearly define the interfaces for its manager contracts.
  - **Documentation Overhaul**:
    - Complete the comprehensive documentation alignment to ensure all `README.md` files and strategic documents accurately reflect the current state and target architecture of the protocol.
  - **Testing Enhancements**:
    - Configure the test environment to simulate Nakamoto block times.
    - Expand test coverage to validate the refactored enterprise and governance modules.

## Phase 1: Feature Hardening & Security (Planned)

- **Objective**: Move the protocol from a "Technical Alpha" to a "Beta" stage by hardening all existing features, expanding security measures, , launching full retail mainnet and preparing for a formal audit for enterprise 

- **Key Activities**:
  - **Contract Hardening**:
    - Implement a production-grade `get-health-factor` in the lending module.
    - Complete the core math for the `concentrated-liquidity-pool.clar`.
    - Harden all temporary stubs and controller hooks identified in Phase 0.
  - **Testing Infrastructure**:
    - Achieve comprehensive test coverage for all core modules, including economic and security stress tests.
    - Harden the Vitest-based test harness for reliable execution of all test suites.
  - **Security & Monitoring**:
    - Implement and test advanced security features, including MEV protection, a robust circuit breaker, and oracle failure modes.
    - Prepare detailed architecture diagrams and threat models for an external security review.

## Phase 2: Advanced Governance & Feature Completion (Planned)

- **Objective**: Finish core protocol features and complete the governance /
  operational architecture so that Conxian can operate with a clear "board and
  automated executive" model.

- **Key Activities**:

  - **Lending & Risk Module**
    - Implement a production-grade `get-health-factor` in
      `comprehensive-lending-system.clar`, aligned with the risk and
      liquidation engines.
    - Complete and integrate `liquidation-manager.clar` /
      `liquidation-engine.clar` for consistent margin checks and liquidations.
    - Extend the existing risk and liquidation tests into full cross-module
      scenarios that bridge lending, oracle, circuit breaker, and liquidation
      behavior, including enterprise-style credit lines.

  - **DEX Module**
    - Complete `concentrated-liquidity-pool.clar` and its core math.
    - Integrate `dijkstra-pathfinder.clar` with `multi-hop-router-v3.clar` for
      efficient routing across pools.
    - Ensure DEX fee flows are fully routed through `protocol-fee-switch.clar`.

  - **Tokens & Emission Module**
    - Enable and harden integration hooks in `cxd-token.clar` for
      system-controller and emission-controller usage, subject to Clarity
      constraints.
    - Complete `token-system-coordinator.clar` behavior and tests for
      cross-token coordination and system health views.
    - Ensure `token-emission-controller.clar` is the canonical emission rail
      for CXD, CXVG, CXTR, and related tokens.

  - **Governance Councils & Role NFTs**
    - Implement or refine council types and roles in
      `enhanced-governance-nft.clar` to match `NAMING_STANDARDS.md`:
      - Protocol & Strategy Council
      - Risk & Compliance Council
      - Treasury & Investment Council
      - Technology & Security Council
      - Operations & Resilience Council
    - Ensure metadata for council membership NFTs uses descriptive,
      regulatory-friendly labels (e.g., `risk-and-compliance-council-member`).

  - **Conxian Automated Operations Seat**
    - Design and implement `conxian-operations-engine.clar` with **deterministic on-chain policy logic**:
      - Replace manual voting maps with `ops-policy.clar` library.
      - Reads metrics from `token-system-coordinator.clar`, risk/treasury
        contracts, circuit breaker, and oracle modules.
      - Aggregates LegEx / DevEx / OpEx / CapEx / InvEx-style inputs.
      - Holds an Operations & Resilience Council membership NFT.
      - Casts votes via `proposal-engine.clar` as an on-chain contract
        principal.
    - Add governance tests to assert that the Conxian Operations Engine seat
      can participate in voting and that its policy respects risk and
      regulatory guardrails.

  - **Guardian Network & Automation Scaffolding**
    - Design and implement `guardian-registry.clar` for managing Guardian roles and bonding in CXD.
    - Wire `keeper-coordinator.clar` and automation targets to enforce Guardian checks via a shared `automation-trait`.
    - Add baseline tests for Guardian registration, bonding/unbonding, and basic misbehavior cases.

  - **Position NFTs & DAO Role NFTs**
    - Design NFT schemas and traits for:
      - LP position NFTs that wrap CXLP balances (SIP-010) into SIP-009
        position tokens.
      - Lending / perpetual position NFTs, where appropriate.
      - DAO role NFTs (council seats, guardians, specialized veto roles) that
        align with the council structure.
    - Ensure these NFTs integrate cleanly with the existing token system,
      emission controls, and governance modules.

  - **Service Vaults & Treasury / Fee Routing**
    - Design a "service vault" pattern for holding CXD (and possibly CXTR) to
      pay for on-chain / off-chain services (e.g., bridges, oracles,
      infrastructure providers).
    - Align service vaults and protocol fee distribution with the patterns
      described in `TREASURY_AND_REVENUE_ROUTER.md` as they are implemented.
    - Implement one or more vault contracts governed by the Treasury &
      Investment and Operations & Resilience councils, with clear budget and
      withdrawal policies.

  - **Security Audit Preparation**
    - Prepare architecture diagrams, threat models, and documentation to
      support an external security review of the full system, including the
      governance and Conxian Operations Engine design.
    - Keep the CHANGELOG, SERVICE_CATALOG, ENTERPRISE_BUYER_OVERVIEW, and
      BUSINESS_VALUE_ROI documents aligned with the actual deployed contracts,
      test coverage, and current testnet-only status.

## Phase 3: Scenario Testing, Stress & Regulatory Formalization (Planned)

- **Objective**: Prove system robustness via end-to-end scenarios and formal
  alignment of on-chain behavior with regulatory-style objectives.

- **Key Activities**:
  - **Cross-Domain Scenario Testing**
    - Implement multi-step economic scenarios that chain DEX, lending,
      protocol fees, and insurance (e.g., stress trades leading to lending
      stress and fee/insurance flows).
    - Test oracle failures, circuit breaker activation, and incident
      playbooks end-to-end.
  - **Governance & Council Behavior**
    - Add tests for quorum, proposal lifecycle, council-based permissions, and
      the impact of the Conxian Operations Engine seat on governance outcomes.
  - **Bonded Guardian Economics**
    - Scenario-test Guardian reward and slashing parameters (bond sizes in CXD, rewards per action, slashing amounts).
    - Validate that Guardian incentives remain aligned with protocol safety under stress scenarios.
  - **Regulatory Alignment Extensions**
    - Extend `REGULATORY_ALIGNMENT.md` with more concrete mappings from
      specific contracts and tests to regulatory-style objectives and stress
      scenarios.
    - Add references to council responsibilities and how they support
      oversight (Risk & Compliance, Treasury & Investment, Operations &
      Resilience, etc.).
  - **Metrics & Dashboards**
    - Extend `token-system-coordinator.clar` and/or add an
      `operations-metrics-registry.clar` to provide structured, read-only
      dashboards for LegEx / DevEx / OpEx / CapEx / InvEx domains.

## Phase 4: Mainnet Launch (Planned)

- **Objective**: Launch the Conxian Protocol on Stacks mainnet with a
  production-ready governance and operational model.

- **Key Activities**:
  - **Deployment**
    - Deploy all core contracts (tokens, DEX, lending, governance, risk,
      oracles, monitoring, councils, Conxian Operations Engine, service
      vaults) to mainnet.
  - **Governance Bootstrapping**
    - Initialize the Conxian Protocol DAO with council membership NFTs,
      including the Conxian Operations Engine seat.
    - Publish an initial governance and incident-response playbook.
  - **Web Application & Tooling**
    - Launch the official web application with dashboards for users, council
      members, and regulators/observers.
    - Provide tooling for proposal creation, voting, and council oversight.
  - **Security Audit & Bug Bounty**
    - Complete an external security audit based on the Phase 2 preparation
      work.
    - Initiate a bug bounty program to incentivize community involvement in
      securing the protocol.
