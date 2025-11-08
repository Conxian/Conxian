# Conxian Protocol — A Multi‑Dimensional DeFi System on Stacks (Nakamoto)

Version: 0.9 (Draft)
Status: Public Draft (Not a security audit)

## Abstract

Conxian is a Bitcoin‑anchored, multi‑dimensional DeFi protocol deployed on Stacks (Nakamoto). It unifies concentrated liquidity pools, a tenure‑aware routing engine, oracle aggregation with manipulation detection, and an enterprise‑grade compliance layer. The system is designed around deterministic encodings, centralized trait governance, and Bitcoin‑finalized operations. This whitepaper presents the architectural principles, protocol mechanics, security model, compliance posture, and roadmap aligned to Clarinet SDK 3.9+ and the Nakamoto Standard.

## 1. Motivation

- Fragmented liquidity, inconsistent encodings, and non‑deterministic ordering lead to fragility in on‑chain execution.
- Cross‑chain execution, institutions, and regulations require modular compliance that preserves permissionless retail flows.
- Bitcoin finality (via Stacks) enables credible neutrality and transparent settlement guarantees.

Conxian addresses these by building a protocol where determinism, auditability, and Bitcoin‑anchored finality are first‑class design constraints.

## 2. Design Principles

- Determinism by construction
  - Centralized trait imports/implementations via `.all-traits.<trait>`.
  - Canonical encoding with `sha256 (to-consensus-buff payload)`.
  - Deterministic token ordering via admin‑managed `token-order` maps.
- Bitcoin finality & Nakamoto integration
  - Use `get-burn-block-info?` (≥ 6 conf), `get-tenure-info?`, and `get-block-info?` via centralized block utilities.
  - Tenure‑aware pricing (TWAP), ordering, and execution windows.
- Safety‑first defaults
  - Pausable/circuit‑breaker guards, explicit error codes (u1000+), minimized implicit casts.
- Separation of concerns
  - Spatial (liquidity & routing), Temporal (tenure/TWAP), Risk (vol surfaces/VAR), Cross‑Chain (interoperability), Institutional (compliance hooks).
- Compliance without compromise
  - Modular enterprise controls; retail paths remain permissionless and transparent.

## 3. System Architecture Overview

- Traits & Policy
  - `contracts/traits/all-traits.clar` is the single source of truth. Contracts must reference traits via `.all-traits.*`.
- Utilities
  - Encoding: canonical `to-consensus-buff` + `sha256` for payload hashing.
  - Block utilities: wrappers for `get-burn-block-info?`, `get-tenure-info?`, `get-block-info?` (Nakamoto tenure support).
- Core Components
  - Concentrated Liquidity Pools (Q64.64 math, sqrt-price-x96 semantics) and pool factory.
  - Advanced Dijkstra Router with tenure‑aware path validation and deterministic route hashing.
  - Unified `dimensional-engine`: Consolidates position management, risk, lending, DEX, and oracle logic.
  - MEV Protection: commit‑reveal, batch auctions, sandwich detection.
  - Proof of Reserves (PoR): on‑chain attestation verification using Merkle proofs.
  - Interoperability: Wormhole inbox/outbox and governance/PoR handlers.
  - Institutional Layer: access control, role NFTs, compliance hooks with DID/ZK extensibility.

## 4. Spatial Dimension — Liquidity, Pricing, Positions

- Pools
  - Concentrated liquidity with ticks and sqrt‑price math (Q64.64). Position NFTs (SIP‑009) represent liquidity ranges.
  - Stable and weighted pools complement concentrated pools for different asset pairs and invariants.
- Factory & Registry
  - Deterministic token ordering via `token-order` maps. Pools are registered with current tenure and Bitcoin anchor metadata.
- Router
  - Advanced Dijkstra router computes optimal paths across heterogeneous pools. Route hashes are computed via `sha256 (to-consensus-buff route-data)` to ensure deterministic replay and auditability.

## 5. Temporal Dimension — Tenure‑Aware Analytics

