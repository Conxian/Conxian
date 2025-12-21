# Conxian Guardian Network & FSCA Alignment

## 1. Purpose and Scope

This document defines how the **Conxian Guardian Network** (guardians, keepers, bridge/oracle operators) is designed, funded and governed so that it:

- Protects users and counterparties from operational and economic harm.
- Aligns with **FSCA / IFWG** expectations on outsourcing, conduct and operational resilience.
- Integrates cleanly with the broader **identity, KYC/KYB and POPIA** model.
- Remains **on-chain first and BTC-aligned**, with clear separation between protocol logic and off-chain operations.

It is a companion to:

- `IDENTITY_KYC_POPIA.md` – identity and tiered KYC/KYB charter.
- `REGULATORY_ALIGNMENT.md` – system-wide mapping to regulatory objectives.
- `PAYROLL_AND_REWARDS.md` – global rewards and payroll structure.

---

## 2. Guardian Network Components (On-Chain)

The Guardian Network is implemented across several contracts:

- **`contracts/automation/guardian-registry.clar`**
  - Maintains the **guardian set**.
  - Handles **bonding** in CXD, **tiering**, **rewards accrual** and **slashing**.

- **`contracts/automation/keeper-coordinator.clar`**
  - Registers **keepers / automation targets**.
  - Assigns and authorises tasks that guardians and keepers can execute.

- **`contracts/interoperability/wormhole-inbox.clar`**
  - Tracks **guardian-set index** for cross-chain messages.
  - Enforces idempotency and correct guardian-set usage for incoming bridge payloads.

- **`contracts/governance/lending-protocol-governance.clar`**
  - Defines `ROLE_GUARDIAN` and governance flow for time-locked, high-impact changes.

- **Other dependent modules** (examples)
  - `contracts/cross-chain/bridge-nft.clar` – NFT representation of bridged positions; indirectly secured by guardians.
  - `contracts/insurance/insurance-protection-nft.clar` – protection products backed by reserves and guardian-driven risk signals.

These components together ensure that **critical actions** (liquidations, bridge handling, oracle interactions, emergency operations) are executed by **bonded, accountable** actors.

---

## 3. Risk Categories and Controls

### 3.1 Operational Risk (Execution Failures, Negligence)

- **Risk**: Guardians or keepers fail to execute tasks (e.g. liquidations, rebalances), causing user harm.
- **Controls**:
  - Guardians must register and **bond CXD** in `guardian-registry.clar`.
  - `keeper-coordinator.clar` provides a registry of valid automation targets and enables rotation.
  - Off-chain monitoring (via StacksOrbit + Hiro API) checks that tasks are executed within expected windows.
  - **Slashing** in `guardian-registry.clar` allows governance/operations to dock bonded CXD for systematic failure.

### 3.2 Integrity & Malicious Behaviour

- **Risk**: Colluding guardians manipulate or ignore oracle/bridge events or seek to front-run users.
- **Controls**:
  - Guardians are **economically bonded** and can be **slashed** for provable misbehaviour.
  - Critical services (bridges, oracles) must be run by **committees**, not single operators.
  - Governance contracts (`lending-protocol-governance.clar` and broader DAO stack) can:
    - Rotate guardians.
    - Adjust minimum bonds.
    - Redirect rewards and tighten parameters based on observed behaviour.

### 3.3 Counterparty / Concentration Risk

- **Risk**: Over-reliance on a small set of guardians, or guardians that are not appropriately capitalised.
- **Controls**:
  - **Tiered bonding requirements** in `guardian-registry.clar` – higher tiers for higher-impact roles.
  - Ability to **diversify** the guardian set (community vs professional operators) with different reward rates.
  - Optional limits on **per-guardian exposure** via governance parameters.

### 3.4 Legal, Licensing and Regulatory Risk

- **Risk**: Guardians operate in ways inconsistent with local licensing or regulatory expectations.
- **Controls**:
  - Guardians are mapped to **KYC/KYB tiers** as defined in `IDENTITY_KYC_POPIA.md`.
  - Higher-impact roles (bridge/oracle committees, operations engine executors) require **Tier 2+** (enhanced KYC/KYB) or institutional status.
  - Off-chain agreements and disclosures are handled by **Conxian Labs** with professional guardians.
  - On-chain contracts expose **transparent roles and events**, supporting audit and supervisory review.

### 3.5 Data Protection and POPIA

