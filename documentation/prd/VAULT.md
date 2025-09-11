# Conxian PRD: Vault Core

| | |
|---|---|
| **Status** | 🔄 Framework Implementation |
| **Version** | 1.2 |
| **Owner** | Protocol WG |
| **Last Updated** | 2025-08-26 |
| **References** | AIP-1, AIP-5, [Architecture](../ARCHITECTURE.md), `vault.clar` (framework implemented) |

---

## 1. Summary & Vision

The Vault is Conxian's core capital aggregation framework primitive. It provides a foundational structure for standardized, secure asset management with proportional share-based accounting. The vision is to create a framework foundation for yield strategies that is simple, extensible through traits, with basic security patterns and accounting structures.

## 2. Goals / Non-Goals

### Goals
- **Framework Accounting**: Provide basic share-based accounting framework for pooled assets, with rounding protection structure (AIP-5).
- **Framework Efficiency**: Maintain a minimal interface framework for core deposit and withdrawal operations structure.
- **Framework Extensibility**: Serve as a base framework layer for yield strategies without embedded strategy logic. Framework extensibility via Strategy and Admin trait structures.
- **Framework Security**: Implement basic access control framework, reentrancy safety structure, and emergency pause mechanism framework (AIP-1).

### Non-Goals
- **Internal Strategy Logic**: The vault does not define or execute yield strategies. This is delegated to external strategy contracts.
- **Complex Rebalancing**: On-chain rebalancing logic is not a feature of this core vault.
- **Direct Governance**: The vault itself is not a DAO; it is administered by the Conxian DAO via timelocked calls.

## 3. User Stories

| ID | As a... | I want to... | So that... | Priority |
|---|---|---|---|---|
| VAULT-US-01 | User | Deposit tokens into the vault | I can receive proportional shares representing my stake in the pooled assets. | P0 |
| VAULT-US-02 | User | Redeem my shares from the vault | I can get back my underlying assets, less any accrued fees. | P0 |
| VAULT-US-03 | Governance Admin | Set and adjust deposit caps and fees | I can manage risk and control revenue generation for the protocol. | P0 |
| VAULT-US-04 | Automation Module| Adjust operational parameters within safe constraints | The system can self-regulate based on predefined conditions. | P1 |
| VAULT-US-05 | Protocol Auditor | View all critical state and parameters | I can verify the health and security of the vault at any time. | P0 |

## 4. Functional Requirements

| ID | Requirement | Test Case |
|---|---|---|
| VAULT-FR-01 | Provide a `deposit(asset, amount)` function that accepts a supported asset and mints proportional shares to the caller. | `deposit-succeeds` |
| VAULT-FR-02 | Provide a `withdraw(shares, asset)` function that burns shares and returns the corresponding amount of the underlying asset. | `withdraw-succeeds` |
| VAULT-FR-03 | Store and enforce a global deposit cap for each asset. Revert transactions that would exceed the cap. | `deposit-fails-cap-exceeded` |
| VAULT-FR-04 | Support configurable deposit and withdrawal fees, denominated in basis points (bps). | `fees-are-applied` |
| VAULT-FR-05 | Emit standardized events for critical operations: `deposit`, `withdraw`, `fee-change`, `cap-change`. | `events-are-emitted` |
| VAULT-FR-06 | Enforce a global `paused` flag (AIP-1) that blocks all mutating operations except for unpausing by a multi-sig guardian. | `mutating-call-fails-when-paused`|
| VAULT-FR-07 | Use a high-precision math library for all share and fee calculations to prevent rounding exploits (AIP-5). | `precision-math-verified` |
| VAULT-FR-08 | Expose public, read-only getters for key state like `get-total-value-locked`, `get-share-price`, and `get-balance`. | `getters-return-correct-values` |
| VAULT-FR-09 | Ensure all administrative functions (`set-fees`, `set-cap`, `set-paused`) are gated and can only be called by authorized principals (e.g., Governance/Timelock). | `unauthorized-admin-call-fails` |
| VAULT-FR-10 | Be inherently reentrancy-safe due to Clarity's design (state is updated before external calls). | `reentrancy-attack-fails` |

## 5. Non-Functional Requirements (NFRs)

