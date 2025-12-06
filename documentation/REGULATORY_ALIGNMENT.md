# Conxian Regulatory & Policy Alignment

This document maps key Conxian modules and tests to regulatory-style objectives: user protection, prudential safety, market integrity, and operational resilience.

It is **not** legal advice, but a technical alignment guide to support audits, internal risk reviews, and external regulators.

---

## 1. User Protection & Fair Treatment

### 1.1 Tokens (CXD, CXVG, CXLP, CXTR, CXS)

- **Contracts**
  - `cxd-token.clar`, `cxvg-token.clar`, `cxlp-token.clar`, `cxtr-token.clar`, `cxs-token.clar`.
- **Key protections**
  - Access control on minting and ownership.
  - Balance and total supply invariants.
  - Clear error codes for insufficient balance and unauthorized actions.
- **Tests**
  - `tests/governance/governance-token.test.ts`
  - `tests/integration/token-system-coordinator.test.ts`
- **Regulatory rationale**
  - Prevents unauthorized dilution of token holders.
  - Ensures correct accounting of voting power and economic rights.

### 1.2 Lending (User-Level Safety)

- **Contract**
  - `comprehensive-lending-system.clar`
- **Key protections**
  - Reject zero-amount supply/borrow/repay/withdraw (`ERR_ZERO_AMOUNT`).
  - Health factor checks before borrow (`ERR_INSUFFICIENT_COLLATERAL`).
  - Explicit error codes for insufficient balances.
- **Tests**
  - `tests/lending/comprehensive-lending-system.test.ts`
- **Regulatory rationale**
  - Avoids ambiguous or unsafe user operations.
  - Enforces conservative collateralization, reducing default risk to other users.

---

## 2. Prudential Safety & Capital Protection

### 2.1 Reserves & Revenue (Interest Rate Model + Lending)

- **Contracts**
  - `interest-rate-model.clar`
  - `comprehensive-lending-system.clar`
  - `protocol-fee-switch.clar`
- **Key controls**
  - Interest accrual with explicit tracking of `total-reserves`.
  - Separation of reserves, cash, borrows, and supplies.
  - Withdrawal of reserves routed via the fee switch.
- **Tests**
  - `tests/lending/interest-rate-model.test.ts`
  - `tests/core/protocol-fee-switch.test.ts`
  - `tests/integration/full-system-fee-insurance.test.ts`
- **Regulatory rationale**
  - Explicit reserve accounting supports prudential oversight.
  - Fee routing to treasury, staking, and insurance supports loss-absorbing capacity.

### 2.2 Insurance Fund

- **Contract**
  - `conxian-insurance-fund.clar`
- **Key controls**
  - Governance-only configuration of staking token.
  - Staking and cooldown for withdrawals.
- **Tests**
  - `tests/security/conxian-insurance-fund.test.ts`
- **Regulatory rationale**
  - Encourages long-term, locked capital supporting protocol solvency.
  - Reduces run risk via cooldown periods.

---

## 3. Market Integrity & Oracle Governance

### 3.1 TWAP Oracle

- **Contract**
  - `twap-oracle.clar`
- **Key controls**
  - Governance-only `update-twap`.
  - Validation of periods and explicit `ERR-NO-DATA` error.
- **Tests**
  - `tests/oracle/twap-oracle.test.ts`
- **Regulatory rationale**
  - Ensures price feeds cannot be updated by arbitrary accounts.
  - Provides clear error semantics for missing data, supporting robust downstream handling.

### 3.2 MEV Protection & Circuit Breaker

- **Contracts**
  - `mev-protector.clar`
  - `circuit-breaker.clar`
  - `comprehensive-lending-system.clar` (via `check-circuit-breaker`).
- **Tests**
  - `tests/security/mev-protector.test.ts`
  - `tests/monitoring/circuit-breaker.test.ts`
  - Lending tests extended to assert that an open circuit halts operations.
- **Regulatory rationale**
  - MEV controls and global kill-switch reduce unfair trading advantages and systemic incident scope.
  - Supports requirements for orderly markets and emergency handling.

---

## 4. Governance & Change Control

### 4.1 Governance Token & Voting

- **Contracts**
  - `governance-token.clar`
  - `proposal-registry.clar`
  - `proposal-engine.clar`
  - `governance-voting.clar`
- **Key controls**
  - Ownership-gated parameter changes.
  - Voting period and quorum settings.
  - Quorum requirements for execution (`quorum >= quorum-percentage`).
- **Tests**
  - `tests/governance/governance-token.test.ts`
  - `tests/governance/proposal-registry.test.ts`
  - `tests/governance/proposal-engine-admin.test.ts`
- **Regulatory rationale**
  - Ensures major changes (fees, risk parameters) follow transparent, token-holder governed processes.
  - Quorum and voting windows reduce governance capture and rushed decisions.

---

## 5. Operational Resilience & Monitoring

### 5.1 Token System Coordinator

- **Contract**
  - `token-system-coordinator.clar`
- **Key controls**
  - System-level health metrics (`get-system-health`).
  - Emergency pause and emergency mode flags.
  - Cross-token user activity tracking.
- **Tests**
  - `tests/integration/token-system-coordinator.test.ts`
- **Regulatory rationale**
  - Provides a consolidated view on system status for operations and regulators.
  - Supports auditability of user activity patterns.

### 5.2 Documentation & Testing Framework

- **Artifacts**
  - `README.md`, `ROADMAP.md`.
  - `SECURITY_REVIEW_PROCESS.md`.
  - Test framework documentation.
- **Key practices**
  - Targeted coverage thresholds (80%+ general, 95%+ critical).
  - Dimension-based test suites (DEX, Lending, Governance, Oracle, Risk, Dimensional Core).
- **Regulatory rationale**
  - Structured testing and review process demonstrates ongoing operational due diligence.
  - Facilitates external audits and supervisory reviews.

---

## 6. Gaps & Future Work

The following areas are identified for further alignment work:

- **Stress & Scenario Testing**
  - Multi-step economic scenarios (DEX → Fees → Lending → Insurance) under stress.
  - Tail-risk simulations for correlated asset failures and oracle disruptions.
- **Formal Policy Mapping**
  - Mapping specific jurisdictional rules (e.g. consumer protection, prudential standards) to individual contracts and tests.
- **Off-Chain Processes**
  - Runbooks for governance proposal reviews.
  - Expanded incident playbooks and SLAs.

These items should be tracked as separate enhancements and validated via additional tests and documentation updates.
