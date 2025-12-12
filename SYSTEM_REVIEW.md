# Conxian System Review: Full Stacks Native Architecture

## Executive Summary

The Conxian protocol is well-structured with a modular design leveraging Clarity traits. However, to achieve "Full Stacks Native Architecture" and readiness for the Nakamoto upgrade, significant adjustments are required. The current system relies on patterns that will be disrupted by faster block times and misses opportunities to leverage unique Stacks features like PoX and native Bitcoin reads.

## 1. Critical: Nakamoto Upgrade & Block Times

**Impact: High | Urgency: Immediate**

The Stacks Nakamoto upgrade changes block times from ~10 minutes (tied to Bitcoin) to ~5-10 seconds. Your contracts currently use `block-height` for time-dependent logic, which will accelerate system time by ~120x.

### Affected Areas (Confirmed via Scan)

- **Governance**: `voting-period` (u720 -> 1 hour), `voting-delay`.
- **Vaults**: `WITHDRAWAL_DELAY_BLOCKS` (u144 -> 12 minutes).
- **Yield**: `BLOCKS_PER_YEAR` (u52560 -> ~3 days).
- **Oracles**: `MAX_STALENESS_BLOCKS` (u144 -> 12 minutes).

**Files requiring immediate updates:**

- `contracts/vaults/custody.clar`
- `contracts/governance/governance.clar`
- `contracts/dex/bond-factory.clar`
- `contracts/lending/interest-rate-model.clar`
- `contracts/monitoring/analytics-aggregator.clar`

### Recommendation

- **Audit & Rescale**: Multiply all block-based constants by ~120 (assuming 5s blocks).
- **Use Burn Height**: For long-term locking or synchronization with Bitcoin (like `BTC_FINALITY_BLOCKS`), switch to `burn-block-height`, which tracks Bitcoin blocks directly and remains stable at ~10 minutes.

## 2. Native sBTC Integration

**Impact: High | Urgency: High**

The current `contracts/vaults/btc-bridge.clar` implements a custom, trusted bridging mechanism. Stacks offers a decentralized, non-custodial sBTC peg.

### Recommendation

- **Deprecate Custom Bridge**: Remove custom wrapping/unwrapping logic in `btc-bridge.clar`.
- **Integrate Official sBTC**:
  - Use the official sBTC mini-extensions or the `sbtc-registry` contract interfaces.
  - Accept sBTC (`SIP-010`) directly in vaults.
  - For "Deposit from Bitcoin" flows, listen for native sBTC mint events or use a helper contract that verifies sBTC mint transactions using `clarity-bitcoin`.

## 3. Trustless Bitcoin State Reads

**Impact: Medium | Urgency: Medium**

The current `btc-adapter.clar` relies on trusted inputs. Stacks allows contracts to read Bitcoin state directly.

### Recommendation

- **Use `clarity-bitcoin`**: Import the standard library for parsing Bitcoin transactions and block headers.
- **Verify Transactions**: Implement `was-tx-mined?` checks to cryptographically prove that a user deposited BTC, rather than trusting a relayer.

**See `contracts/sbtc/native-btc-bridge.clar` (created by me) for a reference implementation.**

## 4. PoX-Aligned Governance

**Impact: Low | Urgency: Low**

Current governance uses a standard token-voting model. Stacks allows for "Stacking" governance, where locking governance tokens yields BTC (via PoX).

### Recommendation

- **Stacking for Governance**: Require users to "Stack" their governance tokens (lock them) to receive voting power.
- **PoX Cycles**: Align governance epochs with PoX reward cycles (~2 weeks) to create a natural rhythm for protocol updates.

## 5. Architecture Support Plan

### Immediate Actions

1. **Scan & Fix Constants**: Identify all `uint` constants representing time (Script provided: `scripts/analyze_nakamoto_impact.py`).
2. **Refactor `btc-adapter`**: Prototype `clarity-bitcoin` integration.
3. **Update Tests**: Configure `Clarinet.toml` to simulate Nakamoto block times.
