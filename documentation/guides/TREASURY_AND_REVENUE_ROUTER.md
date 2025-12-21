# Conxian Treasury and Revenue Router Design

## 1. Objectives

This document specifies the treasury and revenue routing architecture for Conxian. The goal is to ensure that all protocol revenues and expenditures are:

- **Transparent** – all flows are visible and traceable on‑chain.
- **Programmable** – allocation policies can be updated via governance.
- **Modular** – products plug into a shared router instead of hardcoding splits.
- **Global‑ready** – the Conxian DAO can fund guardians, risk reserves, Conxian Labs and future regional entities from a single coherent system.

---

## 2. Core Components

### 2.1 Treasury Vaults

Conxian uses logical vaults (implemented as one or more contracts) to hold protocol assets. At minimum:

- **Protocol Treasury Vault**
  - Holds long‑term reserves in CXVG, BTC‑aligned assets, stables and other tokens.
  - Funds R&D, ecosystem grants, liquidity bootstrapping and long‑horizon initiatives.

- **Guardian Rewards Vault**
  - Dedicated balance for paying guardians/validators/keepers.
  - Feeds into staking reward logic and any streaming/vesting payment contracts.

- **Risk & Insurance Reserves Vault**
  - Holds reserves backing insurance/cover products, bad‑debt buffers and emergency response.
  - Payouts from this vault are governed by on‑chain risk and claims logic.

- **Ops / Conxian Labs Vault**
  - Budget for off‑chain operations executed by Conxian Labs (legal, compliance, infra, core contributors).
  - Conxian Labs converts assets from this vault to fiat or other forms as needed, under board/DAO oversight.

- **Optional Special‑Purpose Vaults**
  - **Legal Bounties Vault** – funds on‑chain legal and policy bounties.
  - **Regional Ops Vaults** – per‑jurisdiction wrappers if the DAO adds new legal entities outside South Africa.

Each vault exposes at least:

- `deposit(asset, amount)` – increase the vault balance.
- `withdraw(asset, amount, to)` – controlled by specific roles/policies.
- Read‑only views for analytics and accounting.

### 2.2 Revenue Router

A central **Revenue Router** contract receives protocol fees from products and distributes them to vaults according to policy.

- **Inputs**
  - Called by approved product contracts (DEX pools/factory, lending markets, insurance, bridges, MEV protection, structured products).
  - Canonical entrypoint shape (conceptual):
    - `route-fee(asset, amount, source-tag, product-id)`

- **Responsibilities**
  - Validate the caller against an allow‑list of approved products.
  - Optionally normalise incoming assets (e.g. swap a portion into a canonical treasury asset via DEX calls, subject to risk constraints).
  - Query the **Allocation Policy** for the given `source-tag`.
  - Split `amount` across the configured vaults.
  - Call `deposit` on the relevant vaults.
  - Emit detailed events for each routing operation:
    - `{ source-tag, product-id, asset, amount, allocations: {...} }`.

### 2.3 Allocation Policy Module

Allocation logic is separated from routing mechanics in an **Allocation Policy** module.

- **State**
  - For each `source-tag` (and optionally per product):
    - A set of basis‑point (bps) percentages for each destination vault, e.g. `{ guardian-bps, risk-bps, treasury-bps, ops-bps, legal-bps, ... }`.

- **Functions**
  - `get-allocation(source-tag) -> { guardian-bps, risk-bps, treasury-bps, ops-bps, ... }`
  - Governance/Ops‑controlled updates:
    - `set-allocation(source-tag, guardian-bps, risk-bps, treasury-bps, ops-bps, ...)`

- **Constraints**
  - Sum of bps values must equal a fixed constant (e.g. `u10000` for 100%).
  - Optional minimum/maximum bounds per vault (e.g. ensure at least X% of certain revenues flow to risk reserves, cap the Ops share).

The router is responsible for execution; the policy module defines **who gets what**.

---

## 3. Revenue Flows from Products

Products do not hardcode revenue splits. Instead, each product computes the fee it owes to the protocol and calls the Revenue Router.

### 3.1 DEX Swap Fees

- DEX pools compute swap fees on each trade.
- The pool or factory contract calls:
  - `route-fee(asset, fee-amount, "DEX_SWAP", pool-id)`.
- Router:
  - Looks up allocation for `"DEX_SWAP"`.
  - Splits `fee-amount` among vaults.
  - Deposits to the appropriate vaults.

### 3.2 Lending Interest

- Lending markets compute net protocol interest (after depositor share).
- Call:
  - `route-fee(asset, interest-amount, "LENDING_INTEREST", market-id)`.
- Allocation typically favours:
  - Risk & Insurance Reserves Vault (bad‑debt buffers).
  - Guardian Rewards Vault (liquidation incentives, monitoring).
  - Protocol Treasury Vault.

### 3.3 Insurance Premiums

- Protection/cover contracts collect premiums.
- A portion is reserved internally for claims; a portion is routed as protocol revenue:
  - `route-fee(asset, premium-share, "INSURANCE_PREMIUM", product-id)`.
- Allocations can prioritise:
  - Risk & Insurance Reserves Vault.
  - Legal Bounties Vault (for regulatory research and product approvals).
  - Protocol Treasury Vault.

### 3.4 Bridge Fees

- Cross‑chain bridges charge a fee per transfer.
- Call:
  - `route-fee(asset, fee-amount, "BRIDGE_FEE", bridge-id)`.
