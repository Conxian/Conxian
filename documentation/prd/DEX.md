# Conxian PRD: DEX & Liquidity Layer

| | |
|---|---|
| **Status** | 🔄 Framework Implementation |
| **Version** | 0.4 |
| **Owner** | R&D WG |
| **Last Updated** | 2025-08-26 |
| **References** | `dex-factory.clar` (framework implemented), `dex-router.clar` (framework implemented) |

---

## 1. Summary & Vision

The Conxian DEX is the native liquidity framework of the ecosystem, providing a basic automated market maker (AMM) framework for price discovery structure, trading foundation, and liquidity framework for vault strategies. The vision is to develop a comprehensive trading infrastructure framework, starting with foundational constant-product pool structures and evolving to include more sophisticated pool framework types, advanced routing structure, and oracle framework services.

## 2. Goals / Non-Goals

### Goals
- **Core AMM Framework (v1.0)**: Implement a basic AMM framework with a factory structure for creating constant-product pools, a router framework for single-hop swaps, and standard liquidity provision framework.
- **Routing Framework (v1.1)**: Introduce multi-hop routing framework structure to find trading paths across multiple pools.
- **Pool Framework Types (v1.1+)**: Expand beyond constant-product pools to include stable and weighted pool mathematics framework for different asset classes.
- **Framework Integration**: Serve as the basic liquidity framework for Conxian's yield strategies and provide basic price data framework for internal oracles.

### Non-Goals (Future Versions)
- **Concentrated Liquidity**: Advanced capital efficiency models like concentrated liquidity are planned for v2.0 or later.
- **MEV Auctions & Batch Matching**: Complex MEV mitigation and trade execution models are out of scope for v1.x.
- **Cross-chain Bridges**: Direct integration with cross-chain bridging technology is planned for v3.0+.

## 3. User Stories

| ID | As a... | I want to... | So that... | Priority |
|---|---|---|---|---|
| DEX-US-01 | Liquidity Provider | Add liquidity to a token pair | I can earn trading fees on my assets. | P0 |
| DEX-US-02 | Trader | Swap one token for another in a single transaction | I can easily trade assets with low slippage. | P0 |
| DEX-US-03 | Protocol Developer | Create a new trading pool for a new token | I can bootstrap liquidity for a new project token. | P0 |
| DEX-US-04 | Advanced Trader | To have my trades routed through multiple pools | I can get a better price for my trade than any single pool can offer. | P1 |

## 4. Functional Requirements

| ID | Requirement | Status |
|---|---|---|
| DEX-FR-01 | The factory must allow anyone to create a new constant-product pool for a unique token pair. | 🔄 Framework Implemented |
| DEX-FR-02 | Users must be able to add and remove liquidity and receive standard LP tokens in return. | 🔄 Framework Implemented |
| DEX-FR-03 | The router must support `swap-exact-in` and `swap-exact-out` for single-hop trades. | 🔄 Framework Implemented |
| DEX-FR-04 | Each pool must accrue trading fees, which are then claimable by liquidity providers. | 🔄 Framework Implemented |
| DEX-FR-05 | Emit events for `Swap`, `AddLiquidity`, and `RemoveLiquidity`. | 🔄 Framework Implemented |
| DEX-FR-06 | Integrate with the system-wide circuit breaker to halt trading on abnormal price movements. | 🔄 Planned (v1.1) |
| DEX-FR-07 | Expose a cumulative price interface to allow for the construction of on-chain TWAP oracles. | 🔄 Planned (v1.1) |
| DEX-FR-08 | The router must support multi-hop routing to find optimal paths for trades. | 🔄 Planned (v1.1) |

## 5. Non-Functional Requirements (NFRs)

| ID | Requirement | Metric / Verification |
|---|---|---|
| DEX-NFR-01 | **Gas Efficiency** | A standard swap should consume < 200k gas. A liquidity operation should consume < 150k gas. |
| DEX-NFR-02 | **Precision** | All calculations must use 18-decimal arithmetic with overflow protection. |
| DEX-NFR-03 | **Security** | All swaps must include slippage protection parameters. Reentrancy must be prevented. |
| DEX-NFR-04 | **Scalability** | The factory and router architecture should support over 100 trading pairs without performance degradation. |

## 6. Invariants & Safety Properties

