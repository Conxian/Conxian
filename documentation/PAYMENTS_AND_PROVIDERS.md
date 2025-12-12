# Payments & Providers Design

## 1. Scope & Goals

This document describes how Conxian Labs and regional wrappers interact with external payment and banking providers, while keeping the protocol BTC-aligned and minimising internal compliance burden.

Goals:

- **BTC-first** – protocol-level value flows and reserves prioritise BTC-aligned assets and stablecoins.
- **Provider-agnostic** – on-chain logic does not depend on any specific payment provider.
- **Compliance-aware** – leverage regulated providers for KYC/AML, fiat rails, and reporting, instead of rebuilding them.
- **Standardised outputs** – Conxian Labs provides consistent data exports and "compliance packs" for all providers.

---

## 2. Provider Categories

### 2.1 BTC & Crypto Payroll Providers

Examples (non-exhaustive and non-endorsing):

- Crypto payroll services that accept BTC or stablecoin funding and pay employees/contractors in BTC and/or fiat.
- Lightning or BTC payout services that support bulk payouts.

Role in Conxian:

- Receive BTC or stablecoins withdrawn from Ops / Labs Vault.
- Handle employee/contractor KYC/AML and local payment rails.
- Provide statements and reports to Conxian Labs for accounting and tax.

### 2.2 Open-Banking & Multi-Currency Payment Providers

Examples (non-exhaustive and non-endorsing):

- Open-banking platforms and multi-currency business account providers.
- Regional payment providers with South African coverage for ZAR payouts.

Role in Conxian:

- Provide business accounts and APIs for:
  - Paying staff and vendors in local currency.
  - Managing FX from BTC/stable holdings.
- Implement strong KYC/AML and transaction monitoring on their side.

### 2.3 Traditional Banking Relationships

- Corporate bank accounts held by Conxian Labs and regional wrappers.
- Used where required for regulatory, tax, or payroll reasons.

---

## 3. On-Chain vs Off-Chain Responsibilities

### 3.1 On-Chain (Conxian Protocol & DAO)

- Track and allocate protocol revenues via:
  - Revenue Router and Allocation Policy (`TREASURY_AND_REVENUE_ROUTER.md`).
  - Vaults holding BTC-aligned assets, stables, and other tokens.
- Record **intent and category** of payments:
  - Salary/retainer streams.
  - Guardian rewards.
  - Bounties and grants.
  - Regional wrapper funding.

On-chain records include principals, assets, amounts, and tags, but never PII.

### 3.2 Off-Chain (Conxian Labs & Regional Wrappers)

- Maintain KYC/KYB files, HR records, and vendor contracts.
- Operate provider integrations for:
  - BTC/crypto payroll.
  - Open-banking/multi-currency payments.
  - Traditional banking where necessary.
- Map on-chain entries (streams, bounties, withdrawals) to:
  - Accounting entries.
  - Tax and regulatory reports.

---

## 4. Standardised Outputs ("Compliance Packs")

To keep providers and regulators plug-and-play, Conxian Labs defines stable export formats.

### 4.1 Identity & KYC/KYB Pack

- Derived from `IDENTITY_KYC_POPIA.md` and off-chain identity systems.
- Contains, per subject (internal ID):
  - Internal subject ID and role (e.g. employee, guardian, vendor).
  - KYC/KYB tier and provider used.
  - Jurisdiction(s) and relevant status flags.
- Excludes PII in raw exports used for protocol or general sharing.

### 4.2 Treasury & Revenue Pack

- Derived from:
  - Vault balances and routing events.
  - Allocation policies.
- Includes:
  - Asset balances per vault.
  - Historical fee inflows by source-tag and allocation.
  - Summary of protocol revenues allocated to Ops, guardians, risk, and grants.

### 4.3 Payments & Payroll Pack

- Maps on-chain payment entries to recipient categories:
  - Guardians.
  - Labs staff.
  - Regional wrappers.
  - Bounty and grant recipients.
- Includes tags for:
  - Salary/retainer.
  - Bonus.
  - Bounty.
  - Grant.
- Helps providers and accountants classify flows correctly.

### 4.4 Incident & Risk Pack

- Derived from monitoring and incident logs.
- Includes:
  - Circuit breaker activations.
  - Major loss events.
  - Insurance payouts.
  - Governance decisions related to risk.

These packs can be generated periodically or on demand for regulators, auditors, and key providers.

---

## 5. Integration Patterns

### 5.1 BTC-Heavy Model (Crypto Payroll Centric)

- Conxian Labs keeps a significant portion of Ops budget in BTC/stables.
- Steps:
  1. DAO funds Ops / Labs Vault via Revenue Router.
  2. Labs withdraws BTC/stables to its custody.
  3. Labs funds BTC payroll provider.
  4. Provider pays employees/contractors in BTC or local fiat.
- Compliance load:
  - Conxian Labs manages KYB/KYC with provider.
  - Provider manages end-recipient rails and AML.

### 5.2 Hybrid Model (Crypto + Open-Banking)

- For some recipients:
  - BTC payroll provider.
- For others:
  - Open-banking provider or direct bank payments.
- Same on-chain funding pattern, with off-chain rules deciding which rail to use.

### 5.3 Crypto-Only Model (Where Appropriate)

- For DeFi-native contributors and some guardians:
  - On-chain payouts in BTC-aligned assets or stables.
- Recipients handle local conversion and tax in their jurisdictions.
- Used selectively, respecting legal and policy constraints.

---

## 6. Compliance Considerations

- Conxian Labs remains responsible for:
  - POPIA compliance over personal data.
  - SA tax and corporate filings.
  - KYB and vendor due diligence.
- Providers carry substantial responsibility for:
  - KYC/AML of end recipients.
  - Transaction monitoring and reporting under their local regimes.

The design aims to minimise duplicated compliance work by:

- Using standard on-chain records and export formats.
- Centralising off-chain compliance and provider relations in Conxian Labs and authorised wrappers.

---

## 7. Governance & Evolution

- The DAO approves:
  - High-level provider categories.
  - Budget allocations per vault.
  - Major changes in payout and provider strategies.
- Conxian Labs and regional wrappers:
  - Select specific providers within DAO-approved categories.
  - Are accountable for provider performance and compliance.

This document should evolve as new provider categories emerge and regulatory expectations change.
