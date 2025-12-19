## Objectives

- Achieve full **Clarity 4 / Nakamoto** alignment across all contracts, traits, and manifests.
- Eliminate all compile errors and deprecations by migrating to Clarity 4–native idioms and functions.
- Enforce canonical trait usage and manifest-driven deployment for non-interactive `clarinet check`.
- Introduce Clarity 4–specific security patterns (`contract-hash`, `restrict-assets`, `to-ascii`, native post-conditions) where they materially improve correctness and safety.
- Verify each subsystem (DEX, CLP, lending, governance, interoperability) via compile gates and focused unit/integration tests.
- Keep the architecture minimal, idiomatic, and auditable while updating documentation and artifacts as part of the flow.

---

## Phase 1: Canonical Traits, Manifests & Nakamoto Layout

- Normalize all `(use-trait ...)` references to canonical entries in `Clarinet.toml` and enforce a **single source of truth**:
  - `sip-010-ft-trait` → `.sip-010-ft-trait.sip-010-ft-trait`
  - `rbac-trait` → `.base-traits.rbac-trait`
  - `pausable-trait` → `.base-traits.pausable-trait`
  - `circuit-breaker-trait` → `.monitoring-security-traits.circuit-breaker-trait`
  - `oracle-aggregator-v2-trait` → `.oracle-aggregator-v2-trait.oracle-aggregator-v2-trait`
- Remove or refactor any `.traits folder.*` and `.traits.*` references that are not registered, replacing them with canonical trait contracts.
- Standardize token/governance trait usage (SIP‑010, SIP‑009, RBAC, pausable, monitoring) across:
  - `contracts/tokens/**`
  - Governance, rewards, and emission modules
- Align project structure with **Nakamoto-native Clarinet** conventions:
  - Use scoped manifests per subsystem (DEX, CLP, lending, governance, interoperability).
  - Prefer `Clarinet.toml` + `Deployments.toml` over ad-hoc environment assumptions.
- Ensure fully **non-interactive** compilation:
  - Use `clarinet check` with pre-populated deployment plans, or
  - Use `clarinet check --manifest-path <scoped-manifest>` for subsystem-specific gates.

---

## Phase 2: High-Impact Compile Blockers (Clarity 4 Corrections)

- `dex-factory-v2.clar`:
  - Replace `map-to-list` and other removed idioms with supported Clarity 4 patterns
  (e.g., maintaining registry lists, iterating keys via helper functions).
  - **Clarity 4 Enhancement**: Implement `get-all-pool-types` and `get-all-pools` using
  `to-ascii` where string representations are needed, favoring readable, bounded outputs.
- Token modules (e.g., `cxd-token.clar` and related SIP‑010 FTs):
  - Fix SIP‑010 imports to canonical contracts.
  - Ensure trait signatures match SIP‑010, including:
   `get-balance`, `transfer`, `transfer-memo`, `get-total-supply`, `get-decimals`,
    and any SIP‑010 extensions actually used.
- `math_lib_advanced.clar`:
  - Remove duplicate `log2` or conflicting math
    routines.
  - Normalize function names and signatures
    referenced by CLP, router, lending,
    and liquidation engines.
    `mev-protector.clar`
  - Remove or refactor lambda-style mapping and
    `.utils.encoding` calls that are not Clarity 4–compatible.
  - Replace with named helper functions and explicit,
    supported encoding/decoding patterns 
    (e.g., tuples, fixed-width buffers).
- `external-oracle-adapter.clar`:
  - Fix list and tuple expressions that fail to parse on Clarity 4 (e.g., missing closing elements).
  - Correct trait imports (`.oracle-trait`, `.sip-010-ft-trait`) to point to the canonical entries in `Clarinet.toml`.
- `sbtc-integration.clar`:
  - Fix `match` arms so all branches return the **same** `(response ...)` type.
  - Ensure interoperable calls use explicit error codes and match trait contracts used by the rest of the lending/bridging stack.
- `access/traits/access-traits.clar`:
  - Correct any type spec parse errors (for example around `initial-owner` and authority roles).
  - Validate that trait methods (grant, revoke, has-role, owner checks) are well-typed, minimal, and used consistently across access-controlled modules.
- Modules previously referencing `.traits folder` (e.g., `budget-manager.clar`, `pools/tiered-pools.clar`):
  - Replace with canonical trait paths and register missing trait contracts.
  - Ensure trait implementation contracts compile under Clarity 4 and pass `clarinet check`.
- Governance (proposal and voting flows):
  - Replace non-supported event macros with `print` (structured tuples) consistent with Clarity 4 logging.
  - Ensure `has-voting-power` and similar functions return the expected response/boolean type, compatible with all call sites.
  - Verify `asserts!` and state updates are sequenced to avoid partial updates and non-deterministic behavior.

---

## Phase 3: Router v3 – Nakamoto-Native Pathfinding & Safety

- **Clarity 4 / Nakamoto Security**:
  - Wrap external swap paths with `restrict-assets`
    post-conditions
  (or equivalent manifest-level protections) to
    ensure swaps cannot leak or misdirect assets across contracts.
  - Use explicit post-condition principals and
    allowed asset deltas per hop.
- Pathfinding & Execution:
  - Implement neighbor discovery via Factory v2 (`get-pool` over known token pairs)
    to construct an adjacency list.
  - Implement Dijkstra (distance and predecessor  
    maps) using non-mutating reconstruction patterns
    (e.g., functional updates over maps/lists).
  - Implement minimal caching for common pairs
    (in-memory via contract storage) with explicit invalidation on pool creation/removal.
