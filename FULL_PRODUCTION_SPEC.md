# Conxian Protocol: Full Production Specification & Architecture Guide

**Version:** 1.0.0  
**Date:** November 30, 2025  
**Status:** Living Document  
**Vision:** Full Production, Hexagonal, Modular, Multi-Dimensional DeFi on Stacks/Bitcoin.

---

## 1. Executive Summary & Vision

Conxian is a Bitcoin-native, multi-dimensional DeFi protocol built on Stacks. It aims to provide institutional-grade financial primitives (Lending, DEX, Derivatives) with a focus on **modularity**, **security**, and **compliance**.

**Core Philosophy:**

* **Hexagonal Architecture (Ports & Adapters):** Core domain logic (`contracts/core`, `contracts/dimensional`) is isolated from external dependencies (Oracles, Tokens, UI) via **Traits** (Ports) and **Contracts** (Adapters).
* **Decentralization:** No single point of failure; decentralized governance and oracle aggregation.
* **Production Readiness:** Zero compilation errors, >90% test coverage, comprehensive auditing, and strict adherence to Clarity constraints.
* **Agent-Driven Development:** The codebase is structured to be easily parsed, understood, and modified by AI agents (`stacksorbit`), with clear "Agents.md" alignment.

---

## 2. Architecture: Hexagonal & Modular

The system is organized into distinct layers to ensure loosely coupled, highly cohesive components.

### 2.1 The Core (Domain Logic)

* **Location:** `contracts/core/`, `contracts/dimensional/`
* **Responsibility:** Pure business logic (Positions, Health Factors, Risk Calculations).
* **Constraints:** Should depend *only* on Traits, not specific external contracts.
* **Example:** `dimensional-core.clar` manages position state but asks `oracle-trait` for prices.

### 2.2 The Ports (Traits)

* **Location:** `contracts/traits/`
* **Responsibility:** Define the interfaces for external interaction.
* **Key Traits:**
  * `oracle-trait`: Price feeds.
  * `sip-010-trait`: Tokens.
  * `risk-management-trait`: Risk parameters.
* **Rule:** All inter-module communication MUST go through these traits.

### 2.3 The Adapters (Implementations)

* **Location:** `contracts/oracle/`, `contracts/dex/`, `contracts/tokens/`
* **Responsibility:** Implement the Traits to provide real functionality.
* **Examples:**
  * `oracle-aggregator-v2.clar` implements `oracle-trait` using a weighted average strategy.
  * `sbtc-oracle-adapter.clar` adapts sBTC price feeds to `oracle-trait`.

---

## 3. Clarity Constraints & Design Patterns

To achieve "Full Production" status, we must adhere to strict Clarity limitations found during research (docs.hiro.co).

### 3.1 The "Read-Only Trait" Limitation

**Constraint:** A `define-read-only` function cannot call a `contract-call?` on a Trait. Clarity assumes all dynamic calls are potentially state-changing.
**Impact:** Pure "View" functions (like `get-health-factor`) that need external data (Prices) cannot be `read-only` if they use Traits for modularity.
**Pattern for Production:**

1. **Public Views:** Define these functions as `define-public`.
    * *Pros:* Fully modular (can use Traits).
    * *Cons:* Requires a transaction if called on-chain; "simulated" read-only off-chain.
    * *Usage:* The UI/API calls them via the `read_only` endpoint, simulating a transaction.
2. **Private Helpers:** If the logic is used internally by a transaction (e.g., `liquidate-position`), make the helper `define-private`.

### 3.2 Monolith Avoidance

**Constraint:** Contracts should be focused and small (< 1000 lines preferred) to avoid "Contract Size Exceeded" errors and ensure auditability.
**Status:** `comprehensive-lending-system.clar` is growing.
**Action:** Split logic into `lending-core`, `lending-storage`, and `lending-actions` if it exceeds complexity limits.

---

## 4. Current Status vs. Vision (Gap Analysis)

| Feature | Current Status | Vision | Action Required |
| :--- | :--- | :--- | :--- |
| **Compilation** | ~20 Errors (Semantic/Trait) | 0 Errors (Clean) | Resolve trait mismatches in Risk/Lending. |
| **Oracle Integration** | Mixed (Direct vs Trait) | 100% Trait-based | Refactor `dimensional-core` to strict Trait usage (Done). |
| **Health Checks** | `read-only` (Broken) | `public` (Simulated View) | Applied fix to `dimensional-core`. Apply to `lending`. |
| **Security** | Internal Drafts | Full Audit Suite | Implement automated property tests. |
| **Docs** | Extensive but Scattered | Unified "Spec" | This document serves as the central anchor. |

---

## 5. Implementation Plan (Refactoring Roadmap)

### Phase 1: Critical Fixes (Immediate)

1. **Fix Read-Only Violations:**
    * Scan all `define-read-only` functions.
    * If they use `contract-call? <trait>`, convert to `define-public` or `define-private`.
2. **Align Traits:**
    * Ensure `oracle-trait`, `liquidity-pool-trait`, and `flash-loan-trait` are consistent across all implementations.

### Phase 2: Modular Hardening (Week 1)

1. **Decouple `comprehensive-lending-system`:**
    * Verify it doesn't hardcode oracle dependencies.
    * Ensure it uses `risk-manager-trait`.
2. **Standardize Error Codes:**
    * Move all errors to `contracts/traits/trait-errors.clar` or a shared constant contract.

### Phase 3: "Full Spec" Verification (Week 2)

1. **Agent Verification:**
    * Use `stacksorbit` to auto-verify that every contract in `Clarinet.toml` implements its declared traits.
2. **Network State Sync:**
    * Ensure `contracts/oracle` has a "mock" mode for local devnet that mimics Mainnet state (prices).

---

## 6. Agent & Tooling Alignment

* **`stacksorbit`:** The deployment tool must support "Dry Run" deployments that verify trait compliance before broadcasting.
* **`AGENTS.md`:** Agents must check `FULL_PRODUCTION_SPEC.md` before proposing architectural changes.
* **API:** The Conxian UI must be updated to handle "Public View" functions (using `callReadOnly` on public functions) instead of assuming they are native read-only.
