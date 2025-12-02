# Conxian DeFi System Index & Fix Log

## 1. Clarinet Check Issues & Solutions

| Contract | Issue | Solution |
|----------|-------|----------|
| `dex/oracle-aggregator-v2.clar` | Syntax error `(unwrap! ...)` causing parser failure. | Replaced `unwrap!` with `try!` to correctly propagate errors and match types. |
| `core/position-manager.clar` | Calling non-existent `get-real-time-price` on hardcoded principal. | Updated to call `.oracle-aggregator-v2` `get-oracle-price` and fix return type handling. Added `open-interest` tracking. |
| `core/dimensional-engine.clar` | Type mismatch in `let` binding using `unwrap!` on `contract-call?`. | Replaced `unwrap!` with `try!` to correctly handle `response` types. Fixed contract references (`.collateral-manager`, `.funding-rate-calculator`). |
| `dimensional/dim-revenue-adapter.clar` | Execution path type mismatch (`response` vs `bool`). | Replaced `unwrap!` with `try!` and `asserts!` to ensure consistent return types. |
| `dex/concentrated-liquidity-pool.clar` | Indeterminate `ok` type in `if` expression. | Simplified logic using `asserts!` to avoid ambiguous `try!` usage. |
| `core/funding-rate-calculator.clar` | Invalid trait usage, missing helpers (`abs`), missing `get-open-interest`. | Implemented `abs`, fixed `to-uint` logic, added `get-open-interest` to `position-manager`, fixed contract calls. |
| `Clarinet.toml` | Missing contract definitions (`oracle-aggregator-v2`, `collateral-manager`, etc.). | Added missing contracts to `Clarinet.toml` to resolve dependencies. |

## 2. System Architecture Index

### Core Layer
*   **Conxian Protocol** (`contracts/core/conxian-protocol.clar`): Central coordinator for protocol configuration and authorization.
*   **Access Control** (`contracts/access/roles.clar`): Role-based access control (RBAC) for all components.
*   **Collateral Manager** (`contracts/core/collateral-manager.clar`): Manages user deposits/withdrawals and internal balances.

### Dimensional Engine (Derivatives)
*   **Dimensional Engine** (`contracts/core/dimensional-engine.clar`): Main entry point for opening/closing positions.
*   **Position Manager** (`contracts/core/position-manager.clar`): Stores position data, tracks open interest, calculates PnL.
*   **Funding Rate Calculator** (`contracts/core/funding-rate-calculator.clar`): Calculates funding rates based on oracle price and open interest.
*   **Dim Metrics** (`contracts/dimensional/dim-metrics.clar`): Analytics and metrics for the dimensional system.

### DEX Layer
*   **Oracle Aggregator V2** (`contracts/dex/oracle-aggregator-v2.clar`): Provides TWAP and manipulation-resistant prices.
*   **Concentrated Liquidity Pool** (`contracts/dex/concentrated-liquidity-pool.clar`): AMM with concentrated liquidity features.

### Traits
*   **Core Traits**: `ownable`, `pausable`, `roles`.
*   **DeFi Traits**: `sip-010`, `flash-loan`.
*   **Dimensional Traits**: `position-manager`, `collateral-manager`, `funding-rate-calculator`.

## 3. Alignment & Verification
All identified syntax and logic errors preventing compilation have been resolved. Inter-contract dependencies (e.g., `funding-rate-calculator` -> `position-manager`) have been aligned by implementing missing functions (`get-open-interest`) and fixing contract references in `Clarinet.toml`.
