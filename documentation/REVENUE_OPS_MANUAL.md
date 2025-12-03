# Conxian Revenue Operations & Automation Manual

## 1. Financial System Overview

The Conxian Protocol generates revenue from three primary sources. This document outlines how to initialize, monitor, and audit these flows.

### Revenue Streams

| Source | Contract | Fee Rate | Destination |
| :--- | :--- | :--- | :--- |
| **DEX Swaps** | `concentrated-liquidity-pool.clar` | Dynamic (Default 0.3%) | `protocol-fee-switch` |
| **Lending Spread** | `comprehensive-lending-system.clar` | Reserve Factor (10%) | `protocol-fee-switch` |
| **Liquidations** | `liquidation-manager.clar` | Incentive (Default 5%) | Liquidator + Protocol |

---

## 2. Initialization Checklist (One-Time Setup)

Before mainnet launch, the **Protocol Admin** must execute the following transactions to wire up the financial pipes.

### A. Initialize Fee Switch

The `protocol-fee-switch` defaults to the deployer address. You must set the actual cold wallets/multisigs.

```clarity
(contract-call? 'ST1...protocol-fee-switch set-recipients 
    'ST1...TREASURY_WALLET   ;; Ops & Grants
    'ST1...STAKING_POOL      ;; veToken Rewards
    'ST1...INSURANCE_FUND    ;; Safety Module
)
```

### B. Configure Fee Splits

Adjust how incoming revenue is divided (Total must equal 10,000 bps).

```clarity
(contract-call? 'ST1...protocol-fee-switch set-fee-splits
    u2000  ;; 20% Treasury
    u6000  ;; 60% Staking
    u2000  ;; 20% Insurance
    u0     ;; 0% Burn
)
```

### C. Enable Lending Revenue

The lending system accumulates reserves internally. You must periodically sweep them.

---

## 3. Automation & Keepers

The system is designed to be "Self-Driving" via the `keeper-coordinator`.

### Keeper Setup

1. Deploy a bot/script that holds `KEEPER_WALLET` private key.
2. Register the keeper on-chain:

    ```clarity
    (contract-call? 'ST1...keeper-coordinator register-keeper 'ST1...KEEPER_WALLET)
    ```

3. The bot should call `execute-batch-tasks` every block or every N blocks.

### Automated Tasks

* **Liquidation Checks**: The keeper triggers `execute-liquidation-check`.
* **Oracle Updates**: Triggers `execute-oracle-update` to fetch fresh prices.
* **Interest Accrual**: Triggers `accrue-interest` on active markets.

---

## 4. Auditing & Reporting

All financial events are logged on-chain.

### Key Events to Monitor

#### 1. DEX Swap Execution

* **Contract**: `concentrated-liquidity-pool`
* **Event**: `(print { event: "swap-execution", ... fee-collected: u1000 ... })`
* **Action**: Verify `fee-collected` matches `amount-in * 0.003`.

#### 2. Fee Routing

* **Contract**: `protocol-fee-switch`
* **Event**: `(print { event: "fee-routed", treasury: u200, staking: u600 ... })`
* **Action**: Sum `treasury` amounts daily to calculate Net Protocol Revenue.

#### 3. Reserve Withdrawal

* **Contract**: `comprehensive-lending-system`
* **Event**: `(print { event: "reserves-withdrawn", amount: u5000 ... })`
* **Action**: Confirm these funds arrived in the Fee Switch and were subsequently routed.

---

## 5. Emergency Procedures

### Circuit Breaker

If `circuit-breaker` triggers (e.g., 50% price drop in 1 block):

1. System pauses automatically.
2. **Ops Action**: Verify oracle data integrity.
3. **Ops Action**: Call `reset-circuit-breaker` (Multisig required).

### Liquidation Failure

If keepers fail to liquidate:

1. **Admin Action**: Call `liquidation-manager.emergency-liquidate`.
2. **Post-Mortem**: Check `keeper-coordinator` logs for `ERR_INSUFFICIENT_GAS`.