- Testing:
  - Add unit tests and targeted integration tests for:
    - Single-hop swaps
    - Multi-hop swaps
    - Slippage guards and hop limits
    - Failure paths with `restrict-assets` active (post-condition violations, insufficient liquidity).

---

## Phase 4: Concentrated Liquidity Pool (CLP) Tick Math & Liquidity – Clarity 4 Integrity

- **Clarity 4 Integrity Check**:
  - Integrate `contract-hash` checks so dependent contracts (router, lending, governance) can verify the CLP contract identity before interaction.
  - Expose a helper that returns the CLP `contract-hash` for external verification when required by subsystem manifests.
- Tick Math & Liquidity:
  - Implement `get-sqrt-price-from-tick` and `get-tick-from-price` via `math-lib-concentrated`, using well-bounded integer math and overflow-safe patterns.
  - Implement `add-liquidity` / `remove-liquidity`, managing:
    - Liquidity deltas
    - Fee growth inside tick ranges
    - Position accounting
  - Implement position NFT lifecycle (mint, update, burn) using canonical SIP‑009 interfaces where applicable.
- Testing:
  - Add unit tests for:
    - Tick ↔ price conversion round-trips
    - Liquidity addition/removal across different ranges
    - Fee growth accrual and distribution.

---

## Phase 5: Lending Helpers, Health Factor & PoR

- Lending Helpers:
  - Implement `check-not-paused` using the canonical `pausable-trait`.
  - Implement `accrue-interest` to update debt and reserve indices over time.
  - Implement `get-asset-price-safe` using canonical oracle traits (and fallback logic where needed).
- Health & Proof of Reserves:
  - Implement health factor math consistent with the lending protocol’s risk engine (collateralization ratios, liquidation thresholds).
  - Integrate PoR enforcement, cross-checking positions against oracle and CLP pricing.
- Testing:
  - Add tests for full lending lifecycle:
    - Supply / borrow / repay flows
    - Health factor degradation and improvement
    - Liquidation paths under different collateral and price conditions
    - PoR checks and failure modes.

---

## Phase 6: Governance & Tokens – SIP‑010 / SIP‑009 Compliance Under Clarity 4

- Traits & Implementations:
  - Normalize all token trait usage to canonical SIP‑010 (FT) and SIP‑009 (NFT) traits.
  - Fix governance token principal references (consistent contract IDs across manifests and runtime).
- Governance Flows:
  - Validate that proposal creation, voting, and execution use Clarity 4–compatible patterns (explicit responses, no removed macros).
  - Ensure voting power is derived from canonical token contracts and is queryable via well-typed public functions.
- Testing:
  - Add tests for:
    - SIP‑010 transfers, approvals, and failure cases.
    - Governance proposal lifecycle (create, queue, vote, execute, cancel).
    - Edge conditions (no quorum, invalid timing, revoked voting power).

---

## Phase 7: Manifests, Compile Gates & System-Wide Verification

- Manifest Strategy:
  - Expand and maintain manifest files per subsystem:
    - DEX + router
    - CLP + tick math
    - Lending + liquidation + PoR
    - Governance + tokens
    - Interoperability / oracle adapters
  - Prefer minimal, self-contained manifests for faster iteration and CI gating.
- Compile Gates:
  - Run `clarinet check` non-interactively per manifest to gate changes:
    - Fail fast at subsystem level before full-system checks.
  - Progressively aggregate manifests into a full-system deployment manifest.
- Documentation & Capability Matrix:
  - Record results of each compile gate and test suite in a capability matrix.
  - Update documentation with:
    - Clarity 4 / Nakamoto support status
    - Trait and manifest versions
    - Known limitations and extension points.

---

## QA & Acceptance Criteria

- Every contract module:
  - Compiles cleanly under **Clarity 4 / Nakamoto** with zero errors or deprecated features.
  - Has passing unit tests for its core responsibilities.
- Subsystem & System:
  - Each subsystem manifest passes `clarinet check` non-interactively.
  - The full-system manifest passes `clarinet check` with zero errors.
- Operational Readiness:
  - Docs updated with:
    - Version metadata, contract addresses, and trait mappings.
    - Architecture overview reflecting Clarity 4 / Nakamoto-native structure.
  - Handover checklists completed, including deployment and rollback considerations.

---

## Sequence

1. Canonical traits, manifests, and Nakamoto-native project layout.
2. Targeted compile blockers and Clarity 4 compatibility fixes (tokens, factory, math libs, oracle adapter, MEV, governance).
3. Router v3 completion with `restrict-assets` protections and pathfinding tests.
4. CLP implementation (tick math, liquidity, NFTs) with `contract-hash` integrity checks and tests.
5. Lending and health factor stabilization with PoR enforcement and end-to-end tests.
6. Governance and token compliance under SIP‑010/SIP‑009 with Clarity 4 semantics.
7. Manifest expansion, aggregate system manifest, and final compile gate.

---

## Notes

- Prefer **minimal, explicit, and idiomatic** Clarity 4 code:
  - Avoid unsupported macros, lambdas, or legacy patterns.
  - Use explicit types, responses, and structured `print` logs.
- Keep all checks non-interactive and wired into CI.
- Update manifests, documentation, and artifacts incrementally at each gate to preserve an auditable migration path to **full Clarity 4 / Nakamoto-native architecture**.
