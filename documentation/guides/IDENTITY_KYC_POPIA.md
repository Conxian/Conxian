# Conxian Identity, KYC & POPIA Charter

## 1. Scope and Goals

This document defines how Conxian handles identity, KYC/KYB and data protection while remaining a **BTC‑aligned, on‑chain first** financial system. It applies to both **natural persons** (KYC) and **legal persons** (KYB), including businesses, institutions and service providers that interact with Conxian.

It sets internal standards that:

- **Precede and constrain** implementation choices (vendors, tools, integrations).
- **Align** with POPIA, FSCA/IFWG guidance and global KYC/AML expectations.
- **Protect decentralisation and user privacy** by keeping personal data off‑chain.

This charter is a living document and must be updated alongside roadmap and whitepaper revisions.

---

## 2. Legal and Regulatory Alignment

Conxian (the on‑chain protocol and DAO), together with **Conxian Labs** (the primary off‑chain legal entity wrapper expected to be incorporated under South African law), operate under a multi‑layer alignment model:

- **Internal standards (primary)**
  - Modular, auditable architecture.
  - Explicit risk budgets and economic safety rules.
  - Strict on‑chain minimalism for personal data.

- **South African context**
  - **POPIA** – Protection of Personal Information Act.
  - **FSCA / IFWG** – financial sector conduct, sandbox precedents, and the SA stablecoin and DeFi guidance.

- **Global KYC/AML frameworks**
  - FATF recommendations on VASPs and travel rule (where applicable via partners).
  - Common banking/fintech standards for sanctions/PEP, adverse media, and ongoing monitoring.

Internal standards are **not optional**: vendors, architectures and products must conform to this charter first, then add local regulatory specifics as needed.

---

## 3. Core Principles

### 3.1 On‑Chain Minimalism (No PII On‑Chain)

- No contract or event may store or emit:
  - Names, ID numbers, physical addresses, emails, phone numbers or similar personal identifiers.
  - Raw ID document scans or hashes of raw documents.
- On‑chain state is limited to **status signals**, such as:
  - `kyc-tier` (e.g. `u0`..`u3`).
  - Flags like `requires-review`, `sanctioned`, or `institutional-only` (as booleans/enums).
  - Anonymous or pseudonymous subject handles (random IDs that reveal nothing by themselves).

### 3.2 Vendor‑Agnostic Design

- Smart contracts must **not hardcode any KYC vendor**.
- On‑chain interfaces express **generic requirements** (e.g. "tier ≥ 2") instead of vendor names or formats.
- Off‑chain systems may talk to multiple KYC/KYB providers and DID/VC/ZK identity providers in parallel.

### 3.3 Tiered Access and Duties

- All protocol roles and products are mapped to **KYC/KYB tiers**, not to specific customer types.
- Guardians, institutional LPs, and certain high‑risk actions require higher tiers than ordinary DeFi usage.

### 3.4 BTC Alignment and Decentralisation

- Identity and compliance must not create a single central choke point.
- Design favours:
  - Replaceable attestors.
  - Committee‑based approvals for sensitive changes.
  - ZK / verifiable credentials where practical, to avoid centralised data leaks.

### 3.5 Auditability and Transparency

- All on‑chain access decisions are **verifiable** via:
  - Public functions that expose tiers/flags.
  - Emitted events for every tier/flag change (without PII).
- Off‑chain systems maintain:
  - Detailed logs and audit trails.
  - Clear mapping from real‑world KYC steps to on‑chain status.

---

## 4. Participant Classes and KYC/KYB Tiers

Conxian defines abstract KYC tiers that can be satisfied by different providers and methods over time.

### 4.1 Participant Classes

- **End Users / Retail Participants**
  - Trade, lend, provide liquidity, purchase protection products.

- **Guardians / Validators / Keepers**
  - Operate the Conxian Guardian Network (bridges, oracles, liquidations, governance execution).

- **Institutions and Professional Operators**
  - Banks, custodians, funds, licensed entities, and pro guardian operators.

### 4.2 Tier Definitions (Example Baseline)

- **Tier 0 – Unverified**
  - No KYC performed.
  - Access: public DeFi features that are safe and legally permitted without KYC, subject to ongoing regulatory review.

- **Tier 1 – Basic KYC (Natural Persons)**
  - Identity verification, sanctions/PEP check, liveness, basic AML screening.
  - Access: elevated limits, some additional products, potential community guardian roles with caps.

- **Tier 2 – Enhanced KYC/KYB (Pro Operators)**
  - Full KYC for individuals or KYB for organisations, UBO checks, enhanced AML.
  - Access: professional guardian roles, primary oracle and bridge committees, institutional‑grade liquidity pools.

- **Tier 3 – Regulated Institutions**
  - Licensed banks, custodians, funds and similar under applicable regulations.
  - Access: institution‑only products, direct DAO/Operations engagement, large risk exposures.

### 4.3 Business and Integrator Usage

- Businesses, fintechs and other service providers that integrate with Conxian are onboarded under the same tiered KYC/KYB model.
- KYB for these entities is performed off‑chain by Conxian Labs and its partners, and only the resulting tier and status flags are reflected on‑chain.
- Third‑party applications can rely on Conxian’s on‑chain KYC/KYB tiers as a shared signal when enforcing their own policy and access rules.

Exact requirements per tier are defined and updated by the Operations & Compliance function, in consultation with legal counsel and regulators.

