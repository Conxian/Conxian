# Conxian DApps & Module Mapping

> **Purpose:** This document maps the Conxian protocols on-chain modules and traits to user-facing DApps and flows (DEX, Lending, Governance, Vaults, Enterprise, Monitoring). It is the primary reference for understanding which contracts back which products, and how they are grouped for deployment and testing.

_Last updated: November 29, 2025_

---

## 1. Overview

Conxian is a modular, multi-dimensional DeFi protocol on Stacks. The codebase is organized around:

- **Core engine** (dimensional engine + collateral manager)
- **Product modules** (DEX, Lending, Governance, Vaults)
- **Cross-cutting systems** (Oracles, Risk, Security, Enterprise, Monitoring)
- **Modular traits** (11 primary trait files in `contracts/traits/`)

This document does **not** replace the whitepaper or ARCHITECTURE.md. Instead, it:

- Connects **DApps / UX surfaces** to **specific contracts + traits**.
- Highlights **critical dependencies** and **deployment groupings**.
- Helps coordinate **testing**, **deployment**, and **frontend integration**.

---

## 2. Core Engine & Dimensional System

### 2.1 Core Engine

**Primary responsibilities**

- Coordinate multi-dimensional state (positions, liquidity, pricing, risk).
- Provide a shared foundation for DEX, lending, and higher-level products.

**Key contracts** (see `Clarinet.toml`):

- `contracts/core/dimensional-engine.clar` → `dimensional-engine`
- `contracts/dimensional/dimensional-core.clar` → `dimensional-core`
- `contracts/dimensional/dim-metrics.clar` → `dim-metrics`
- `contracts/dimensional/dim-graph.clar` → `dim-graph`
- `contracts/dimensional/dim-registry.clar` → `dim-registry`
- `contracts/dimensional/dim-oracle-automation.clar` → `dim-oracle-automation`
- `contracts/dimensional/dim-revenue-adapter.clar` → `dim-revenue-adapter`
- `contracts/dimensional/dim-yield-stake.clar` → `dim-yield-stake`
- `contracts/core/collateral-manager.clar` → `collateral-manager`

**Core traits**

- `contracts/traits/dimensional-traits.clar`
- `contracts/traits/defi-primitives.clar`
- `contracts/traits/core-protocol.clar`
- `contracts/traits/math-utilities.clar`

**DApp impact**

- **DEX:** route computation, pool graph, liquidity metrics.
- **Lending:** collateral accounting, portfolio-level metrics.
- **Analytics UI:** key performance and dimensional metrics exposed via monitoring contracts.

---

## 3. DEX DApp

### 3.1 User-Facing Flows

User flows (as referenced by documentation and Conxian_UI):

- Swap tokens (single-hop and multi-hop).
- Add/remove liquidity to concentrated pools and tiered pools.
- View pool KPIs (TVL, fees, price, volume, performance).
- Participate in batch auctions and rebalancing if exposed.

### 3.2 Core DEX Contracts

**Factory, pools, routers, and oracles** (see `contracts/dex/` and `Clarinet.toml`):

- `dex-factory` & `dex-factory-v2`  
  - `contracts/dex/dex-factory.clar`  
  - `contracts/dex/dex-factory-v2.clar`
- `multi-hop-router-v3`  
  - `contracts/dex/multi-hop-router-v3.clar`
- `dimensional-advanced-router-dijkstra`  
  - `contracts/dimensional/advanced-router-dijkstra.clar`
- `concentrated-liquidity-pool`  
  - `contracts/dex/concentrated-liquidity-pool.clar`
- `pool-template`, `tiered-pools`, `pool-registry`  
  - `contracts/dex/pool-template.clar`  
  - `contracts/pools/tiered-pools.clar`  
  - `contracts/pools/pool-registry.clar`
- Price/oracle helpers used by DEX:  
  - `contracts/dex/oracle.clar` → `oracle`  
  - `contracts/dex/oracle-aggregator-v2.clar` → `oracle-aggregator-v2`

**Security & manipulation protection:**

- `contracts/dex/manipulation-detector.clar` → `manipulation-detector`
- `contracts/dex/rebalancing-rules.clar` → `rebalancing-rules`
- `contracts/dex/batch-auction.clar` → `batch-auction`

**Traits & math:**

- `contracts/traits/defi-primitives.clar` (pool/factory/router abstractions)
- `contracts/math/exponentiation.clar` → `exponentiation`
- `contracts/math/math-lib-concentrated.clar` → `math-lib-concentrated`
- `contracts/lib/math-lib-advanced.clar` → `math-lib-advanced`
- `contracts/lib/precision-calculator.clar` → `precision-calculator`

