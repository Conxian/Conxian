# Conxian Payroll, Rewards & Bounties Design

## 1. Scope & Goals

This document defines how Conxian distributes value to Guardians, contributors, Conxian Labs, regional wrappers, and bounty recipients.

Goals:

- **Consistency** – all payments are funded from the vaults and routing rules in `TREASURY_AND_REVENUE_ROUTER.md`.
- **Transparency** – every payment can be traced back to protocol revenues.
- **Compliance-aware** – flows respect KYC/KYB tiers and POPIA constraints from `IDENTITY_KYC_POPIA.md`.
- **Modularity** – on-chain payment patterns are generic; specific providers and rails are off-chain.

---

## 2. Funding Sources

All payments originate from treasury vaults described in `TREASURY_AND_REVENUE_ROUTER.md`:

- **Guardian Rewards Vault** – Guardian/validator rewards.
- **Risk & Insurance Reserves Vault** – Risk and insurance payouts.
- **Ops / Conxian Labs Vault** – Off-chain operations (salaries, infra, legal, KYC vendors).
- **Legal Bounties Vault** – Legal and policy bounties.
- **Grants / Growth Vaults (optional)** – Ecosystem grants, growth incentives.

The Revenue Router allocates protocol fees into these vaults based on DAO-approved policies.

---

## 3. Guardians & Automation Rewards

### 3.1 Reward Types

- **Base Reward Stream**
  - Periodic allocation from Guardian Rewards Vault based on stake, role, and performance.
  - Intended to compensate ongoing monitoring and automation duties.

- **Per-Action Rewards**
  - Rewards tied to discrete on-chain actions such as:
    - Liquidations.
    - Bridge finalisations.
    - Oracle updates.
    - Governance execution tasks.

- **Slashing & Penalties**
  - Reductions in stake and/or accrued rewards for misbehaviour or persistent failure.

### 3.2 Accounting Pattern (Conceptual)

- Guardian staking module maintains per-guardian accounting:
  - `stake`, `performance-score`, `accrued-rewards`.
- At the end of an epoch or when triggered:
  - A `distribute-guardian-rewards()` function:
    - Pulls a configured amount from Guardian Rewards Vault.
    - Updates `accrued-rewards` for each eligible guardian.
- Guardians claim via `claim-rewards()`:
  - Requires meeting minimum KYC/KYB tier.
  - Must not be under active slashing or suspension.

On-chain logic intentionally avoids PII and only uses principals and tiers.

---

## 4. Conxian Labs & Regional Wrappers (Ops Payroll)

### 4.1 Streams & Vesting

Conxian Labs and any authorised regional wrappers may set up streams and vesting schedules funded from the Ops or Regional Ops vaults.

- **Streams (Retainers / Salaries)**
  - Conceptual contract: `payroll-streams.clar`.
  - Functions:
    - `create-stream(recipient, asset, total-amount, start-block, end-block, tag)`.
    - `withdraw-from-stream(stream-id)` – release up to the amount vested at `block-height`.
    - `cancel-stream(stream-id)` – return unvested funds to the funding vault, subject to policy.
  - Tags describe purpose:
    - `LABS_SALARY`, `LABS_CONTRACTOR`, `REGIONAL_WRAPPER`, etc.

- **Vesting (Long-Term Alignment)**
  - For token-based compensation (e.g. CXVG or other governance tokens).
  - Implemented via time-locked vesting contracts to encourage long-term alignment.

### 4.2 Identity & POPIA Considerations

- On-chain:
  - Streams and vesting contracts reference only recipient principals and tags.
  - No names, ID numbers, or other personal data.
- Off-chain (Conxian Labs):
  - Maintains HR and payroll records and handles POPIA rights.
  - Maps streams and tags to employees or vendors in internal systems.

---

## 5. Bounties & Grants

### 5.1 Technical & Security Bounties

- **Scope**
  - Code contributions, bug fixes, security vulnerabilities, performance improvements.
- **Funding**
  - Typically from Grants/Growth Vaults or a dedicated Security/Grants bucket in Treasury.
- **Pattern**
  - `create-bounty(reward, scope, tag)`.
  - `submit-work(bounty-id, principal, work-hash)`.
  - `approve-and-pay(bounty-id, principal)` – via DAO or delegated Ops.

### 5.2 Legal & Policy Bounties

- See also `LEGAL_REPRESENTATIVES_AND_BOUNTIES.md`.
- **Scope**
  - Regulatory research, policy memos, licensing support, incident analysis.
- **Funding**
  - Legal Bounties Vault.
- **Pattern**
  - Same as technical bounties, with tags like `LEGAL_POLICY_MEMO_ZA`, `MICA_ANALYSIS`, etc.

### 5.3 Ecosystem Grants

- **Scope**
  - New integrations, frontends, risk tools, educational content.
- **Funding**
  - Grants/Growth Vaults or Protocol Treasury.
- **Pattern**
  - Larger, often multi-milestone streams or vesting schedules, authorised via DAO governance.

---

## 6. KYC/KYB Tiers & Eligibility

Payments and rewards must comply with identity and data protection standards from `IDENTITY_KYC_POPIA.md`.

- **Guardians**
  - Community guardians: Tier 1 or higher.
  - Professional guardians: Tier 2 or higher.

- **Conxian Labs & Regional Wrappers**
  - Entities themselves: KYB Tier 2 or 3.
  - Staff and contractors: appropriate individual KYC tier as determined by Labs.

- **Legal & Policy Providers**
  - Legal bounties and retainers: Tier 2 or 3.

- **Grantees & Bounty Hunters (Technical)**
  - Tier 0 or 1 may be acceptable for small, on-chain-only rewards, subject to risk policies.
  - Higher tiers may be required for large or recurring payments.

On-chain contracts enforce tiers via shared identity registry calls; detailed verification remains off-chain.

---

## 7. Relationship to External Payment Providers

The on-chain payroll and rewards design is agnostic to specific payment rails.

- Conxian Labs may use:
  - BTC payroll services.
  - Open-banking or multi-currency payout providers.
  - Traditional banking arrangements.

For flows that leave the chain (e.g. to fiat bank accounts), Labs:

- Withdraws from appropriate vaults.
- Executes off-chain payments via providers.
- Maintains accounting and tax records.

The on-chain system provides a canonical, tag-rich ledger of value flows that providers and auditors can reference.

---

## 8. Governance & Upgrades

- The DAO defines global reward policies, caps, and eligible roles.
- Updates to reward parameters, vesting curves, or bounty structures must:
  - Pass through governance proposals.
  - Be reflected in this document and related runbooks.
- Conxian Labs must align off-chain HR, payroll, and vendor agreements with the current on-chain rules.

This design should evolve with feedback from Guardians, contributors, Labs, and external auditors.
