# Conxian SDK Strategy & Client Packages

## 1. Purpose and Scope

The Conxian SDK provides **typed, reusable client libraries** for interacting with Conxian smart contracts and supporting infrastructure. It is intended for:

- Internal protocol automation (Ops Engine, guardian tooling, StacksOrbit flows).
- Third-party integrators (frontends, enterprise systems, wallets).
- Testing and simulations (e.g. `stacks/sdk-tests`).

This document sets the **target architecture and phases** for the SDK. It does **not** introduce a breaking repo restructuring; instead it defines a path that can be implemented incrementally.

---

## 2. Design Principles

- **Type-Safe Contract Access**
  - Use TypeScript and existing tooling (`@clarigen/core`, `@clarigen/test`, `@stacks/*`) to generate typed clients for Conxian contracts.

- **Environment-Agnostic**
  - Support node environments (automation, tests, backends) first.
  - Allow browser usage for frontends where safe and appropriate.

- **Network-Aware**
  - Simple configuration for **testnet**, **mainnet** and local dev networks.
  - Use `dotenv` and conventional config files for environment selection.

- **Separation of Concerns**
  - Core stack/network utilities in one place.
  - Domain packages for DeFi, guardians, insurance, governance, etc.

- **Alignment with StacksOrbit**
  - SDK should be the **canonical way** StacksOrbit scripts and daemons talk to Conxian contracts.

---

## 3. Current State (Baseline)

- Root `package.json` already depends on:
  - `@stacks/blockchain-api-client`, `@stacks/network`, `@stacks/transactions`.
  - `@clarigen/core`, `@clarigen/test` for typed Clarity testing.
- Deployment script `scripts/sdk_deploy_contracts.ts` performs sequential contract deployment using `@stacks/transactions` and Hiro Core API.
- `stacks/sdk-tests/*.spec.ts` contain higher-level system tests and production-readiness checks that:
  - Assume convenient access to multiple contracts and network configuration.
  - Are a natural early consumer of an SDK.

The SDK strategy will **wrap and formalise** these capabilities instead of duplicating logic in each script or test.

---

## 4. Target Package Layout

The SDK will live under a new top-level `sdk/` directory (future work), structured as a set of TypeScript packages:

- **`sdk-core`**
  - Network configuration (testnet/mainnet/local).
  - Stacks client helpers (wrappers around `@stacks/network`, `@stacks/transactions`, `@stacks/blockchain-api-client`).
  - Shared types (addresses, network names, common config).

- **`sdk-defi`**
  - Typed clients for core DeFi modules:
    - DEX (factory, pools, router).
    - Lending (comprehensive lending system, interest rate model).
    - Tokens (CXD, CXVG, CXLP, CXTR, CXS).
  - Utility flows (e.g. open position, add/remove liquidity, repay/withdraw).

- **`sdk-guardians`**
  - Typed clients for:
    - `guardian-registry.clar`.
    - `keeper-coordinator.clar` and automation targets implementing `automation-trait`.
    - `wormhole-inbox.clar` (guardian-set related functions).
  - Helper flows for:
    - Guardian registration and bonding.
    - Reward claiming.
    - Slashing and rotation (where triggered by governance/ops).

- **`sdk-insurance`**
  - Clients for `insurance-protection-nft.clar` and related insurance modules.
  - Helpers for issuing policies, filing claims, and verifying proof-of-insurance.

- **`sdk-governance`**
  - Clients for governance contracts (governance token, proposal engine, voting, timelock).
  - Helpers for creating, simulating and executing proposals, including guardian/ops-related changes.

Initially, these may be implemented as **namespaces** inside a single package (e.g. `sdk-core`) before being separated into fully independent npm packages.

---

## 5. Technical Foundations

### 5.1 Contract Typings

- Use **Clarinet + Clarigen** to generate **typed contract clients** from the existing `Clarinet.toml` and contract sources.
- Each SDK package will:
  - Import generated types and clients.
  - Provide thin, well-documented wrapper functions for common flows.

### 5.2 Network and Environment Handling

- Centralise network configuration:
  - `SDK_NETWORK` env var (`testnet` / `mainnet` / `devnet`).
  - Optional `CORE_API_URL` override.
- Provide helpers for:
  - Creating Stacks network objects (`StacksTestnet`, `StacksMainnet`).
  - Selecting appropriate sender keys and addresses for different roles (deployer, guardian, treasury, etc.).

### 5.3 Error Handling and Observability

- Standardise error classes for:
  - Transaction failures.
  - Pre-flight validation errors (e.g. insufficient balance, bad parameters).
- Expose optional hooks for logging and metrics, so that StacksOrbit and external apps can integrate with their own observability stacks.

---

## 6. Integration with StacksOrbit

The SDK is designed to be shared between Conxian and **StacksOrbit**:

- **Deployment Flows**
  - `sdk-core` will provide reusable building blocks for contract deployment and registry management.
  - Future versions of `scripts/sdk_deploy_contracts.ts` can be refactored to use SDK helpers instead of direct `@stacks/transactions` calls.

- **Automation and Guardian Tooling**
  - `sdk-guardians` will be used by StacksOrbit chainhooks and cron-like jobs to:
    - Read guardian/keeper state.
    - Decide when to submit maintenance transactions.
    - File governance proposals when guardian behaviour violates policy.

- **Monitoring and Diagnostics**
  - StacksOrbit dashboards can rely on the same SDK clients to query on-chain state, ensuring consistency with production automation.

---

## 7. Phased Implementation Plan

### Phase 0 – Documentation and Baseline (Current)

- Capture the SDK vision and layout in this document.
- Confirm existing usage of `@stacks/*` and Clarigen in tests and scripts.

### Phase 1 – `sdk-core` and Test Integration

- Create a single `sdk-core` package under `sdk/` with:
  - Network configuration utilities.
  - Generated typed clients for a **small, critical subset** of contracts (e.g. core tokens, lending, guardian-registry).
- Refactor selected `stacks/sdk-tests/*.spec.ts` to use `sdk-core` for contract calls.

### Phase 2 – Domain Packages

- Split out domain-specific namespaces or packages:
  - `sdk-defi`, `sdk-guardians`, `sdk-insurance`, `sdk-governance`.
- Add ergonomic flows for higher-level operations (e.g. "open leveraged position", "register guardian and bond", "purchase protection").
- Integrate with StacksOrbit deployment and monitoring flows where appropriate.

### Phase 3 – Advanced Features

- Add helpers for:
  - Scenario simulations and strategy backtesting.
  - Guardian SLA monitoring and automatic proposal filing.
  - Enterprise-facing integration patterns (service accounts, dedicated key management hooks).

---

## 8. Open Questions and Decisions to Track

- **Monorepo vs single package**
  - Whether to publish separate npm packages (`@conxian/sdk-core`, `@conxian/sdk-defi`, etc.) or expose them as subpaths from a single package.

- **Security model for private keys**
  - When used by StacksOrbit or enterprise backends, private keys must be managed by **HSMs, custodians or secure vaults**, not hard-coded.

- **Browser support**
  - Exact browser support level and how to integrate with wallet providers using the same SDK primitives.

- **Formal versioning and stability**
  - Decide when to adopt semantic versioning and deprecation policies for SDK interfaces.

This strategy should be revisited as the Conxian protocol and StacksOrbit mature, and updated once the initial `sdk-core` implementation is in place.