| ID | Requirement | Metric / Verification |
|---|---|---|
| VAULT-NFR-01 | **Gas Efficiency** | A standard `deposit` or `withdraw` must consume less than X gas. <= 2 map writes per operation. |
| VAULT-NFR-02 | **Determinism** | All calculations must be deterministic. Rounding direction must be documented and consistent. |
| VAULT-NFR-03 | **Upgradeability** | The system must support upgrades via a registry pointer update, allowing for seamless migration to a new vault implementation. |
| VAULT-NFR-04 | **Test Coverage** | 100% test coverage for all invariants and functional requirements. |

## 6. Invariants & Safety Properties

| ID | Property | Description |
|---|---|---|
| VAULT-INV-01 | **Share Price Integrity** | `totalUnderlying` must always equal `sharePrice * totalShares` (within a minimal, defined rounding tolerance). |
| VAULT-INV-02 | **Share Supply Conservation** | `totalShares` must never decrease, except during a `withdraw` operation where shares are burned. |
| VAULT-INV-03 | **Fee Constraint** | Fees collected can never exceed the configured basis points bounds. |
| VAULT-INV-04 | **Cap Enforcement** | The total underlying asset in the vault can never exceed the deposit cap. |
| VAULT-INV-05 | **Pause Integrity** | No state-mutating operation can succeed when the contract is paused. |

## 7. Data Model / State & Maps

```clarity
;; --- Data Maps
(define-map balances (tuple (asset principal) (owner principal)) uint)
(define-map shares (tuple (asset principal) (owner principal)) uint)

;; --- Data Vars
(define-data-var total-underlying (map principal uint))
(define-data-var total-shares (map principal uint))
(define-data-var deposit-fee-bps uint)
(define-data-var withdraw-fee-bps uint)
(define-data-var deposit-cap uint)
(define-data-var paused bool)
```

## 8. Public Interface (Contract Functions / Events)

### Functions
- `deposit(asset: principal, amount: uint)`: Deposits assets, mints shares. Returns `(response (tuple (shares uint) (fee uint)) error)`.
- `withdraw(asset: principal, shares: uint)`: Burns shares, returns assets. Returns `(response (tuple (amount uint) (fee uint)) error)`.
- `set-fees(dep-bps: uint, wd-bps: uint)`: (Governance) Sets deposit and withdrawal fees.
- `set-cap(new-cap: uint)`: (Governance) Sets the total deposit cap.
- `set-paused(is-paused: bool)`: (Guardian/Multi-sig) Pauses or unpauses the contract.

### Events
- `(print (tuple 'event "deposit" 'user tx-sender 'amount u...))`
- `(print (tuple 'event "withdraw" 'user tx-sender 'shares u...))`

## 9. Core Flows (Sequence Narratives)

### Deposit Flow
1. **Validate**: Check `!paused`, `amount > 0`, and that the resulting `totalUnderlying` does not exceed the `deposit-cap`.
2. **Compute Shares**:
   - If `totalUnderlying` is zero (first deposit), shares minted are equal to the deposit amount.
   - Otherwise, `shares = (amount * totalShares) / totalUnderlying`.
3. **Apply Fee**: Calculate deposit fee from `amount` and subtract it.
4. **Update State**: Mint new shares to the user, and update `totalUnderlying` and `totalShares`.
5. **Emit Event**: Print a `deposit` event with all relevant details.

### Withdraw Flow
1. **Validate**: Check `!paused` and that the user has sufficient `shares`.
2. **Compute Underlying**: `underlying = (shares * totalUnderlying) / totalShares`.
3. **Apply Fee**: Calculate withdrawal fee from `underlying` and subtract it.
4. **Update State**: Burn the user's shares, update `totalUnderlying` and `totalShares`.
5. **Transfer**: Transfer the final `underlying` amount to the user.
6. **Emit Event**: Print a `withdraw` event.

## 10. Edge Cases & Failure Modes

- **First Deposit**: The share price calculation must be bootstrapped correctly (e.g., 1 share = 1 unit of underlying).
- **Zero Amount**: `deposit` and `withdraw` with zero value should be rejected to prevent state bloat or zero-division errors.
- **Full Withdrawal**: Redeeming all shares in the vault should result in `totalUnderlying` and `totalShares` being cleanly zeroed out.
- **Cap Boundary**: A deposit that brings the `totalUnderlying` exactly to the cap must be allowed.
- **Dust Amounts**: Precision math must handle very small amounts without significant value loss.