---

## 5. Architecture Overview

### 5.1 Off‑Chain Identity and KYC Orchestrator

The Conxian off‑chain stack (Operations backend) is responsible for:

- Integrating with one or more **KYC/KYB API providers** (e.g. crypto‑friendly global tools and Africa‑focused vendors).
- Optionally integrating with **decentralised identity / verifiable credential / ZK** providers.
- Storing KYC/KYB artefacts under controls that align with POPIA (encrypted storage, strict access control, retention policies).
- Deriving an internal **risk/policy decision**:
  - Assign `kyc-tier` and flags for each subject.
  - Decide which credentials or on‑chain attestations to issue.

### 5.2 On‑Chain KYC Registry and Attestors

On Stacks (Clarity), Conxian exposes minimal, generic primitives:

- **`kyc-registry` contract (conceptual)**
  - State:
    - `principal → kyc-tier` (uint or enum).
    - `principal → status-flags` (e.g. review required, restricted, revoked).
  - Functions (examples):
    - `get-kyc-tier(principal)`.
    - `is-tier-or-above(principal, tier)`.
    - `set-kyc-status(principal, tier, flags)` – callable only by authorised ops/attestor roles.

- **Optional: Credential / Attestor Contracts**
  - For non‑transferable KYC passes (e.g. SBT‑style NFTs) or ZK‑verified credentials.
  - May be used by third‑party dapps that integrate with Conxian’s identity layer.

Contracts across the ecosystem depend on **these generic signals**, not on vendor‑specific details.

---

## 6. Usage Across the Conxian System

### 6.1 Guardian / Validator Layer

- Guardian registry and staking contracts must:
  - Check minimum `kyc-tier` thresholds for registration (e.g. `tier ≥ 1` for community, `tier ≥ 2` for professional guardians).
  - Support revocation or downgrade if off‑chain KYC/KYB or sanctions status changes.
- Guardian committees for high‑risk services (bridges, oracles) may require higher tiers and additional governance approval.

### 6.2 Products (DEX, Lending, Insurance, Bridge)

- Product contracts consult the `kyc-registry` when:
  - Enforcing institution‑only pools or strategies.
  - Controlling access to structured products that are only suitable for certain categories of investors.
- For most open DeFi flows, access remains permissionless **unless** and until regulation or risk management demands stricter gating.

### 6.3 Governance and Operations

- DAO and Operations Engine policies define:
  - Which proposals require certain KYC tiers for proposers or executors.
  - How guardian roles are granted or revoked based on identity/policy status.
- All on‑chain role changes and KYC‑tier changes must emit events to enable external monitoring and audit.

---

## 7. Provider and Partner Selection Criteria

When evaluating KYC/KYB or identity providers (centralised or decentralised), Conxian applies at least the following criteria:

- **Regulatory and Jurisdictional Fit**
  - Support for South African IDs and data protection regulations.
  - Support for South African IDs and POPIA‑compatible processing.
  - Ability to support FSCA/IFWG expectations for DeFi and virtual assets.

- **Crypto / DeFi Readiness**
  - Experience with exchanges, wallets, and DeFi platforms.
  - Clear stance on non‑custodial protocols and decentralised governance.

- **Technical Capability**
  - Mature APIs, webhooks and SDKs.
  - Support for verifiable credentials, DID, or privacy‑preserving proofs where possible.

- **Security and Data Protection**
  - Encryption at rest and in transit.
  - Audits, certifications, and incident response processes compatible with POPIA.

- **Operational Flexibility**
  - Ability to support multiple regions and user classes.
  - Reasonable SLAs and scalability for guardian onboarding and retail flows.

No single provider is assumed to be permanent. The architecture must tolerate:

- Migration between providers.
- Parallel use of multiple providers.
- Addition of decentralised identity layers over time.

---

## 8. POPIA Data Lifecycle and Data Subject Rights

Conxian distinguishes clearly between **on‑chain signals** and **off‑chain personal data**. Off‑chain processing and storage are primarily the responsibility of Conxian Labs and its contracted service providers, operating under POPIA and other applicable data protection regimes:

- **On‑chain**
  - Contains only KYC tiers, flags and pseudonymous identifiers.
  - Cannot be used to reconstruct personal identity under normal circumstances.

- **Off‑chain**
  - Holds KYC/KYB records, documents and detailed screening results, managed by Conxian Labs and selected partners.
  - Must implement POPIA‑aligned policies for:
    - Lawful basis of processing.
    - Data minimisation and purpose limitation.
    - Retention and deletion schedules.
    - Data subject access, correction and deletion (subject to regulatory constraints).

Data subject requests (access, rectification, deletion) are served through Conxian’s web and support channels and processed in the off‑chain systems. On‑chain status values may be updated (e.g. downgraded or revoked) in line with these decisions.

---

## 9. Open Questions and Future Work

- Refine and formalise exact requirements per tier (Tier 0–3) for each participant class.
- Decide which identity technologies to pilot first (traditional API providers, VC/DID wallets, ZK proofs, or a mix).
- Design and implement the concrete `kyc-registry` and any credential/attestor contracts on Stacks.
- Integrate KYC tiers into guardian registry, institutional products, and the Operations Engine.
- Update ROADMAP and whitepaper to reference this charter and its phased rollout.

This charter should be revisited regularly as regulation, technology and Conxian’s product mix evolve.
