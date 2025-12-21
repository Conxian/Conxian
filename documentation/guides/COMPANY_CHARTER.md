# Conxian On-Chain Company Charter

## 1. Purpose

This charter defines Conxian as an on-chain financial company and describes how its modules, flows, and governance align under the Conxian DAO and Conxian Labs.

The goals are to:

- **Clarify roles** for on-chain contracts, the DAO, Conxian Labs, and external partners.
- **Align incentives and responsibilities** across treasury, risk, operations, products, and compliance.
- **Provide a single reference** for architecture, identity, treasury, and legal wrappers.

This document complements:

- `IDENTITY_KYC_POPIA.md` – identity, KYC/KYB and POPIA alignment.
- `TREASURY_AND_REVENUE_ROUTER.md` – treasury and protocol revenue routing.
- `REGULATORY_ALIGNMENT.md` – mapping to regulatory-style objectives.
- `OPERATIONS_RUNBOOK.md` – operational procedures.

---

## 2. Core Entities

### 2.1 Conxian (Protocol & DAO)

- **Conxian Protocol**
  - The on-chain system of smart contracts on Stacks (DEX, lending, risk, treasury, governance, monitoring, insurance, automation, etc.).
  - Designed to be modular, auditable, and BTC-aligned.

- **Conxian DAO**
  - The on-chain governance body.
  - Owns protocol parameters, contract upgrades (via CXIPs), treasury allocations, and high-level policy decisions.
  - Acts through:
    - Council NFTs and role-based access.
    - Governance tokens and proposals.
    - The Conxian Operations Engine as an automated "operations seat".

### 2.2 Conxian Labs (Off-Chain Legal Wrapper)

- Conxian Labs (expected to be incorporated under South African law) is the primary off-chain legal and operational entity for Conxian.
- Responsibilities include:
  - Running off-chain infrastructure and deployments.
  - Orchestrating KYC/KYB and POPIA-aligned data processing.
  - Managing relationships with regulators, KYC vendors, payment providers, and auditors.
  - Operating off-chain accounting, payroll, and reporting based on on-chain data.
- Conxian Labs acts on behalf of the DAO but is **not** a substitute for DAO governance.

### 2.3 Future Regional Wrappers & Representatives

- The DAO may authorize additional regional entities (legal wrappers) or legal representatives in other jurisdictions.
- These entities:
  - Are registered on-chain in a legal representative registry (conceptual).
  - Are funded through dedicated vaults or streams.
  - Must adhere to the same identity and treasury standards as Conxian Labs.

---

## 3. On-Chain Departments & Their Contracts

Conxian is structured like an on-chain company with clear "departments" implemented as contract clusters.

### 3.1 Treasury & Finance

- **Scope**
  - Manage protocol assets and revenue flows.
  - Fund guardians, risk reserves, operations (Conxian Labs and regional wrappers), growth, and grants.

- **Key components (conceptual)**
  - Treasury Vaults and service vaults.
  - Revenue Router and Allocation Policy as defined in `TREASURY_AND_REVENUE_ROUTER.md`.

### 3.2 Risk & Intelligence

- **Scope**
  - Define and enforce leverage, risk limits, and capital buffers.
  - Monitor price stability and systemic health.

- **Representative contracts**
  - `risk-manager.clar`
  - `interest-rate-model.clar`
  - `price-stability-monitor.clar`
  - Insurance / cover contracts and reserves.

### 3.3 Guardians, Automation & Operations

- **Scope**
  - Execute protocol operations safely and deterministically.
  - Maintain uptime and coverage for bridges, oracles, liquidations, and governance execution.

- **Representative contracts**
  - `guardian-registry.clar` – guardian roles, bonding, slashing.
  - `keeper-coordinator.clar` and automation targets.
  - `conxian-operations-engine.clar` and `ops-policy.clar`.
  - `ops-service-vault.clar` coordinated with the treasury design.

### 3.4 Products (DEX, Lending, Insurance, Cross-Chain)

- **Scope**
  - Generate real economic activity: swaps, lending, hedging, insurance, cross-chain flows.

- **Representative contracts**
  - DEX: factories, pools, routers, MEV protection.
  - Lending: core lending system, liquidation engines.
  - Insurance: protection NFTs, insurance funds.
  - Cross-chain: bridge NFTs, validators, cross-chain LPs.

Products must:

- Integrate with risk engines (health checks, price sanity, circuit breakers).
- Route fees via the Revenue Router.
- Respect identity/KYC/KYB gating where required.

### 3.5 Governance & Councils

- **Scope**
  - Make and enforce policy decisions within the DAO.

- **Representative contracts**
  - Governance token, proposal engine/registry, voting logic.
  - Council NFTs and role-based controls.
  - CXIP proposal registry and upgrade controller.

Governance interacts with all departments by:

- Approving parameter changes.
- Adopting new contracts.
- Updating allocation policies and vault permissions.

---

## 4. Identity, KYC/KYB & Data Protection

Conxian follows the standards defined in `IDENTITY_KYC_POPIA.md`.

- On-chain:
  - Only status/tier signals (KYC/KYB tiers, flags, role eligibility).
  - No PII stored or emitted.
- Off-chain (primarily Conxian Labs):
  - Runs KYC/KYB workflows using selected providers.
  - Manages POPIA-aligned data storage, retention, and rights.

All departments consume identity tiers via shared registry interfaces rather than vendor-specific details.

---

## 5. Treasury, Revenue & Spend

Conxian’s financial flows are governed by `TREASURY_AND_REVENUE_ROUTER.md`.

- All protocol revenues (fees, premiums, interest spreads, bridge fees) are:
  - Routed through a central Revenue Router.
  - Allocated to vaults according to DAO-approved policies.
- Major spend categories:
  - Guardian rewards.
  - Risk and insurance payouts.
  - Operations (Conxian Labs and regional wrappers).
  - Security audits, legal bounties, ecosystem grants.

Departments and wrappers must draw from the appropriate vaults according to policy, ensuring a consistent and auditable financial picture.

---

## 6. Off-Chain Providers & Legal Wrappers

Conxian uses external providers for:

- KYC/KYB, sanctions/PEP screening, and ongoing monitoring.
- BTC and fiat payroll, via crypto payroll and open-banking providers.
- Legal and compliance advice, licensing support, and audit.

Conxian Labs:

- Coordinates and supervises providers.
- Produces standardised "compliance packs" and accounting exports from on-chain data.
- Acts as the primary SA legal wrapper, while regional entities share similar responsibilities in their jurisdictions.

---

## 7. Incentives & Alignment

The Company Charter assumes the following incentive structure:

- Guardians and automation providers
  - Incentivised via rewards from Guardian Rewards Vault.
  - Subject to bonding and slashing.

- Conxian Labs and regional wrappers
  - Incentivised via Ops/Regional Ops Vaults and legal bounties.
  - Bound by contractual and DAO-imposed performance expectations.

- Developers, auditors, legal advisors, and ecosystem builders
  - Supported by bounties, grants, and long-term alignment (where appropriate) through token-based rewards.

---

## 8. Governance of the Charter

- The Conxian DAO is the ultimate authority for this charter.
- Changes must follow the normal governance process and be reflected in:
  - This document.
  - Identity, treasury, regulatory, and operations documents.
- Conxian Labs and other wrappers must operate in accordance with the current version of the charter and relevant policies.

This charter should be revisited as the protocol and its regulatory environment evolve.
