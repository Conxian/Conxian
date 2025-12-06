# Conxian Operations Runbook

This runbook maps key on-chain contracts, events, and admin controls to operational procedures. It is intended for operations, treasury, and incident-response teams.

## 1. Core Operational Controls

### 1.1 Circuit Breaker (`circuit-breaker.clar`)

- **Purpose**
  - Global kill-switch for protocol operations.
  - Guard-rail for critical services (e.g. lending core).
- **Key entrypoints**
  - `set-admin(new-admin)`
  - `open-circuit()` / `close-circuit()`
  - `check-circuit-state(service)`
  - `assert-operational()`
- **Standard operating procedures (SOPs)**
  - **Normal state**
    - `is-circuit-open` returns `false`.
    - `assert-operational` returns `(ok true)`.
  - **When to open circuit**
    - Oracle failure or suspected price manipulation.
    - Critical lending or DEX invariant breach.
    - Governance-mandated emergency pause.
  - **How to open circuit**
    - Call `open-circuit` (or `trigger-circuit-breaker`) from the current admin principal.
    - Verify:
      - `is-circuit-open` returns `true`.
      - Dependent modules (e.g. `comprehensive-lending-system`) revert with circuit-related errors.
  - **How to close/reset circuit**
    - After incident is diagnosed and fixed, call `close-circuit` or `reset-circuit-breaker`.
    - Verify `is-circuit-open` returns `false` and `assert-operational` is `(ok true)`.

### 1.2 Protocol Fee Switch (`protocol-fee-switch.clar`)

- **Purpose**
  - Central fee router for protocol revenue.
  - Splits fees between **treasury**, **stakers**, **insurance fund**, and **burn**.
- **Key entrypoints**
  - `set-module-fee(module, fee-bps)`
  - `set-fee-splits(treasury, staking, insurance, burn)`
  - `set-recipients(treasury, staking, insurance)`
  - `route-fees(token, amount, is-total, module)`
- **Operational notes**
  - `set-fee-splits` must sum to `MAX_BPS` (`10000`).
  - `route-fees` assumes the calling module has already transferred `fee-amount` of the token to the fee-switch contract.
  - Transfers are executed from the fee-switch contract itself using `tx-sender` inside `as-contract`.
- **SOPs**
  - **Changing fee rates**
    - Use `set-module-fee` to adjust base fee for modules (e.g. `"DEX"`, `"LENDING"`).
    - Keep a change log and obtain governance approval where required.
  - **Updating splits**
    - Propose new splits (e.g. 20/60/20/0) through governance.
    - Once approved, execute `set-fee-splits` from an authorized principal.
    - Monitor subsequent fee-routing events (`fee-routed`, `treasury-transfer`, etc.) in logs.
  - **Recipient changes**
    - Use `set-recipients` to update treasury, staking, or insurance fund addresses.
    - Ensure new contracts are deployed and tested prior to changeover.

### 1.3 Token System Coordinator (`token-system-coordinator.clar`)

- **Purpose**
  - Tracks and coordinates operations across CXD, CXVG, CXLP, CXTR, and CXS.
  - Provides system health view for operations.
- **Key entrypoints**
  - `initialize-system()`
  - `register-token(token, symbol, decimals)`
  - `coordinate-multi-token-operation(user, tokens, operation-type, total-value)`
  - `emergency-pause-system()` / `emergency-resume-system()`
  - `activate-emergency-mode()` / `deactivate-emergency-mode()`
  - Read-only: `get-system-health()`, `get-user-activity(user)`.
- **SOPs**
  - **Initialization**
    - After deployment or migration, run `initialize-system` to register the 5 core tokens.
    - Confirm tokens appear in `get-registered-token` and health reflects correct counts.
  - **Pausing and emergency mode**
    - Use `emergency-pause-system` for non-critical maintenance or short pauses.
    - Use `activate-emergency-mode` only during severe incidents; this may block certain coordinated operations.
    - Always document reason, timestamp, and expected resolution path in ops logs.

---

## 2. Risk & Lending Operations

### 2.1 Comprehensive Lending System (`comprehensive-lending-system.clar`)

- **Purpose**
  - Core lending engine with supply, borrow, repay, withdraw, and health factor checks.
  - Integrates with the **circuit breaker**, **interest-rate-model**, and **protocol-fee-switch**.
- **Key dependencies**
  - `.circuit-breaker` via `check-circuit-breaker`.
  - `.interest-rate-model` via `accrue-interest`, `update-market-state`, and `get-market-info`.
  - `.protocol-fee-switch` via `withdraw-reserves` and subsequent `route-fees`.
- **Operational checks**
  - Before enabling new markets or updating risk parameters, ensure:
    - Circuit breaker is closed and `assert-operational` is `(ok true)`.
    - Market is initialized in `interest-rate-model` and parameters are within approved ranges.
  - After `withdraw-reserves`, monitor:
    - Event `reserves-withdrawn` in lending.
    - Subsequent fee-routing events in `protocol-fee-switch`.

### 2.2 Interest Rate Model (`interest-rate-model.clar`)

- **Purpose**
  - Centralized interest calculation and reserve accumulation.
- **Key entrypoints**
  - Admin: `set-lending-system-contract`, `set-interest-rate-model`, `initialize-market`.
  - Lending-only: `accrue-interest`, `update-market-state`, `reduce-reserves`.
- **SOPs**
  - **Parameter updates**
    - Only adjust `base-rate`, `multiplier`, `jump-multiplier`, and `kink` after quantitative analysis.
    - Validate `kink <= PRECISION` and maintain audit records for parameter changes.
  - **Market init**
    - For each new asset, call `initialize-market` from the configured lending system contract.
    - Confirm reserved and utilization metrics via `get-market-info`.

---

## 3. Oracle & Monitoring

### 3.1 TWAP Oracle (`twap-oracle.clar`)

- **Purpose**
  - Provides time-weighted average prices for assets.
- **Key entrypoints**
  - `update-twap(asset, period, current-price)` (governance-only).
  - `get-twap(asset, period)`.
- **SOPs**
  - Ensure only governance address calls `update-twap`.
  - Use non-zero periods and document oracle update cadence.
  - Monitor `twap-updated` logs (via `print`) in your monitoring stack.

### 3.2 Security Monitoring / Circuit Integration

- Align `circuit-breaker` usage with:
  - **Oracle anomalies**: open circuit on extreme or inconsistent prices.
  - **Interest anomalies**: if reserves or indexes move outside expected bands.
  - **Lending health factor breaches**: repeated low health factors across users.

---

## 4. Governance & Policy

### 4.1 Proposal Engine & Registry

- **Key behaviours**
  - Proposals must meet quorum and have more `for` than `against` votes.
  - Only proposers can execute or (with owner) cancel a proposal.
- **Ops notes**
  - Maintain an off-chain log of proposal IDs, parameters, and outcomes.
  - For parameter-change proposals (fees, risk, circuit policies): link proposal IDs to change tickets.

---

## 5. Incident Response Checklist

1. **Detect**
   - Alert from monitoring (oracle, lending, DEX, governance).
2. **Assess**
   - Check `circuit-breaker.is-circuit-open` and `token-system-coordinator.get-system-health`.
3. **Contain**
   - Open circuit and/or pause token system as required.
4. **Diagnose**
   - Review relevant contract events (`fee-routed`, `reserves-withdrawn`, `twap-updated`, governance actions).
5. **Remediate**
   - Apply governance-approved configuration changes.
6. **Restore**
   - Close circuit, resume systems, and confirm tests (including integration and system tests) pass.
7. **Post-mortem**
   - Document root cause, impacts, and improvements.
