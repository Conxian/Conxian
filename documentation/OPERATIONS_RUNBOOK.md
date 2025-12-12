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

### 1.4 Conxian Operations Engine & Guardian Automation

- **Purpose**
  - Provide an on-chain, deterministic "operations seat" for the Operations & Resilience Council.
  - Aggregate system metrics (LegEx / DevEx / OpEx / CapEx / InvEx) and recommend parameter changes.
  - Coordinate with a bonded Guardian network that performs off-chain monitoring and on-chain execution.
- **Key contracts (planned / in design)**
  - `conxian-operations-engine.clar` – on-chain policy engine and council seat.
  - `keeper-coordinator.clar` – registry of automation targets implementing a shared `automation-trait`.
  - `guardian-registry.clar` – manages Guardian roles, CXD bonding, tiers, and slashing.
  - `ops-service-vault.clar` – service vault for funding Guardian rewards and automation OpEx in CXD (to be aligned with `TREASURY_AND_REVENUE_ROUTER.md` as that design is implemented).
  - Automation targets: `liquidation-manager.clar`, `yield-optimizer.clar`, `funding-rate-calculator.clar`, and others.
- **Operational model**
  - Guardians run off-chain software (CLI/SDK) that:
    - Uses the Hiro Core API (`/v2/contracts/call-read`, extended APIs) to call read-only views
      such as `get-runnable-actions` and `get-action-needed`.
    - Submits transactions (e.g. `execute-action`, `execute-vote`) only when required and
      when Guardian tier/permissions allow it.
  - The Operations Engine reads Guardian metrics (coverage, success rate, vault balance) and
    encodes policy in `ops-policy.clar` to recommend:
    - Adjustments to fee splits into `ops-service-vault`.
    - Changes to Guardian rewards or bond thresholds.
    - Temporary restrictions on high-risk modules if automation coverage is degraded.
- **SOPs (Guardian & Ops Engine)**
  - **Normal operations**
    - Guardians continuously poll read-only views via Hiro API. No on-chain gas is consumed
      until an action is actually needed.
    - `ops-service-vault` maintains a target CXD buffer (e.g. several months of projected
      automation spend).
  - **When automation coverage degrades**
    - Monitor Guardian metrics (active Guardians, tiers, success/failure rates) via
      dashboards and on-chain views.
    - If coverage or success rate drops below thresholds, the Operations & Resilience
      Council should:
      - Review Ops Engine recommendations from `get-action-needed`.
      - Initiate governance actions to increase Guardian rewards, adjust fee splits into
        `ops-service-vault`, or throttle risky modules.
  - **When ops budget is low**
    - If `ops-service-vault` balance falls below agreed minimums, treat this as an
      operational risk.
    - Use governance to either:
      - Increase the fee-share routed to `ops-service-vault` via `protocol-fee-switch`.
      - Allocate a one-off top-up from treasury vaults, with clear change records.

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