- Allocations may:
  - Heavily favour Guardian Rewards Vault (bridge guardians).
  - Contribute to Risk & Insurance Reserves (bridge failure buffers).
  - Send a smaller share to Treasury and Ops.

Other product‑specific tags can be introduced as Conxian adds more modules.

---

## 4. Expenditure Buckets and Vault Mapping

This section maps major expenditure categories to their funding vaults.

### 4.1 On‑Chain Protocol Expenditures

- **Guardian / Validator Rewards**
  - Paid from: Guardian Rewards Vault.
  - Funded by: portions of DEX, lending, bridge and MEV‑related fees.

- **Risk & Insurance Payouts**
  - Paid from: Risk & Insurance Reserves Vault.
  - Funded by: insurance premiums plus a share of lending/DEX revenues.

- **Liquidity / Growth Incentives**
  - Paid from: Protocol Treasury Vault or a dedicated Growth Vault.
  - Funded by: flexible share of overall protocol revenues.

- **Security & Audit Bounties**
  - Paid from: Security/Grants bucket within the Treasury.
  - Funded by: allocations from the Treasury and/or high‑risk product revenues.

- **Legal / Policy Bounties**
  - Paid from: Legal Bounties Vault.
  - Funded by: a configured fraction of protocol revenues or explicit DAO transfers.

- **Ecosystem Grants**
  - Paid from: Protocol Treasury Vault or a dedicated Grants Vault.
  - Funded by: long‑term treasury allocations via DAO governance.

### 4.2 Off‑Chain Conxian Labs Expenditures

Conxian Labs handles off‑chain costs but is funded on‑chain from the Ops / Conxian Labs Vault.

- **Team Compensation** (salaries, contractors, benefits).
- **Infrastructure** (nodes, indexers, monitoring, CI, storage).
- **Legal & Compliance Retainers** (SA counsel, international counsel, licensing).
- **KYC/KYB and Data Providers** (identity vendors, sanctions screening, analytics).
- **Accounting & Tax** (bookkeeping, audits, tax advisory).
- **Business Development, Marketing, Research**.

The DAO sets an allocation cap for the Ops / Conxian Labs Vault (e.g. a maximum share of total protocol revenues) to preserve long‑term protocol solvency.

### 4.3 Regional Ops Wrappers

If the DAO establishes additional legal entities in other jurisdictions, each can be assigned:

- A dedicated **Regional Ops Vault**.
- A small allocation slice from the router.

This enables global operations while keeping the core architecture and contracts unchanged.

---

## 5. Governance and Safety

### 5.1 Who Controls What

- **Conxian DAO**
  - Owns the Allocation Policy module.
  - Approves changes to allocation percentages and the creation/removal of vaults.
  - Authorises large grants and strategic use of treasury funds.

- **Conxian Labs**
  - Has spending authority only over the Ops / Conxian Labs Vault and any explicitly assigned vaults.
  - Must operate within the on‑chain budgets set by the DAO; larger budgets require updated allocations or explicit DAO transfers.

- **Protocol Modules (Risk, Guardians, Insurance, Legal Bounties)**
  - Guardian staking and rewards modules pull from Guardian Rewards Vault under predefined rules.
  - Insurance and risk contracts pull from the Risk & Insurance Reserves Vault for claims and bad‑debt coverage.
  - Legal bounty modules draw from the Legal Bounties Vault when tasks are completed and accepted.

### 5.2 Constraints and Checks

- Allocation updates are gated by governance proposals and may require:
  - Risk manager consultation (e.g. checking reserve sufficiency).
  - Operations Engine checks (e.g. cooldowns or quorum requirements).
- Hard constraints can be encoded in the Allocation Policy:
  - Minimum share to Risk & Insurance Reserves for certain tags.
  - Maximum share to Ops / Conxian Labs to avoid treasury drain.

### 5.3 Transparency

- Router and vault contracts must emit structured events for:
  - Every revenue routing operation.
  - Every allocation policy change.
  - Significant vault withdrawals.
 - Off‑chain analytics, accounting and tax tools consume these events to build ledgers for Conxian Labs and any regional entities.

---

## 6. Identity, KYC/KYB and Policy Hooks

- Access to certain reward streams or bounties may require minimum **KYC/KYB tiers**, as defined in the Identity, KYC & POPIA Charter.
  - Guardian rewards: typically Tier 1 or 2.
  - Legal bounties: Tier 2 or 3 (verified professionals or institutions).
  - Large grants: appropriate tiers plus additional due diligence.
- Vaults and routers should not store PII; they only enforce access conditions via:
  - On‑chain KYC/KYB tiers and flags.
  - Role checks managed by governance and Operations.

This ties financial flows and operations to the same identity and policy/control framework used across Conxian.

---

## 7. Open Questions and Next Steps

- Decide whether to implement vaults as separate contracts or a single multi‑bucket vault.
- Determine which assets should be held natively versus normalised into canonical treasury assets.
- Define per‑product allocation profiles (e.g. more conservative routing for riskier markets).
- Implement the Revenue Router, Allocation Policy and Vault contracts on Stacks.
- Integrate the router with existing products (DEX, lending, insurance, bridge) as the single ingress for protocol fees.
- Update ROADMAP and whitepaper to reference this design and its rollout phases.
