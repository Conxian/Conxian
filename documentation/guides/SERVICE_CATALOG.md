# Conxian Service Catalog (Internal & External)

This catalog summarizes the main services provided by the Conxian ecosystem (on-chain protocol, tooling, and user interfaces). It is intended for internal teams, prospective institutional clients, and partners.

> **Maturity & Availability (as of 2025-12-06)**
>
> - Conxian smart contracts are in **technical alpha on testnet** and **not yet production-ready**.
> - Enterprise support tiers, formal SLAs, and REST APIs are **target designs** and will only be offered after security audits and regulatory review.
> - This catalog is a **planning and alignment tool**, not a legal commitment.

## 1. External, Customer-Facing Services

### 1.1 Conxian DeFi Protocol (On-Chain)

- **Description**: Modular DeFi protocol on Stacks providing DEX, lending, derivatives (dimensional engine), governance, risk, and insurance primitives.
- **Primary users**: Institutional integrators, advanced DeFi users, Conxian UI, third-party frontends.
- **Scope**:
  - DEX module (factory, router, pools, MEV protection, circuit breaker).
  - Lending module (`comprehensive-lending-system`, interest-rate model, liquidation engine).
  - Dimensional engine (position-manager, funding-rate-calculator, dim-metrics).
  - Token system (CXD, CXVG, CXTR, CXS, CXLP, emission controller, token-system-coordinator).
  - Governance (governance-token, proposal engine/registry, councils, role NFTs, operations engine – planned).
  - Insurance and protection (insurance fund, loan & liquidity protection cover – in design).
- **Delivery form**: Clarity smart contracts deployed on Stacks (devnet/testnet now; mainnet planned).
- **Status**: **Technical alpha / testnet only**.
- **SLA**: No formal uptime SLA; best-effort support only during development.

### 1.2 Conxian Portal (Web UI)

- **Repo**: `Conxian_UI`.
- **Description**: Next.js application for interacting with Conxian contracts on Stacks.
- **Capabilities**:
  - Wallet connection and transaction templates for SIP-010 tokens and pools.
  - Router UI with ABI-driven function discovery.
  - Pools dashboard with KPIs (TVL, fees, volume, price, inventory skew).
  - Clarity argument builder for structured contract calls.
- **Primary users**: Traders, LPs, council members, operations staff in testnet/pilot environments.
- **Delivery form**: Web app backed by Hiro Core API (`/v2/contracts/interface`, `/v2/contracts/call-read`, etc.).
- **Status**: **Developer / pilot UI**, aligned with current testnet contract set.
- **SLA**: No production SLA; dependent on Hiro API and hosting provider availability.

### 1.3 Enterprise Policy & Analytics Platform (Status: Planned)

- **Description**: Off-chain services for AML/KYC integration, sanctions screening, GDPR-aligned data export, portfolio risk analytics, and audit reporting.
- **Current implementation**:
  - Design and example code in `COMPLIANCE_SECURITY.md` and `BUSINESS_VALUE_ROI.md`.
  - No production REST API or hosted service in this repository.
- **Target capabilities**:
  - AML and Travel Rule-aligned control workflows, sanctions/PEP screening integration hooks.
  - Privacy and GDPR-aligned data export and erasure workflows.
  - Portfolio and transaction risk scoring APIs.
  - Real-time audit dashboards and historical reports.
- **Status**: **Planned / target architecture (in design)**.
- **SLA**: To be defined prior to any production rollout.

### 1.4 Enterprise Support Programme (Planned)

- **Description**: Dedicated support tiers (Standard Institutional, Professional Trading, Enterprise Premier) with account management, integration help, and incident response.
- **Current implementation**: Described in `COMPLIANCE_SECURITY.md` (support tiers, response-time targets) but not yet backed by an operating team or ticketing system in this repo.
- **Status**: **Planned offering**, to be validated through pilot programmes.
- **SLA**: Target values documented; contractual SLAs to follow once operational capacity is in place.

---

## 2. Internal & Enabling Services

### 2.1 StacksOrbit Deployment Service

