# Conxian Stacks DeFi — Design

This document outlines the live Conxian on-chain DeFi architecture (current implementation + in-progress subsystems) on Stacks, leveraging Bitcoin anchoring and future BTC bridges (e.g., sBTC) for differentiation.  
For detailed product-level requirements, see `documentation/prd/` (e.g., `VAULT.md`, `DAO_GOVERNANCE.md`, `DEX.md`).

## Principles

- Minimal, composable core: single vault primitive with predictable accounting
- Parameterized via DAO (fees, caps, allowlists), not code changes
- Safety-first: explicit invariants, post-conditions, and conservative fee/limit defaults
- Sustainable economics: fee capture to protocol reserve, transparent emissions (if any)
- BTC-native differentiation: accept BTC-derivatives (e.g., sBTC) and anchor state to Bitcoin

## Core Contracts (Implemented)

- `vault.clar` – Share-based accounting, caps, dynamic fees, precision math integration
- `cxd-staking.clar` – Staking contract for CXD tokens.
- `cxd-token.clar` – The main token contract for CXD.
- `cxlp-migration-queue.clar` – Manages the migration of CXLP tokens.
- `cxlp-token.clar` – The liquidity pool token.
- `cxs-token.clar` – A secondary token in the system.
- `cxtr-token.clar` – A tertiary token in the system.
- `cxvg-token.clar` – The governance token.
- `cxvg-utility.clar` – Utility contract for the governance token.
- `dex-factory.clar` – Factory for creating DEX pools.
- `dex-pool.clar` – A standard DEX pool.
- `dex-router.clar` – Router for the DEX.
- `automated-circuit-breaker.clar` – Automated circuit breaker for the system.
- `protocol-invariant-monitor.clar` – Monitors the protocol for invariants.
- `revenue-distributor.clar` – Distributes revenue to stakeholders.
- `token-emission-controller.clar` – Controls the emission of new tokens.
- `token-system-coordinator.clar` – Coordinates the token system.
  
Traits & Interfaces: `vault-trait`, `vault-admin-trait`, `strategy-trait`, `pool-trait`, `sip-010-trait`.

## Differentiation via Bitcoin Layers (Planned / Partially Enabled)

- Accept sBTC (or wrapped BTC) as primary collateral asset
- Anchor protocol state to Bitcoin via Stacks settlement
- BTC-native strategies (e.g., BTC LSTs or staking derivatives) when available

## Security & Upgrades

- No code upgrade in-place; deploy new versions and migrate via proxy/dispatcher pattern
- Use Clarity post-conditions for critical user flows
- Use events for all state-changing actions; support off-chain indexing
- Exhaustive input checks; prefer u* operations and explicit bounds

## Gas/Cost Optimization

- Minimize map writes; write only when balances change
- Batch parameter updates; avoid per-user loops
- Use read-only calls for getters and price queries
- Compact events; avoid oversized payloads

## Oracles & Pricing (Planned)

- Prefer on-chain TWAPs or signed-oracle updates with minimal cadence
- Price-dependent logic behind caps/limits rather than per-tx dynamic heavy math

## Roadmap

Completed:

1. SIP-010 token integration (governance & auxiliary tokens)
2. Comprehensive test suites (unit, integration, production validation, circuit breaker)
3. DEX Subsystem (AMM core, router, variants, math library)
4. Circuit breaker & enterprise monitoring layer

In Progress:

1. Enhanced Tokenomics Refactor (addressing circular dependencies)
2. Multi-hop routing & advanced pool types (stable, weighted)

Upcoming:

1. Concentrated liquidity & oracle standardization
2. sBTC integration & BTC-native strategies

## DEX Subsystem (Foundational State)

Implemented (baseline): `dex-factory`, `dex-pool`, `dex-router`, `math-lib`, `pool-trait`.

Prototypes / Experimental: `stable-pool`, `weighted-pool`, `multi-hop-router`, `mock-dex`.

Design References: `DEX_DESIGN.md`, `DEX_IMPLEMENTATION_ROADMAP.md`, `DEX_ECOSYSTEM_BENCHMARK.md`.

Next Steps:

- Harden pool math (precision validation, invariant tests)
- Integrate circuit-breaker hooks (volatility halts)
- Add TWAP oracle surfaces & external oracle trait
- Advance multi-hop path selection and gas profiling

Deferred: Concentrated liquidity, compliance hooks, external oracle aggregator, batch auction / MEV protections.

Updated: Sep 06, 2025
