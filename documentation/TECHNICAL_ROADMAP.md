# Conxian Technical Roadmap: The Path to Tier-1

**Date:** December 3, 2025
**Focus:** Clarinet SDK, Nakamoto Upgrade, DLCs

---

## Phase 1: Foundation & Hygiene (Weeks 1-4)

### 1.1 Clarinet SDK Migration
*   **Objective:** Move all testing infrastructure to the official `@stacks/clarinet-sdk`.
*   **Action Items:**
    1.  Install `vitest` and `@stacks/clarinet-sdk`.
    2.  Refactor `tests/*.ts` to use `simnet` instead of legacy `Chain` object.
    3.  Implement `simnet.getAssetsMap()` for precise balance assertions.
    4.  Configure `vitest.config.ts` for parallel test execution.
*   **Benefit:** 10x faster test execution, better debugging, aligned with Stacks best practices.

### 1.2 Codebase Standardization
*   **Objective:** Enforce naming conventions and directory structure.
*   **Action Items:**
    1.  Rename contracts per `NAMING_STANDARDS.md`.
    2.  Flatten `contracts/` directory or enforce strict sub-modules (`dex/`, `lending/`, `governance/`).
    3.  Consolidate traits into `contracts/traits/`.

---

## Phase 2: Nakamoto Readiness (Weeks 5-8)

### 2.1 Fast Block Optimization
*   **Objective:** Optimize contracts for 5-second block times.
*   **Action Items:**
    1.  **Remove `block-height` dependency** for time-sensitive logic (e.g., interest rates). Use `stacks-block-height` or trusted oracle timestamps if available/needed, or simply adapt APY calculations to higher block frequency.
    2.  **Review Governance Timelocks:** 144 blocks (1 day) becomes 17,280 blocks in Nakamoto. Update all constants.
    3.  **State Bloat:** Fast blocks mean more state changes. Optimize `define-map` usage to prevent cost blowup.

### 2.2 sBTC Integration (v1.0)
*   **Objective:** Native sBTC support.
*   **Action Items:**
    1.  Implement `sbtc-registry` adapter.
    2.  Build `sbtc-deposit-helper` for UI integration (generating deposit scripts).
    3.  Test `sbtc-withdraw` flow with the official sBTC developer release.

---

## Phase 3: Innovation Layer (Weeks 9-12)

### 3.1 Discreet Log Contracts (DLC)
*   **Objective:** Launch "Conxian Options" (Oracle-Free).
*   **Technical Spec:**
    *   **Contract:** `dlc-options-manager.clar`
    *   **Functionality:**
        *   `create-dlc`: Locks user BTC + Counterparty BTC.
        *   `close-dlc`: Unlocks based on Attestor signature.
    *   **Integration:** Use `dlc-link` or similar infrastructure to coordinate the off-chain setup.
*   **Use Case:** Hedging Impermanent Loss for LPs directly on Bitcoin.

### 3.2 Decentralized Identity (BNS)
*   **Objective:** Social DeFi.
*   **Action Items:**
    1.  Resolve `.btc` names in the UI.
    2.  Allow sending assets to BNS names in `transfer` functions (UI layer resolution).
    3.  **On-Chain Profile:** Map `principal -> BNS -> Reputation Score`.

---

## Phase 4: Enterprise Features (Weeks 13+)

### 4.1 Permissioned Pools (Aave Arc style)
*   **Objective:** KYC/AML Compliant DeFi.
*   **Implementation:**
    *   `permissioned-pool-trait`.
    *   `whitelist-manager.clar`: Checks for a "KYC NFT" or signed credential before allowing `supply`/`swap`.

### 4.2 Privacy (Keep Integration)
*   **Objective:** Private swaps.
*   **Research:** Evaluate tBTC or similar privacy-preserving bridges if feasible on Stacks L2.

---

## Cost/Benefit Analysis

| Feature | Cost (Dev Hours) | Benefit (Value) | ROI |
| :--- | :--- | :--- | :--- |
| **Clarinet SDK** | 40h | Stability, Speed, DevEx | **High** |
| **Nakamoto Opt.** | 20h | Usability (Fast UX) | **Critical** |
| **DLC Options** | 100h | Unique Selling Point (USP) | **Very High** |
| **Privacy** | 200h+ | Niche Market | **Low** (for now) |

---
*Authored by Conxian Autonomous Architect*