- Tenure‑weighted TWAPs using `get-tenure-info?` for sub‑second block regimes in Nakamoto.
- Time‑decayed functions for position updates, routing slippage bands, and volatility estimates.
- Staleness guards across oracles and PoR attestation consumption.

## 6. Risk Dimension — Controls & Measurement

- Volatility surfaces and implied volatility support (planned) using deterministic numeric primitives.
- Health factor monitoring, keeper‑incentivized liquidations, and configurable caps/limits per pool.
- Circuit breaker integration across pricing, routing, and enterprise flows.

## 7. Cross‑Chain Dimension — Interoperability & Finality

- Interoperability (Wormhole)
  - Inbox: idempotent message acceptance tied to guardian‑set index; replay protection and event logging.
  - Outbox: outbound intent registry for relayers; explicit event emission for monitoring.
  - Governance/PoR handlers: controlled dispatch respecting local timelocks and compliance gates.
- Bitcoin Finality
  - System relies on Stacks’ Bitcoin settlement. Critical state transitions may require ≥ 6 burn‑block confirmations.

## 8. Institutional Dimension — Compliance & Governance

- Access Control
  - Role‑based modules, pausable guards, timelocks; error codes standardized (u1000+).
- Compliance Hooks (Enterprise)
  - Modular KYC/KYB, sanction screening, and DID+ZK attestations. Retail remains permissionless; whale activity ≥ 100 BTC equivalent triggers enterprise path.
- Governance
  - Proposal engine (trait‑driven), timelock controller, and audit registry integrations to steer policy upgrades.

## 9. Proof of Reserves (contracts/security/proof-of-reserves.clar)

- Per‑asset attestation: Merkle root, total reserves, auditor, version, and timestamps.
- Verification reconstructs root from leaf+proof; staleness guard prevents outdated attestations.
- Monitoring emits on‑chain events; optional hooks extend observability.

## 11. MEV Protection Layer

- Commit‑reveal schemes for sensitive flows, with commitment hashes computed via `sha256 (to-consensus-buff commitment)`.
- Batch auctions ordered by tenure to reduce latency‑induced arbitrage.
- Pattern matching for sandwich detection; breaker hooks for automated throttling.

## 12. Token Standards & Traits

- SIP‑009 NFTs for positions and roles; SIP‑010 FTs for tokens and accounting.
- All trait imports/implementations reference `.all-traits.*` with no principal‑qualified identifiers.
- Deterministic order maps replace principal serialization comparisons.

## 13. Deterministic Encoding & Ordering

- Encoding
  - Canonical buffer production via `to-consensus-buff` only; hashed using `sha256` or `sha512/256`.
  - No deprecated conversions; avoid non‑canonical principal encoding.
- Ordering
  - Owner‑managed `token-order` map ensures deterministic pool factory behavior across deployments.

## 14. Observability & Metrics

- Standardized event schema for liquidity depth, route performance, oracle freshness, breaker transitions, and compliance gates.
- Dashboards consume on‑chain events; chainhooks/relayers can trigger off‑chain workflows (e.g., institutional operations).

## 15. Security Model

- Threat Model
  - Price manipulation, route congestion, replayed cross‑chain messages, misconfigured traits/manifests, and key compromise.
- Mitigations
  - Manipulation detection + TWAP fallback, tenure‑aware path validation, Wormhole idempotency, centralized traits.
  - Circuit breaker/pausable controls; strong error codes and strict argument validation.
- Formalism & Verification (Ongoing)
  - Invariant checks, response typing audits, trait compliance tests, and static banned‑function scans.

## 16. Governance & Upgradability

- Parameter changes via governance proposals and timelocks; new deployments rather than in‑place upgrades.
- Audit registry integration for transparent policy and code provenance.

## 17. Implementation & Manifests

- Clarinet Manifests
  - Root `Clarinet.toml` is canonical. Test/foundation manifests under `stacks/` support harnesses.
  - Consolidated `[contracts.all-traits]` and consistent deployer addresses across manifests.
