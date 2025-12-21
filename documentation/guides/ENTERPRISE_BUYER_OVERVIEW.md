# Conxian Enterprise Buyer & Due-Diligence Overview

This document is for institutional buyers, procurement teams, risk/compliance officers, and technical due-diligence reviewers. It summarizes what Conxian is, what services are in scope today, and where to find deeper technical and regulatory documentation.

> **Honest Status (as of 2025-12-06)**
>
> - The Conxian Protocol is in a **stabilization & alignment phase on testnet** and is **not yet production-ready**.
> - All ROI, policy/assurance, and support descriptions reflect **target design** rather than an already-operational regulated platform.
> - Any live production deployment will follow external audits, jurisdiction-specific legal review, and updated documentation.

## 1. What Conxian Is

- **On-chain protocol**: A modular, multi-dimensional DeFi system on the Stacks blockchain (DEX, lending, derivatives, governance, tokens, oracles, security).
- **Tooling**: StacksOrbit deployment and monitoring tooling (CLI + APIs) for Stacks smart contracts.
- **Web UI**: A Next.js-based Conxian Portal for interacting with Conxian contracts (currently aligned with testnet deployments).

For a detailed technical view, see:

- `README.md` and `documentation/architecture/ARCHITECTURE.md` (system architecture).
- `documentation/REGULATORY_ALIGNMENT.md` (mapping to regulatory-style objectives).
- `documentation/OPERATIONS_RUNBOOK.md` (incident procedures and operational controls).
- `documentation/SERVICE_CATALOG.md` (service inventory and maturity levels).
- `documentation/API_OVERVIEW.md` (API surfaces and planned REST services).

## 2. Services & Scope

High-level service categories (see `SERVICE_CATALOG.md` for details):

- **Conxian DeFi Protocol (On-Chain)** – smart contracts providing trading, lending, derivatives, governance, and risk primitives.
- **Conxian Portal (Web UI)** – reference interface for interacting with the protocol on testnet.
- **StacksOrbit Deployment Service** – tooling for deploying and monitoring Stacks contracts, including Conxian.
- **Enterprise Policy & Analytics Platform (Status: Planned)** – off-chain services for AML/KYC integration, sanctions screening, GDPR-aligned workflows, risk analytics, and audit reporting.
- **Enterprise Support Programme (Planned)** – structured support tiers and SLAs.

## 3. Security & Policy/Assurance Posture

See `documentation/enterprise/COMPLIANCE_SECURITY.md` for full details. Key points:

- **Frameworks referenced**: FATF, OFAC, GDPR, SOC 2, ISO 27001, MiCA-style requirements.
- **Certifications**:
  - SOC 2 Type II: In progress (target Q1 2026).
  - ISO 27001: In progress (target Q2 2026).
  - PCI DSS: Planned (target Q3 2026).
- **Controls (design)**:
  - Multi-layer security (network, application, data, key management).
  - AML transaction monitoring and sanctions screening.
  - GDPR-aligned data subject rights (export, erasure, portability).
  - Incident response runbooks and SLAs for security incidents.

> **Important**: These frameworks and certifications describe **intended controls and audit paths**. Actual certification status and scope must be confirmed contractually and may evolve over time.

## 4. Operational Resilience & Governance

- **Operational resilience**:
  - On-chain circuit breaker and emergency pause mechanisms.
  - Token-system-coordinator providing system health views.
  - Incident response checklist and runbooks (`OPERATIONS_RUNBOOK.md`).
- **Governance**:
  - Governance token, proposal engine, proposal registry, and voting modules.
  - Planned council structure and Conxian Operations Engine seat.
  - Planned bonded Guardian network (with CXD bonding and slashing) and a Guardian
    automation SDK/CLI that uses Hiro Core API for monitoring and execution.

For a technical mapping of these elements to regulatory-style objectives, see `REGULATORY_ALIGNMENT.md`.

## 5. APIs & Integration

- **On-chain integration**: Direct Clarity calls via Stacks nodes (Hiro Core API endpoints) for trading, lending, governance, and monitoring.
- **Deployment integration**: StacksOrbit JS/Python APIs and CLI for managing deployments (see `stacksorbit/docs/api.md` and `stacksorbit/README_ENHANCED.md`).
- **Guardian & Automation SDK (Planned)**: TypeScript SDK and reference Guardian client built
  on the same stack as Conxian_UI, enabling institutions to run their own bonded Guardians
  that monitor metrics via Hiro Core API and execute automated on-chain actions.
- **Planned enterprise REST APIs**: Policy, analytics, and audit-oriented endpoints
  described conceptually in `COMPLIANCE_SECURITY.md` and more concretely in
  `API_OVERVIEW.md`.

Integration teams should treat the on-chain and StacksOrbit interfaces as **primary integration points** until REST services are explicitly documented as GA.

## 6. Dependencies & Third Parties

Conxian depends on several external components:

- **Stacks blockchain** (consensus, settlement).
- **Hiro Core API / node infrastructure** for contract queries and transactions.
- **Cloud infrastructure & security providers** (e.g., WAF/DDoS protection) as described in `COMPLIANCE_SECURITY.md`.

Any enterprise deployment should include a supplier risk assessment for these components.

## 7. How to Use This Document in Procurement

- **Scoping**: Use the service list and maturity indicators to define what is in-scope for any proof-of-concept, pilot, or early production engagement.
- **Risk assessment**: Combine this overview with `COMPLIANCE_SECURITY.md` and `REGULATORY_ALIGNMENT.md` to perform technical and operational risk reviews.
- **Contracting**: Treat all SLAs, uptime targets, and certification references in this repository as **inputs to negotiation**, not as binding commitments, until formal contracts are executed.

For additional details, engineering teams should review the underlying contracts and tests in the `Conxian` repository, and operations teams should consult the runbooks and security documentation.
