# Proposed Solutions & Architectural Alignment

**Date**: December 7, 2025
**Status**: For Alignment Review

Based on a comprehensive review of the codebase and industry standards (Stacks/Bitcoin DeFi, MEV patterns, and Autonomous Governance), this document outlines the proposed solutions to close the critical gaps between the **Conxian Whitepaper** and the **current Codebase**.

## 1. Routing & Pathfinding Architecture

### 🔴 The Issue

The Whitepaper claims a "Dijkstra's Algorithm... Implemented in `multi-hop-router-v3.clar`".
**Reality**: Running Dijkstra or complex graph pathfinding *on-chain* in Clarity is computationally prohibitive (exceeds block limits) and gas-inefficient. Standard DeFi practice (e.g., Uniswap, Velar, Alex) uses **Off-Chain Smart Order Routing (SOR)**.

### ✅ Proposed Solution

**Off-Chain Discovery, On-Chain Verification.**

1. **Why not full On-Chain?**:
    * **Clarity Limits**: Graph traversal (Dijkstra/BFS) requires recursion or unbounded loops, which are **not supported** in Clarity.
    * **Runtime Costs**: Even `read-only` functions have a "Runtime Execution Limit" in Stacks. A complex graph search will error out (`execution-cost-exceeded`) before finding the path.
2. **The Efficient Hybrid**:
    * **Read-Only**: The SDK (client-side) calculates the path. It is "Read-Only" because it reads the chain state without executing a tx.
    * **On-Chain Executor**: `multi-hop-router-v3.clar` receives the path. It **verifies** the path (slippage, liquidity existence) and executes it.
    * *Optional On-Chain Helper*: We can add a `get-quote(path)` read-only function that simulates the swap to show the user the exact output, but the *path itself* must be provided.
3. **Action Plan**:
    * Docs: Update Whitepaper to clarify "Off-chain path discovery via SDK; On-chain atomic verification & execution."
    * Code: Ensure `multi-hop-router-v3` has a `get-quote` read-only view for pre-tx validation.

## 2. Conxian Operations Engine (The "Brain")

### 🔴 The Issue

The "Automated DAO Seat" currently returns hardcoded `u0` for policies and uses a manual `auto-support-proposals` map. This is "Human-in-the-Loop" disguised as automation.

### ✅ Proposed Solution

**Hybrid "Guardian View" Architecture.**

1. **Architecture**:
    * **On-Chain**: `conxian-operations-engine.clar` exposes a **read-only** function: `(get-action-needed) -> (optional (tuple ...))`.
    * **Logic**: This read-only function runs all the "Daily Ops" checks (System Health OK? Treasury sufficient? Policy met?) purely as a view. **No gas cost** to query this.
    * **Execution**: An off-chain Guardian (bot) polls `get-action-needed`.
        * If `none`: Do nothing. (Cost: $0).
        * If `some`: Guardian submits the `execute-vote` transaction. (Cost: Gas fee).
2. **Action Plan**:
    * Implement `ops-policy.clar` as a library used by both the *view* and the *execute* functions.
    * This ensures "not all internal transactions carry a fee" — only the necessary ones do.

## 3. MEV Protection & Batch Execution

### 🔴 The Issue

`mev-protector.clar` handles the **Commit-Reveal** perfectly, but `execute-batch` is a state marker. It does not strictly *enforce* that the trades are executed against the DEX. A Guardian could "execute" the batch (mark it done) without actually performing the swaps.

### ✅ Proposed Solution

**Enforce Execution via Solver Pattern.**

1. **Architecture**:
    * Modify `execute-batch` to accept a **Solution Payload** (List of Swaps).
    * **Verification**: The contract checks:
        * Do these swaps match the revealed commitments in this batch?
        * Are they ordered correctly?
    * **Execution**: The contract *calls* the DEX `swap` function for each valid order in the payload.
2. **Action Plan**:
    * Update `mev-protector.clar` to call `multi-hop-router-v3` or `concentrated-liquidity-pool` directly during the `execute-batch` phase.

## 4. Unified Operational Architecture

### 🔴 The Issue

Currently, `keeper-coordinator.clar` attempts to be a centralized "Job Runner" with empty placeholders (`execute-interest-accrual`, etc.). This creates a bottleneck and high gas costs for a single tx. Meanwhile, `liquidation-manager` and `risk-manager` operate independently.

### ✅ Proposed Solution

**Registry + Polling Pattern (Decentralized Execution).**

1. **Philosophy**: The Coordinator does not *execute* tasks; it *points* to contracts that need execution.
2. **Standard Trait**: Define `automation-trait`:
    * `get-runnable-actions() -> (list action-id)`: Read-only view. Returns empty if nothing to do.
    * `execute-action(action-id)`: The public function a Guardian calls.
3. **Architecture**:
    * **`keeper-coordinator`**: Becomes a simple registry of `(list <automation-trait>)`.
    * **Guardians (Off-Chain)**:
        1. Call `keeper-coordinator.get-registry()`.
        2. Loop through contracts -> Call `get-runnable-actions()` (Read-Only, Free).
        3. If action found -> Submit tx to that specific contract.
4. **Benefits**:
    * **Gas Efficient**: No "check-all" transaction. Only necessary writes.
    * **Scalable**: New modules just register themselves; no update to coordinator logic needed.

5. **Identified Automation Candidates**:
    * **Liquidation**: `liquidation-manager` -> `get-liquidatable-positions`
    * **Ops Engine**: `conxian-operations-engine` -> `get-action-needed`
    * **Yield**: `yield-optimizer` -> `get-rebalance-needed` (Check APY drift)
    * **Derivatives**: `funding-rate-calculator` -> `get-funding-update-needed` (Periodic updates)

## 5. Documentation Updates

* **ROADMAP.md**: Add "Off-Chain SDK Development" and "Guardian Network & Automation Scaffolding" as key activities for Phase 2, and "Bonded Guardian Economics" for Phase 3.
* **NAMING_STANDARDS.md**: Confirmed aligned (CXD/CX* tokens, Guardian role naming, `-registry` / `-coordinator` / `-vault` suffixes).
* **OPERATIONS_RUNBOOK.md**: Add a section describing the Conxian Operations Engine, Guardian-based automation (via `guardian-registry`, `keeper-coordinator`, and `automation-trait`), and how ops teams monitor and intervene.
* **REGULATORY_ALIGNMENT.md**: Document the Guardian Network & Automation under Operational Resilience, including bonded CXD guardians, Hiro API-based monitoring, and slashing controls.
* **SERVICE_CATALOG.md**: List the Guardian Network & Automation SDK / reference Guardian client as an internal enabling service (initial tooling provided by Conxian, with community extensibility).
* **ENTERPRISE_BUYER_OVERVIEW.md** / **BUSINESS_VALUE_ROI.md**: Reference automated Guardian operations and CXD-funded OpEx (via service vaults) as part of the operational resilience and ROI story.
* **Whitepaper**: Clarify "Off-chain path discovery and monitoring via SDK and Hiro Core API; On-chain atomic verification & execution" and the role of the Conxian Operations Engine seat.

---

**Next Steps**:

1. Approve this architectural alignment.
2. I will generate the `ops-policy` logic.
3. I will draft the `mev-protector` execution update.
4. I will refactor `keeper-coordinator` to be a lightweight registry.