- **Repo**: `stacksorbit`.
- **Description**: Advanced deployment tool for Stacks smart contracts with CLI, monitoring, and verification.
- **Capabilities**:
  - CLI commands for deploy, check, monitor, verify, diagnose (`stacksorbit_cli.py`).
  - Monitoring dashboard (`stacksorbit_dashboard.py`).
  - JS and Python APIs for programmatic deployments (`docs/api.md`, `README_ENHANCED.md`).
  - Support for generic Clarinet projects (not only Conxian).
- **Primary users**: Internal Conxian ops, external developers integrating with Stacks.
- **Delivery form**: Open-source tool (Python + Node), optionally packaged as a global CLI.
- **Status**: **Stable tooling**, used for Conxian testnet deployments; still evolving.
- **SLA**: No hosted SLA; support via open-source processes and any enterprise arrangements outside this repo.

### 2.2 Operations, Identity & Regulatory Alignment

- **Docs**:
  - `documentation/guides/OPERATIONS_RUNBOOK.md` – incident playbooks and SOPs for core contracts.
  - `documentation/guides/REGULATORY_ALIGNMENT.md` – mapping contracts/tests to regulatory-style objectives.
  - `documentation/guides/IDENTITY_KYC_POPIA.md` – identity, KYC/KYB and POPIA alignment charter (Conxian and Conxian Labs).
  - `documentation/guides/TREASURY_AND_REVENUE_ROUTER.md` – protocol treasury and revenue routing design.
- **Description**: Internal knowledge base for operations, risk, compliance, and treasury teams.
- **Status**: **Living documentation**, updated alongside contract changes and governance decisions.

### 2.3 Test & Verification Framework

- **Repo**: `Conxian`.
- **Description**: Vitest-based test harness and Clarinet checks (unit, integration, system tests).
- **Docs**: `DEVELOPER_GUIDE.md`, references in `ROADMAP.md` and `REGULATORY_ALIGNMENT.md`.
- **Status**: **Active**, but still expanding as new modules and scenarios are covered.

### 2.4 Guardian Network & Automation SDK (Planned)

- **Repos**: `Conxian_UI` (shared TS client stack), future dedicated package for Guardian SDK/CLI.
- **Description**: TypeScript SDK and reference Guardian client for running bonded automation
  on behalf of the protocol and enterprise users. Guardians use the Hiro Core API
  (`/v2/contracts/call-read`, `/extended/v1/*`) to:
  - Discover automation targets via `keeper-coordinator.clar`.
  - Call read-only views such as `get-runnable-actions` and `get-action-needed`.
  - Submit on-chain `execute-action` or governance transactions when required.
- **Primary users**: Internal ops, institutional partners running their own Guardians,
  and community automation providers.
- **Delivery form**: SDK + CLI, built on the same Stacks client utilities as Conxian_UI.
- **Status**: **Planned**, to be developed alongside the Conxian Operations Engine and
  Guardian registry.

---

## 3. Service Maturity Ladder

To keep sales, marketing, and operations aligned, all services should reference the same maturity ladder:

- **Technical Alpha**: Contracts and tooling available on devnet/testnet for internal and friendly external testing. No SLAs, limited support.
- **Pilot**: Selected institutions use the system under strict limits, with enhanced monitoring and incident processes. Informal SLOs, no broad public access.
- **Production (Planned)**: Audited contracts, formal SLAs, incident playbooks, and regulatory alignment validated for targeted jurisdictions.

As of 2025-12-06:

- Conxian DeFi Protocol: **Technical Alpha (testnet)**.
- Conxian Portal (UI): **Technical Alpha (testnet)**.
- StacksOrbit Deployment Service: **Stable tool**, but not a hosted SaaS.
- Enterprise Policy & Analytics Platform: **Planned**.
- Enterprise Support Programme: **Planned**.

---

## 4. How This Catalog Should Be Used

- **Sales & Marketing**: Use this catalog to describe only the services at their documented maturity level. Clearly distinguish current capabilities from roadmap.
- **Procurement & Risk**: Use this as a starting point to understand which services exist today, which are planned, and where to look for deeper technical and regulatory details.
- **Engineering & Ops**: Keep this catalog updated as modules graduate between alpha, pilot, and production and as new services (e.g., loan & liquidity protection cover, service vaults) are added.