- **Risk**: Guardian identity or personal data is mishandled.
- **Controls**:
  - On-chain contracts **never store PII**; they only reference principals and KYC tier flags.
  - Off-chain systems (Conxian Labs + partners) store KYC data under POPIA-aligned policies and expose only **tiered status** on-chain.

---

## 4. FSCA / IFWG Alignment

The design aligns with key FSCA/IFWG themes:

### 4.1 User Protection and Fair Treatment

- **Transparent roles and incentives**:
  - Guardian bonding, rewards and slashing rules are encoded on-chain and testable.
  - Events allow users and auditors to see **who is empowered** and **how they are rewarded**.
- **Incident response**:
  - Operations runbooks (see `OPERATIONS_RUNBOOK.md`) define how guardians respond to incidents and how users are protected.

### 4.2 Prudential Safety and Capital at Risk

- Guardians put **CXD capital at risk** as a precondition for operating.
- Slashing and reduced rewards can recapitalise **treasuries or insurance funds** in case of failures.
- Ties into `TREASURY_AND_REVENUE_ROUTER.md` and the insurance fund design for loss absorption.

### 4.3 Market Integrity and Outsourcing

- Guardian and keeper functions are a form of **technology / operational outsourcing**.
- Controls include:
  - Documented responsibilities and SLAs in off-chain agreements.
  - On-chain capabilities that allow rapid **rotation** and **deactivation**.
  - Logging and monitoring through StacksOrbit and the Operations Engine.

### 4.4 Operational Resilience

- Multiple guardians/keepers per task to avoid single points of failure.
- Circuit breakers and MEV protections (see `REGULATORY_ALIGNMENT.md`) work together with guardians for **safe halts** and restarts.

---

## 5. Where Off-Chain Governance & Policy Plug In

Off-chain governance and policy primarily act through:

- **Identity and Tiering**
  - KYC/KYB decisions and sanctions/adverse media screening are performed off-chain.
  - On-chain, `guardian-registry.clar` and related modules consume **tier signals** and flags.

- **Guardian Onboarding & Offboarding Process**
  - Conxian Labs (or equivalent operations entity) runs an onboarding process:
    - Perform KYC/KYB and risk assessment.
    - Map the applicant to a guardian tier and allowed roles.
    - Trigger on-chain registration and bonding.
  - Offboarding is initiated when:
    - Policy status changes (e.g. sanctions, licence loss).
    - Guardian breaches operational or economic thresholds.

- **Policy and Parameter Governance**
  - DAO and Operations governance contracts manage:
    - Minimum bond sizes per tier.
    - Reward rates and emission schedules.
    - Slashing policies and appeal mechanisms.
  - Proposals can be structured to clearly signal **regulatory-relevant changes** (e.g. changes to outsourcing reliance or capital at risk).

---

## 6. Contract-Level Mapping

This section links core guardian-related contracts to their policy/control roles:

- **`guardian-registry.clar`**
  - Encodes **who is a guardian**, how much they have at risk, and their reward accrual.
  - Provides **slashing** hooks and view functions for off-chain monitoring.

- **`keeper-coordinator.clar`**
  - Records **automation targets** and which principals are authorised to execute them.
  - Enables periodic audits of which off-chain services are effectively being outsourced.

- **`wormhole-inbox.clar`**
  - Enforces that only messages associated with the correct guardian-set index are accepted.
  - Supports auditability of cross-chain message handling.

- **Governance contracts (e.g. `lending-protocol-governance.clar`)**
  - Define `ROLE_GUARDIAN` and related roles.
  - Gate **high-impact parameter changes** behind transparent, token-holder governance.

---

## 7. Open Questions and Future Work

- **Formalising guardian SLAs and policies**
  - Exact thresholds for "failing performance" and associated slashing levels.
  - Differentiation between community guardians and professional operators.

- **FSCA-facing documentation**
  - Standardised summaries of outsourcing arrangements and capital at risk.
  - Pre-defined reporting templates linking on-chain metrics to regulatory categories.

- **Further integration with KYC/KYB tiers**
  - Hardening which KYC tiers are required for which guardian roles.
  - Defining escalation flows when identity or risk status changes.

- **Automation of monitoring**
  - Expanded use of StacksOrbit and guardian SDK modules to automatically:
    - Detect SLA breaches.
    - File governance proposals for role rotation or parameter updates.

This document should be updated alongside changes to `guardian-registry.clar`, automation contracts, and the broader regulatory and KYC/KYB framework.
