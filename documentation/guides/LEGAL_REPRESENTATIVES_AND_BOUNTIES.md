# Legal Representatives & Bounties Design

## 1. Scope & Goals

This document defines how Conxian recognises, incentivises, and governs legal wrappers and legal/policy contributors.

Goals:

- **Decentralised but accountable** – multiple legal representatives and advisors can participate, but each jurisdiction has clear accountability.
- **Plug-and-play** – legal entities integrate via standard on-chain registries and off-chain data packs.
- **Aligned with identity and treasury designs** – identity uses `IDENTITY_KYC_POPIA.md`; funding uses `TREASURY_AND_REVENUE_ROUTER.md` and `PAYROLL_AND_REWARDS.md`.

---

## 2. Roles

### 2.1 Conxian Labs (Primary SA Wrapper)

- Acts as the primary legal and operational wrapper in South Africa.
- Responsible for:
  - POPIA compliance and SA regulatory engagement.
  - Operating KYC/KYB and payment provider relationships on behalf of the DAO.

### 2.2 Regional Legal Wrappers

- Additional entities authorised by the DAO for other jurisdictions.
- Examples:
  - EU-focused entity for MiCA and PSD2 alignment.
  - US-focused entity for securities, commodities, and tax considerations.
- Typically hold local licenses or partner with local firms.

### 2.3 Legal Representatives & Advisors

- Law firms, legal DAOs, or individual experts that:
  - Provide legal opinions, regulatory research, and policy guidance.
  - May or may not be the formal wrapper in any jurisdiction.

All of these roles are represented on-chain through a shared registry interface.

---

## 3. Legal Representative Registry (Conceptual)

A conceptual contract, `legal-representative-registry.clar`, provides a canonical view of legal representatives.

### 3.1 State

For each representative:

- `region-id` (e.g. `"ZA"`, `"EU"`, `"US"`, `"GLOBAL"`).
- `entity-principal` (Stacks principal representing the entity or a proxy contract).
- `role`:
  - `PRIMARY_WRAPPER` – primary legal entity per region.
  - `LOCAL_COUNSEL` – law firm or counsel in a region.
  - `POLICY_ADVISOR` – research or advisory role.
- `status`:
  - `ACTIVE`, `PROBATION`, `SUSPENDED`, `RETIRED`.
- `kyc-tier` (from central identity registry, typically Tier 2 or 3).
- Optional: `bonded-stake` and simple `reputation-score`.

### 3.2 Functions (Conceptual)

- `register-legal-rep(region, principal, role)` – restricted to DAO/Operations.
- `update-status(region, principal, status)` – adjust status as relationships change.
- `set-bond(region, principal, amount)` – if a bonding mechanism is required.
- `get-legal-reps(region)` – view function for UIs, auditors, and integrators.

Actual implementation details will be finalised alongside governance integration.

---

## 4. Incentive Model

### 4.1 Base Retainers

- **Who**: Conxian Labs (ZA) and any DAO-approved regional wrappers.
- **What**: Recurring compensation for maintaining regulatory posture, reporting, and incident support.
- **Funding**: Ops / Conxian Labs Vault and Regional Ops Vaults via Revenue Router allocations.
- **Mechanism**: Streams defined in `PAYROLL_AND_REWARDS.md` (e.g. `create-stream` with tags like `LEGAL_SA_RETAINER`).

Retainers are subject to:
- DAO approval and periodic review.
- Caps expressed as a percentage of protocol revenues.

### 4.2 Legal & Policy Bounties

- **Who**: Any registered legal representative or advisor meeting tier requirements.
- **What**: Discrete tasks such as:
  - Regulatory landscape reviews.
  - Policy memos for specific jurisdictions.
  - Licensing strategy proposals.
  - Post-incident legal analyses.
- **Funding**: Legal Bounties Vault.
- **Mechanism**:
  - `create-bounty(region, reward, scope, tag)`.
  - `submit-work(bounty-id, principal, work-hash)`.
  - `approve-and-pay(bounty-id, principal)` via DAO or delegated Ops.

This enables competition and specialisation without locking into a single advisor.

### 4.3 Milestone-Based Bonuses

- For major achievements, such as:
  - Successful SA sandbox/pilot completion.
  - Formal regulatory no-action letters.
  - Key licenses obtained for regional wrappers.
- Funded via Legal Bounties Vault or treasury allocations.
- Treated as distinct bounties with objective completion criteria.

---

## 5. Identity, KYC/KYB & POPIA

All legal representatives and wrappers are subject to the identity standards in `IDENTITY_KYC_POPIA.md`.

- KYB and any relevant KYC are performed off-chain by Conxian Labs and providers.
- On-chain registry stores only:
  - Principals, regions, roles, statuses, and tiers.
- POPIA and other data protection laws are satisfied by:
  - Conxian Labs managing personal and corporate data in its own systems.
  - Protocol-layer contracts never storing PII.

---

## 6. Governance & Accountability

- The DAO:
  - Approves registration of primary wrappers and key legal partners.
  - Sets retainer budgets and bounty allocations.
  - Can change or revoke representative status via proposals.

- Conxian Labs:
  - Coordinates day-to-day interactions with representatives.
  - Ensures contracts and engagement letters align with DAO intent.

Disputes about quality or conflicts of interest can be:
- Addressed through governance (status changes, termination of retainers).
- Supplemented by on-chain dispute resolution mechanisms where appropriate.

---

## 7. Integration with External Stakeholders

- **Regulators**
  - Can see an on-chain list of representatives and wrappers per region.
  - Receive consistent reporting and compliance packs via Conxian Labs.

- **Institutions and Partners**
  - Can verify legal counterparties and advisory networks transparently.
  - Use on-chain registry data to validate who speaks on behalf of Conxian in their jurisdiction.

This model keeps legal representation flexible and decentralised while preserving clear accountability per jurisdiction.
