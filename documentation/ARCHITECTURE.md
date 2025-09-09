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

### Foundation Layer
- `vault.clar` – Share-based accounting, caps, dynamic fees, precision math integration
- `math-lib-advanced.clar` – Advanced mathematical functions (sqrt, pow, ln, exp) using Newton-Raphson and Taylor series
- `fixed-point-math.clar` – Precise arithmetic operations with proper rounding modes for 18-decimal precision
- `precision-calculator.clar` – Validation and benchmarking tools for mathematical operations

### Lending & Flash Loan System
- `comprehensive-lending-system.clar` – Complete lending protocol with supply, borrow, liquidation, and flash loans
- `enhanced-flash-loan-vault.clar` – ERC-3156 compatible flash loans with reentrancy protection
- `interest-rate-model.clar` – Dynamic interest rates based on utilization curves with kink models
- `loan-liquidation-manager.clar` – Automated liquidation system with keeper incentives
- `lending-protocol-governance.clar` – Community governance for protocol parameters
- `flash-loan-receiver-trait.clar` – Interface for flash loan callback implementations
- `lending-system-trait.clar` – Comprehensive lending protocol interface definitions

### Token System
- `cxd-staking.clar` – Staking contract for CXD tokens
- `cxd-token.clar` – The main token contract for CXD
- `cxlp-migration-queue.clar` – Manages the migration of CXLP tokens
- `cxlp-token.clar` – The liquidity pool token
- `cxs-token.clar` – A secondary token in the system
- `cxtr-token.clar` – A tertiary token in the system
- `cxvg-token.clar` – The governance token
- `cxvg-utility.clar` – Utility contract for the governance token

### DEX Infrastructure
- `dex-factory.clar` – Factory for creating DEX pools with advanced math integration
- `dex-pool.clar` – Standard DEX pool with precision mathematics
- `dex-router.clar` – Router for the DEX with multi-hop capabilities

### Monitoring & Security
- `automated-circuit-breaker.clar` – Automated circuit breaker for the system
- `protocol-invariant-monitor.clar` – Monitors the protocol for invariants
- `revenue-distributor.clar` – Distributes revenue to stakeholders
- `token-emission-controller.clar` – Controls the emission of new tokens
- `token-system-coordinator.clar` – Coordinates the token system

### Additional Infrastructure
- `distributed-cache-manager.clar` – Manages distributed caching for performance
- `memory-pool-management.clar` – Optimizes memory pool usage
- `predictive-scaling-system.clar` – Handles system scaling predictions
- `real-time-monitoring-dashboard.clar` – Real-time system monitoring
- `transaction-batch-processor.clar` – Processes transaction batches efficiently
  
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

1. **Mathematical Foundation**: Advanced functions (sqrt, pow, ln, exp) with Newton-Raphson and Taylor series algorithms
2. **Comprehensive Lending System**: Supply, borrow, liquidation with ERC-3156 compatible flash loans
3. **Dynamic Interest Rates**: Utilization-based rates with kink models and real-time adjustments  
4. **Automated Risk Management**: Health factor monitoring, automated liquidations, keeper incentives
5. **Protocol Governance**: Community-driven parameter management and upgrade mechanisms
6. **SIP-010 Integration**: Token integration (governance & auxiliary tokens)
7. **Comprehensive Test Suites**: Unit, integration, production validation, circuit breaker
8. **DEX Subsystem**: AMM core, router, variants, advanced mathematical library
9. **Circuit Breaker & Monitoring**: Enterprise monitoring layer with structured event codes

Current:

1. **Enhanced Integration**: Connecting new lending system with existing vault infrastructure
2. **Advanced Pool Support**: Leveraging mathematical foundation for concentrated liquidity
3. **Cross-Protocol Optimization**: Flash loan arbitrage and yield optimization strategies

Upcoming:

1. **Concentrated Liquidity**: Full Uniswap V3 style implementation using existing math foundation
2. **Cross-Chain Flash Loans**: Bridge integration for cross-chain arbitrage opportunities  
3. **Advanced Risk Models**: VaR calculations and portfolio optimization using implemented math functions
4. **sBTC Integration**: BTC-native strategies and collateral support

## DEX Subsystem (Enhanced with Advanced Mathematics)

**Core Implementation**: `dex-factory`, `dex-pool`, `dex-router`, `math-lib-advanced`, `fixed-point-math`, `pool-trait`

**Mathematical Capabilities**: 
- Newton-Raphson square root for liquidity calculations
- Binary exponentiation for weighted pool invariants  
- Taylor series ln/exp for compound interest and advanced pricing models
- 18-decimal precision arithmetic with proper rounding modes

**Advanced Features Ready**:
- Concentrated liquidity pool mathematics implemented
- Weighted pool invariant calculations supported
- TWAP oracle integration framework prepared
- Multi-hop routing with precise slippage calculations

**Prototypes / Experimental**: `stable-pool`, `weighted-pool`, `multi-hop-router`, `mock-dex`

**Design References**: `DEX_DESIGN.md`, `DEX_IMPLEMENTATION_ROADMAP.md`, `DEX_ECOSYSTEM_BENCHMARK.md`

**Next Steps**:
- Deploy concentrated liquidity pools using implemented mathematical functions
- Integrate flash loan arbitrage with DEX operations
- Add MEV protection using circuit-breaker hooks
- Implement cross-protocol yield optimization strategies

**Completed**: Mathematical library gap resolved, precision validation, invariant calculations ready

Updated: Sep 09, 2025