### 3.3 DEX: DApp ↔ Contract Map

- **Conxian_UI `/router`**
  - Uses ABI from `multi-hop-router-v3` and/or `dimensional-advanced-router-dijkstra`.
  - Depends on traits from `defi-primitives` and `dimensional-traits`.

- **Conxian_UI `/pools`**
  - Read-only queries to `concentrated-liquidity-pool`, `pool-registry`, `tiered-pools`.
  - KPIs built from DEX contracts + monitoring contracts (see §8).

- **Conxian_UI `/tx` DEX templates**
  - Calls on `dex-factory(-v2)`, pool contracts, and router contracts for:  
    `add-liquidity`, `remove-liquidity`, `swap-exact-in`, `swap-exact-out`.

---

## 4. Lending DApp

### 4.1 User-Facing Flows

- Deposit supported assets as collateral.
- Borrow against collateral with interest rate model.
- Trigger or be subject to liquidations when risk limits are breached.
- (Future) Enterprise lending products and sBTC-backed credit lines.

### 4.2 Core Lending & Risk Contracts

**Lending engine:**

- `contracts/lending/comprehensive-lending-system.clar` → `comprehensive-lending-system`  
  _Central orchestrator for lending flows._
- `contracts/lending/interest-rate-model.clar` → `interest-rate-model`
- `contracts/lending/liquidation-manager.clar` → `liquidation-manager` (depends on `comprehensive-lending-system`).

**Risk engine:**

- `contracts/risk/risk-manager.clar` → `risk-manager`
- `contracts/risk/liquidation-engine.clar` → `liquidation-engine`
- `contracts/risk/funding-calculator.clar` → `funding-calculator`
- Traits: `contracts/traits/risk-management.clar`

**Enterprise lending & integrations:**

- `contracts/enterprise/enterprise-loan-manager.clar` → `enterprise-loan-manager`
- `contracts/enterprise/enterprise-api.clar` → `enterprise-api`
- Governance and policy integration:  
  - `contracts/governance/lending-protocol-governance.clar` → `lending-protocol-governance`

### 4.3 Lending: DApp ↔ Contract Map

(Current UI is primarily DEX-focused; lending DApp flows are defined in docs and tests rather than a dedicated web UI.)

- **CLI / integration tests**
  - Use `comprehensive-lending-system`, `liquidation-manager`, `lending-protocol-governance` for end-to-end flows.
- **Future UI**
  - Will surface:  
    - Collateralization ratios and positions (via lending & risk contracts).  
    - Liquidation previews and events (via risk and oracle modules).  
    - Enterprise credit lines (via `enterprise-*` contracts).

- **Testing**
  - Vitest + Clarinet SDK tests under `tests/` cover flows such as deposit, borrow, repay, liquidate, but coverage is still below target.

---

## 5. Governance DApp

### 5.1 User-Facing Flows

- Create and register proposals (protocol upgrades, parameter changes, treasury actions).
- Vote with governance tokens.
- Execute approved proposals with timelock.

### 5.2 Governance Contracts

- `contracts/governance-token.clar` → `governance-token`
- `contracts/governance/proposal-engine.clar` → `proposal-engine`
- `contracts/governance/proposal-registry.clar` → `proposal-registry`
- `contracts/governance/voting.clar` → `governance-voting`
- `contracts/dex/timelock-controller.clar` → `timelock-controller`
- Traits: `contracts/traits/governance-traits.clar`

### 5.3 Governance: DApp ↔ Contract Map

- **User governance UI (planned / partially implemented)**
  - Create proposals via `proposal-engine`.
  - View and filter proposals via `proposal-registry`.
  - Vote via `governance-voting` using `governance-token`.
  - Time-locked execution enforced by `timelock-controller`.

- **Interaction with other modules**
  - Parameter changes for DEX, lending, risk, and oracles are routed through governance proposals.
  - Circuit breaker and risk controls can be wired to require governance approval for certain thresholds.

---

## 6. Tokens & Vaults

### 6.1 Protocol Tokens

**Primary tokens** (see `contracts/tokens/`):

- `cxd-token` → `contracts/tokens/cxd-token.clar` (governance token)
- `cxlp-token` → `contracts/tokens/cxlp-token.clar` (LP token)
- `cxvg-token` → `contracts/tokens/cxvg-token.clar` (vault governance)
- `cxtr-token` → `contracts/tokens/cxtr-token.clar` (treasury/liquidity incentives)
- `cxs-token` → `contracts/tokens/cxs-token.clar` (staking / stability)
- `token-system-coordinator` → `contracts/tokens/token-system-coordinator.clar`
- `cxd-price-initializer` → `contracts/tokens/cxd-price-initializer.clar`