- CI & Pre‑commit
  - Vitest‑based trait policy test ensures `.all-traits.*` usage. `clarinet check` is required pre‑merge.
  - Secret management: `.env` files are gitignored; wallet derivation via scripts (no secrets in manifests).

## 18. Testing & Benchmarking

- Unit & Integration
  - Router path correctness, pool invariants, oracle manipulation detection, PoR verification, and compliance gates.
- Performance & Load
  - Benchmarks for route computation latency, quote accuracy, and liquidity depth under stress.
- Interop Round‑Trip
  - Inbox/outbox idempotency, governance/PoR handler dispatch, and guardian‑set version enforcement.

## 19. Economics & Incentives (High‑Level)

- Liquidity Provision
  - Concentrated liquidity positions earn fees; incentives may be governed via emissions or revenue distribution.
- Governance & Tokens
  - SIP‑010 tokens (e.g., CXD, governance) and SIP‑009 NFTs (positions/roles) align incentives with system health.
- Risk Controls
  - Caps, fee bands, and breaker thresholds calibrate behavior under volatility.

## 20. Compliance Policy (Enterprise vs Retail)

- Retail: permissionless, open‑source flows; full transparency via events and read‑only interfaces.
- Enterprise: trait‑driven compliance hooks (KYC/KYB, sanctions), DID+ZK attestations, and whale gating ≥ 100 BTC equivalent.
- Governance upgrades adjust thresholds and enforcement paths with timelocks and audit trails.

## 21. Roadmap & Milestones

- M1: Core Unification (oracle, risk, position management) — Complete.
- M2: Advanced Router Integration and Test Harness Normalization.
- M3: MEV Protection Hardening (batch auctions, sandwich detection).
- M4: Full Route Orchestration and Production Benchmarking.

## 22. References & Standards

- Stacks SIP‑009 (NFT) and SIP‑010 (FT)
- Clarinet SDK 3.9+ (target), 3.8.1 (current in repo; migration in progress)
- Nakamoto Tenure Model and tenure‑aware primitives
- Wormhole interoperability notes and security best practices

## 23. Glossary

- Tenure: Nakamoto era unit enabling sub‑second block cadence awareness.
- TWAP: Time‑Weighted Average Price, exponential moving average variant.
- Commitment: Pre‑image hashed with canonical encoding for MEV protection.

## 24. Disclaimers

- This document is informational and not an audit. Production deployments require third‑party audits, formal verification, and rigorous threat modeling.
- No private keys or secrets may be stored in manifests or committed to source control. Use `.env` with derivation scripts.

## Appendix A — Contract Inventory (Selected)

- Traits: `contracts/traits/all-traits.clar` (centralized)
- Router: `contracts/dimensional/advanced-router-dijkstra.clar`
- Pools: `contracts/dimensional/concentrated-liquidity-pool.clar` (+ stable/weighted variants)
- Factory: `contracts/dex/dex-factory-v2.clar`
- Core Engine: `contracts/core/dimensional-engine.clar`
- MEV: `contracts/mev-protector.clar`
- PoR: `contracts/security/proof-of-reserves.clar`
- Interop: `contracts/interoperability/wormhole-{inbox,outbox,handlers}.clar`
- Utilities: `contracts/utils/*` (encoding, block utils)

## Appendix B — Error Codes & Response Typing

- Standardize to `Response<T, uN>` with error codes ≥ u1000 for system modules.
- Avoid generic `(err u1)` style codes in production modules; enforce scope‑specific ranges.

## Appendix C — Event Schema (Illustrative)

- Router: `{ event: "route-executed", route-hash, tenure-id, hops, slippage-bps }`
- Oracle: `{ event: "oracle-updated", asset, price, twap, deviation-bps }`
- MEV: `{ event: "commit-reveal", commitment-hash, round }`
- PoR: `{ event: "por-verified", asset, updated-at }`
- Compliance: `{ event: "whale-gated", principal, threshold-btc }`

---

Authorship: Conxian Protocol Core Contributors
License: CC BY‑SA 4.0