## 11. Risks & Mitigations (Technical / Economic / Operational)

| Risk | Mitigation |
|---|---|
| **Rounding Arbitrage** | Use of a high-precision math library with consistent rounding direction. Invariant checks (`VAULT-INV-01`) in testing. |
| **Parameter Griefing** | Administrative functions (fee/cap changes) are restricted to the DAO and subject to a timelock, allowing users to exit if they disagree with pending changes. |
| **Oracle Dependency** | The core vault has no direct oracle dependency, reducing this attack surface. Strategies using the vault may have oracle risk. |
| **Emergency Pause Abuse** | The `set-paused` function is controlled by a multi-sig wallet, requiring multiple independent actors to trigger a pause. All pause events are public. |

## 12. Metrics & KPIs

| ID | Metric | Description |
|---|---|---|
| VAULT-M-01 | **Total Value Locked (TVL)** | The total value of all underlying assets held in the vault. |
| VAULT-M-02 | **Share Price** | `totalUnderlying / totalShares`. Used to track the value of a single share over time. |
| VAULT-M-03 | **Transaction Volume** | Count and total value of deposits and withdrawals over time. |
| VAULT-M-04 | **Fee Revenue** | Total fees collected by the protocol from vault operations. |
| VAULT-M-05 | **Failed Transaction Rate** | Rate of reverted transactions, especially due to cap limits. |

## 13. Rollout / Migration Plan

- **Initial Deployment**: The vault will be deployed as part of the initial Conxian mainnet launch. The address will be registered in the `conxian-registry.clar` contract.
- **Upgrades**: Future versions of the vault will be deployed as new, separate contracts. Migration will be facilitated by the DAO, which will vote to update the vault pointer in the registry. Users will need to manually migrate their funds, guided by a provided migration interface.

## 14. Monitoring & Observability

- **Circuit Breaker**: An off-chain monitoring agent will track `Share Price` variance (`VAULT-M-02`). If the price changes by more than a predefined threshold in a short period, it can trigger an alert or an automated pause via the guardian multi-sig.
- **Health Scripts**: The `scripts/monitor-health.sh` script queries and logs key metrics (`VAULT-M-01`, `VAULT-M-03`) for dashboarding and alerting.

## 15. Open Questions

- Should a performance fee be introduced in a future version? (Current decision: No, keep core vault simple).
- Should the share price be cached in a data-var or recomputed on each call? (Current decision: Recompute to ensure real-time accuracy).

## 16. Changelog & Version Sign-off

- **v1.2 (2025-08-26)**:
    - Refactored PRD to align with the 16-point standard format.
    - Updated content to reflect full system context from `FULL_SYSTEM_INDEX.md`.
    - Added Appendix A for Nakamoto/Clarity3 compliance assessment.
- **v1.1 (2025-08-18)**:
    - Validated SDK 3.5.0 compliance and confirmed production readiness for mainnet.
- **v1.0 (2025-08-17)**:
    - Initial stable PRD created from implementation review and existing documentation.

**Approved By**: Protocol WG, SDK Compliance Team
**Mainnet Status**: **APPROVED FOR DEPLOYMENT**

---

## Appendix A: Nakamoto & Clarity3 Adherence Assessment

**Date:** 2025-08-25
**Assessor:** Jules

### Findings
1.  **No Nakamoto Features**: The current `vault.clar` implementation does not use any Nakamoto-specific features (e.g., sBTC, new `pox-4` capabilities). It is a Clarity 2 compatible contract.
2.  **PoC for Future**: The `nakamoto-vault-ultra.clar` contract exists as a proof-of-concept for a future, Nakamoto-native vault but is not production-ready.
3.  **Clarity2 Syntax**: The contract is written in Clarity 2. An upgrade to Clarity 3 is required to leverage Nakamoto features.

### Recommendations
1.  **Future Upgrade**: Plan a future upgrade path to a new vault implementation that is Clarity 3 compatible.
2.  **sBTC Integration**: As part of the Clarity 3 upgrade, integrate sBTC to allow for direct deposit and withdrawal of Bitcoin.
3.  **Complete PoC**: Mature the `nakamoto-vault-ultra.clar` PoC into a fully-featured, audited contract for a future release.