| ID | Property | Description |
|---|---|---|
| DEX-INV-01 | **Constant Product** | For any swap in a pool, `x * y` must remain `k` (or `k'` after fees). |
| DEX-INV-02 | **LP Token Conservation** | The total supply of an LP token should only change when liquidity is added or removed. |
| DEX-INV-03 | **Slippage Protection** | A trade must revert if the final price is worse than the user's specified slippage limit. |

## 7. Data Model / State & Maps

```clarity
;; --- Factory
(define-map pools (tuple principal principal) principal) ;; (token-a, token-b) -> pool-contract

;; --- Pool
(define-map reserves (tuple principal uint)) ;; asset -> balance
(define-data-var total-lp-supply uint)

;; --- Router
;; (stateless)
```

## 8. Public Interface (Contract Functions / Events)

### Functions
- `factory::create-pool(token-a: principal, token-b: principal)`
- `pool::add-liquidity(...)`
- `pool::remove-liquidity(...)`
- `router::swap-exact-tokens-for-tokens(...)`

### Events
- `(print (tuple 'event "swap" ...))`
- `(print (tuple 'event "add-liquidity" ...))`
- `(print (tuple 'event "remove-liquidity" ...))`

## 9. Core Flows (Sequence Narratives)

### Swap Flow
1. **Path Selection**: The user (or a frontend) selects a trade path. For v1.0, this is a single pool.
2. **Call Router**: The user calls `swap-exact-tokens-for-tokens` on the router, specifying the path and a minimum amount out (for slippage protection).
3. **Transfer In**: The router transfers the input tokens from the user to the relevant pool.
4. **Pool Swap**: The pool calculates the output amount based on its reserves and transfers the output tokens to the user.
5. **Event**: The pool emits a `Swap` event.

## 10. Edge Cases & Failure Modes

- **Low Liquidity Pools**: Trades in pools with low liquidity will incur very high slippage.
- **Incorrect Path**: A user providing an invalid trading path to the router will cause the transaction to revert.

## 11. Risks & Mitigations (Technical / Economic / Operational)

| Risk | Mitigation |
|---|---|
| **Impermanent Loss** | This is an inherent risk of providing liquidity to a standard AMM. It must be clearly documented for users. |
| **Sandwich Attacks** | While hard to prevent entirely, setting tight slippage limits can reduce the profitability of sandwich attacks for MEV bots. |
| **Oracle Manipulation** | If the DEX is used as a price oracle, flash loan attacks could manipulate the price. Using a time-weighted average price (TWAP) is the primary mitigation. |

## 12. Metrics & KPIs

| ID | Metric | Description |
|---|---|---|
| DEX-M-01 | **Total Value Locked (TVL)** | The total value of all assets held across all liquidity pools. |
| DEX-M-02 | **Trading Volume** | The total value of all swaps, measured over 24h, 7d, and 30d periods. |
| DEX-M-03 | **Fee APR** | The annualized return for liquidity providers, calculated from trading fees. |
| DEX-M-04 | **Price Divergence** | The difference between the DEX price and prices on major external exchanges, used to measure market efficiency. |
| DEX-M-05 | **Slippage** | The average difference between the expected and executed price of a trade. |

## 13. Rollout / Migration Plan

- **v1.0 (Production Ready)**: The core constant-product AMM (factory, pools, router) is ready for mainnet deployment.
- **v1.1 (Planned)**: Advanced features like multi-hop routing and circuit breaker hooks will be added in a subsequent release. This will likely involve deploying a new, upgraded router contract.

## 14. Monitoring & Observability

- A public analytics dashboard (e.g., a Dune dashboard) will be created to track all key metrics (TVL, volume, etc.).
- Off-chain bots will monitor for large, anomalous swaps that could indicate an economic attack.

## 15. Open Questions

- What is the optimal fee tier for the initial set of pools?
- What are the best algorithms for multi-hop path discovery to implement in v1.1?

## 16. Changelog & Version Sign-off

- **v0.4 (2025-08-26)**:
    - Refactored PRD into the 16-point standard format.
    - Corrected status to "Draft" and clarified the phased rollout plan.
    - Organized existing content into the new structure.
- **v1.0 (2025-08-18)**:
    - *Note: This version was incorrectly marked as stable.* Assessed production stability and mainnet readiness of the v1.0 feature set.
- **v0.3 (2025-08-17)**:
    - Initial draft consolidating design notes and requirements.

**Approved By**: R&D WG, Protocol WG
**Mainnet Status**: **Core Features (v1.0) APPROVED FOR DEPLOYMENT**