Traits:

- SIP-010 and related standards: `contracts/traits/sip-standards.clar`
- Error traits: `contracts/traits/trait-errors.clar`

### 6.2 Vaults & sBTC

- `contracts/vaults/*` (not fully enumerated here) – vault abstractions.
- `contracts/sbtc/btc-adapter.clar` → `btc-adapter`
- `contracts/sbtc/dlc-manager.clar` → `dlc-manager`
- `contracts/dex/sbtc-integration.clar` → `sbtc-integration`

**Use cases**

- BTC/sBTC collateralized positions.  
- On-chain vaults for LP and strategy-based products.  
- sBTC-backed liquidity and lending products, integrated with risk and oracle layers.

---

## 7. Oracles & Risk

### 7.1 Oracle System

**Contracts** (per `Clarinet.toml` and `documentation/architecture/adr/0002-oracle-system-design.md`):

- `oracle` → `contracts/dex/oracle.clar`
- `oracle-aggregator-v2` → `contracts/dex/oracle-aggregator-v2.clar`
- `dimensional-oracle` → `contracts/oracle/dimensional-oracle.clar`
- `twap-oracle` → `contracts/integrations/twap-oracle.clar`
- `oracle-adapter` & related stubs → `contracts/oracle/oracle-adapter-stub.clar`
- sBTC oracle integration: `sbtc-oracle-adapter` (via remapping)

Traits:

- `contracts/traits/oracle-pricing.clar`

**Responsibilities**

- Aggregate price feeds from multiple sources.  
- Provide dimensional (time-weighted, risk-aware) pricing to DEX, lending, and risk modules.  
- Bridge external data into the protocol in a modular, upgradeable manner.

### 7.2 Risk System

**Contracts**

- `risk-manager` → `contracts/risk/risk-manager.clar`
- `liquidation-engine` → `contracts/risk/liquidation-engine.clar`
- `funding-calculator` → `contracts/risk/funding-calculator.clar`
- `protocol-invariant-monitor` → `contracts/monitoring/protocol-invariant-monitor.clar` (by design)

Traits:

- `contracts/traits/risk-management.clar`

**Responsibilities**

- Interpret prices and volatility to compute risk limits.  
- Decide when to liquidate positions or rebalance pools.  
- Feed metrics into monitoring and, in future, cover/insurance layers.

### 7.3 DApp & Product Impact

- **DEX:** slippage/price impact, MEV-aware routing, and pool health are driven by oracle + risk data.  
- **Lending:** collateralization, margin calls, and liquidations rely on consistent oracle + risk calculations.  
- **Enterprise:** institutional credit frameworks depend on risk metrics and invariant monitoring.

---

## 8. Security, MEV Protection & Monitoring

### 8.1 Security Layer

**Contracts**

- Circuit breaker:  
  - `contracts/security/circuit-breaker.clar` → `circuit-breaker`
- MEV protection:  
  - `contracts/mev/mev-protector-root.clar` → `mev-protector-root`  
  - `contracts/dex/mev-protector.clar` → `mev-protector`
- Access control and roles:  
  - `contracts/base/ownable.clar` → `ownable`  
  - `contracts/base/pausable.clar` → `pausable`  
  - `contracts/access/roles.clar` → `roles`
- Audit artifacts:  
  - `contracts/audit-registry/audit-registry.clar` → `audit-registry`  
  - `contracts/audit-registry/audit-badge-nft.clar` → `audit-badge-nft`

Traits:

- `contracts/traits/security-monitoring.clar`
- `contracts/traits/core-protocol.clar` (ownable/pausable patterns)

### 8.2 Monitoring & Analytics

**Contracts** (representative subset; see `contracts/monitoring/` and docs):

- `analytics-aggregator` → `contracts/monitoring/analytics-aggregator.clar`
- `finance-metrics` → `contracts/monitoring/finance-metrics.clar`
- `protocol-invariant-monitor` → `contracts/monitoring/protocol-invariant-monitor.clar`

Docs:

- `documentation/ANALYTICS_METRICS_GUIDE.md`
- `documentation/SECURITY_REVIEW_PROCESS.md`
- `documentation/security/SECURITY.md`

**DApp impact**

- Analytics dashboards and monitoring tools (on-chain + off-chain) rely on these contracts to surface KPIs and invariants for:
  - DEX pools and routing.
  - Lending portfolios and vaults.
  - Enterprise and compliance oversight.

