# Conxian Naming & Standardization System

**Version:** 1.0.0
**Enforcement:** Strict
**Goal:** Eliminate ambiguity, prevent duplication, and align with Stacks Ecosystem standards.

---

## 1. Global Naming Conventions

### 1.1 Contract Naming
*   **Format:** `kebab-case`
*   **Prefixing:**
    *   Core Protocol: `conxian-{module}` (e.g., `conxian-core`, `conxian-config`)
    *   DEX Modules: `dex-{component}` (e.g., `dex-router`, `dex-pool-v1`)
    *   Lending Modules: `lending-{component}` (e.g., `lending-pool`, `lending-risk`)
    *   Traits: `{name}-trait` (e.g., `pool-trait`, `vault-trait`)
    *   Interfaces/Adapters: `{system}-adapter` (e.g., `sbtc-adapter`)

### 1.2 Function Naming
*   **Public Functions:** `verb-noun` (e.g., `add-liquidity`, `swap-tokens`)
*   **Read-Only Functions:** `get-{property}` (e.g., `get-balance`, `get-pool-state`)
*   **Private Functions:** `check-{condition}` or `calc-{value}` (e.g., `check-owner`, `calc-fee`)

### 1.3 Token Naming
*   **Fungible Tokens:** `{Symbol}-token` (e.g., `cxd-token`, `sbtc-token`)
*   **Non-Fungible Tokens:** `{Name}-nft` (e.g., `position-nft`, `insurance-nft`)
*   **LP Tokens:** `lp-{pair-name}` (e.g., `lp-sbtc-stx`)

---

## 2. Standardized SDK Primitives

We adhere strictly to the **Clarinet SDK** and **SIP Standards**. Custom "Conxian-specific" primitives should only exist where standard ones fail.

### 2.1 Fungible Tokens (SIP-010)
*   **Standard:** `sip-010-trait`
*   **Source:** `.sip-standards.sip-010-ft-trait`
*   **Prohibited:** Defining custom `ft-trait` unless extending functionality (e.g., `mintable-token-trait`).

### 2.2 Non-Fungible Tokens (SIP-009)
*   **Standard:** `sip-009-trait`
*   **Source:** `.sip-standards.sip-009-nft-trait`

### 2.3 Error Codes
*   **Standard:** `contracts/errors/standard-errors.clar`
*   **Range Allocation:**
    *   `u1000-u1999`: Authorization & Permissions
    *   `u2000-u2999`: Math & Calculation
    *   `u3000-u3999`: DEX / Pool Logic
    *   `u4000-u4999`: Lending Logic
    *   `u5000-u5999`: Governance & DAO
    *   `u6000-u6999`: Yield & Strategy

---

## 3. Current Repository Audit & Remediation Plan

### 3.1 Duplicate Traits
*   **Issue:** `defi-traits.clar` and individual trait files (e.g., `contracts/traits/pool-trait.clar`) often duplicate logic.
*   **Fix:** Centralize all shared traits into `contracts/traits/definitions.clar` OR keep strict one-file-per-trait structure.
    *   *Decision:* **One-file-per-trait** in `contracts/traits/` folder.
    *   *Action:* Deprecate monolithic `defi-traits.clar` over time.

### 3.2 Ambiguous Contracts
*   **Issue:** `yield-optimizer` vs `cross-protocol-integrator`.
    *   *Clarification:* `yield-optimizer` manages strategies. `cross-protocol-integrator` executes them.
    *   *Action:* Rename `cross-protocol-integrator` to `strategy-executor` for clarity.

### 3.3 Math Library Fragmentation
*   **Issue:** `math-lib-concentrated`, `fixed-point-math`, `precision-calculator`.
*   **Fix:** Create `conxian-math.clar` as the single source of truth for fixed-point arithmetic (Wad/Ray).

---

## 4. Implementation Guide

When adding a new feature:
1.  **Check Standards:** Does a SIP exist? Use it.
2.  **Check Primitives:** Does a Math lib function exist? Use it.
3.  **Name Correctly:** Follow the `kebab-case` and prefix rules.
4.  **Error Codes:** Register new error codes in `standard-errors.clar` to avoid collisions.

---
*Authored by Conxian Autonomous Architect*
