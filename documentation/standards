# Standards and Interoperability Guide

This document codifies standards for Conxian’s Stacks DeFi system to ensure security, efficiency, and seamless interoperability with other systems.

## Token Standard: SIP-010 (Fungible Tokens)

- Token interactions MUST target a configurable token principal, not a hardcoded contract.
  - Vault stores token principal in `var token` and uses it for `transfer` and `transfer-from`.
  - Safety: Token changes are only allowed when the vault is paused and empty.
- Use `as-contract` when the vault triggers token transfers to ensure correct `tx-sender`.
- Ensure allowance flows for `deposit` use `transfer-from` and require user approvals.
- Post-conditions SHOULD be used by callers for critical transfers and state changes.
- Recommended minimal SIP-010 surface used:
  - `transfer(recipient, amount) -> (response bool uint)`
  - `transfer-from(sender, recipient, amount) -> (response bool uint)`
  - `get-balance-of(owner) -> (response uint uint)`

## Vault Interface Standard (ERC‑4626 inspired)

Introduce a standard vault trait for cross-system composability. This trait is defined at `stacks/contracts/traits/vault-trait.clar`.

```clarity
(define-trait vault-trait
  (
    (deposit (user principal) (amount uint) (response uint uint))
    (withdraw (user principal) (amount uint) (response uint uint))

    (get-balance (user principal) (response uint uint))
    (get-total-assets () (response uint uint))
    (preview-deposit (amount uint) (response uint uint))
    (preview-withdraw (amount uint) (response uint uint))

    (get-token () (response principal uint))
    (paused () (response bool uint))
  )
)
```

Notes:
- Current `vault.clar` retains the existing method signatures for backwards compatibility with tests and integrations.
- A migration path will be planned to either:
  - Add wrapper entrypoints that conform to `vault-trait`, or
  - Introduce `v2` vault that implements the trait directly.

## Strategy and Oracle Adapters

- Strategy trait SHOULD expose a minimal interface for deposit/withdraw of assets and reporting of realized PnL or asset growth.
- Oracle trait SHOULD expose a standardized price query with data source, freshness checks, and decimals.
- Registry SHOULD record vault-strategy relationships by trait reference, not by concrete contract, to allow hot-swaps via governance.

## Governance & Auth

- All admin-changing and parameter updates SHOULD be gated by a timelock (queue/execute) owned by a DAO or multi-sig per environment.
- Critical state transitions:
  - Pause before upgrades or token changes; require empty vault for token change.
  - Enforce caps, rate-limits, and fee bounds on user operations.
- Emit events for all admin and user actions to support indexers and off-chain monitoring.

## Security Controls

- Invariants:
  - `total-balance` equals sum of all user balances.
  - Reserves cannot underflow and cannot be withdrawn beyond their balances.
  - Caps and rate limits are always enforced when enabled.
- Parameter constraints:
  - Fees `<= 10000 bps`.
  - `min-withdraw-fee < max-withdraw-fee`.
  - `util-high > util-low`.
- Upgrades:
  - Prefer new deployments and registry/dispatcher patterns; avoid in-place mutation of logic.

## Interop Guidelines

- Avoid hardcoding contract principals; store references in data-vars and expose getters.
- Use traits for all cross-contract interactions.
- Provide `read-only` view functions for critical state to support off-chain clients.
- Emit structured `print` events for deposits, withdrawals, and governance changes.

## Testing & Observability

- Unit tests SHOULD cover:
  - Deposit/withdraw happy paths and edge cases (caps, rate-limits, fees).
  - Timelock queue/execute for admin actions.
  - Reserve accounting and withdrawals.
  - Token change safeguards (paused + empty).
- Add preview functions to support client UX and testing of slippage/fees.

## Status

- Implemented: dynamic SIP-010 token usage in `vault.clar`.
- Added: `vault-trait.clar` (not yet implemented by the current vault for compatibility).
- Next: add wrappers or a `v2` vault to implement `vault-trait`, and standardize strategy/oracle traits.