---

## 9. Enterprise & Compliance

### 9.1 Enterprise Module

**Contracts**

- `enterprise-api` → `contracts/enterprise/enterprise-api.clar`
- `enterprise-loan-manager` → `contracts/enterprise/enterprise-loan-manager.clar`

Docs:

- `documentation/enterprise/ONBOARDING.md`
- `documentation/enterprise/BUSINESS_VALUE_ROI.md`
- `documentation/enterprise/COMPLIANCE_SECURITY.md`

**Responsibilities**

- Provide structured entry points for institutional participants.  
- Coordinate enterprise loan products and policy enforcement.  
- Integrate with external compliance and risk tooling while keeping core protocol decentralized.

### 9.2 Legal & Regulatory Alignment

- Designed for alignment with FSCA/IFWG/Markaicode-style requirements.  
- Future work: explicit compliance hooks (e.g. KYB/KYC attestations, risk disclosures) integrated via traits rather than hard-coded policies.

---

## 10. Traits & Cross-Cutting Abstractions

### 10.1 Trait Files (Canonical Interfaces)

As of November 27, 2025, the primary trait set includes:

- `sip-standards` → `contracts/traits/sip-standards.clar`
- `core-protocol` → `contracts/traits/core-protocol.clar`
- `defi-primitives` → `contracts/traits/defi-primitives.clar`
- `dimensional-traits` → `contracts/traits/dimensional-traits.clar`
- `oracle-pricing` → `contracts/traits/oracle-pricing.clar`
- `risk-management` → `contracts/traits/risk-management.clar`
- `cross-chain-traits` → `contracts/traits/cross-chain-traits.clar`
- `governance-traits` → `contracts/traits/governance-traits.clar`
- `security-monitoring` → `contracts/traits/security-monitoring.clar`
- `math-utilities` → `contracts/traits/math-utilities.clar`
- `trait-errors` → `contracts/traits/trait-errors.clar`
- Additional specialized traits: `queue-traits`, `controller-traits`.

These are the **single source of truth** for all contract interfaces used by Conxian products and DApps.

### 10.2 How DApps Should Use Traits

- Frontend and integration code (e.g. Conxian_UI) should rely on **ABI and behavior defined by these traits**, not ad-hoc assumptions.  
- When adding new features or modules:
  - First update or add traits under `contracts/traits/`.
  - Then implement or extend contracts to conform to those traits.
  - Finally, wire ABI-based calls in UIs and off-chain services.

---

## 11. Deployment & Testing Considerations (Conxian View)

> Full, cross-repo deployment mapping (including StacksOrbit) is documented separately; this section focuses on Conxians own view of readiness.

### 11.1 Manifest & Remappings

- `Clarinet.toml` defines:
  - All core, module, and trait contracts with addresses and dependencies.  
  - `remap.contracts` entries (e.g. `dex-router`, `oracle-aggregator-v2`, `risk-manager`, `mev-protector`, `cxd-token`) used heavily in tests and integration tooling.

### 11.2 Current Compilation Status (High-Level)

- Global manifest is **syntactically clean** in the design baseline, but current local runs may still surface:
  - Trait/semantic mismatches in **risk, lending, enterprise, token, and MEV-helper** modules.  
  - Occasional syntax regressions when editing math or advanced routing contracts (e.g. `exponentiation`, `math-lib-*`, or router variants).

### 11.3 Testing

- Tests are organized primarily under `tests/` with Vitest + Clarinet SDK.
- Key test focuses:
  - DEX routing & concentrated liquidity.  
  - Lending and liquidation flows.  
  - Circuit breaker and MEV protection.
- Coverage and stability remain below target; see `documentation/TESTING_FRAMEWORK.md` and `ROADMAP.md` for current metrics and goals.

---

## 12. How to Use This Map

- **Frontend / UX teams (e.g. Conxian_UI)**
  - Use this map to know which contracts back which UI routes and KPIs.
  - When designing new screens, anchor them to explicit modules and traits from this document.

- **Protocol engineers**
  - Use this as a checklist when 
    - adding new contracts to `Clarinet.toml`,  
    - updating traits, or  
    - adjusting deployment/test plans.

- **DevOps / tooling (e.g. StacksOrbit integration)**
  - Use this map to define deployment categories and monitoring views that align with actual DApp surfaces.

This document should evolve alongside the architecture and is intended to remain tightly coupled to `Clarinet.toml`, the traits in `contracts/traits/`, and the top-level DApp surfaces described in `documentation/README.md` and the whitepaper.
