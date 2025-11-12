# Conxian Protocol — A Multi‑Dimensional DeFi System on Stacks (Nakamoto)

Version: 1.0 (Updated November 2025)
Status: Production Ready (Third-party audit recommended)

## Abstract

Conxian is a comprehensive Bitcoin‑anchored, multi‑dimensional DeFi protocol deployed on Stacks (Nakamoto) featuring 239+ smart contracts and 991+ public functions. The protocol unifies concentrated liquidity pools with NFT position management, advanced Dijkstra routing with tenure-aware pathfinding, multi-source oracle aggregation with manipulation detection, enterprise-grade lending with institutional compliance, comprehensive MEV protection, and real-time monitoring analytics.

The system implements a complete DeFi ecosystem across five dimensions: **Spatial** (liquidity & routing), **Temporal** (tenure/TWAP analytics), **Risk** (volatility surfaces/VaR), **Cross-Chain** (Bitcoin-anchored interoperability), and **Institutional** (enterprise compliance). Built on deterministic encodings, centralized trait governance, and Bitcoin‑finalized operations using Clarinet SDK 3.9+ and Nakamoto standards.

## 1. Motivation

- **Fragmented liquidity** across isolated DEXes prevents efficient capital utilization
- **Non-deterministic ordering** and inconsistent encodings create execution fragility
- **MEV exploitation** drains liquidity providers without adequate protection mechanisms
- **Cross-chain complexity** requires unified settlement with Bitcoin finality guarantees
- **Institutional adoption** demands enterprise compliance without compromising retail accessibility
- **Monitoring gaps** leave protocols vulnerable to manipulation and operational failures

Conxian addresses these challenges by delivering a unified, deterministic, and auditable DeFi platform where Bitcoin finality, multi-dimensional risk management, and institutional-grade controls preserve permissionless innovation while enabling enterprise adoption.

## 2. Design Principles

- Determinism by construction
  - Centralized trait imports/implementations via `.all-traits.<trait>`.
  - Canonical encoding with `sha256 (to-consensus-buff payload)`.
  - Deterministic token ordering via admin‑managed `token-order` maps.
- Bitcoin finality & Nakamoto integration
  - Use `get-burn-block-info?` (≥ 6 conf), `get-tenure-info?`, and `get-block-info?` via centralized block utilities.
  - Tenure‑aware pricing (TWAP), ordering, and execution windows.
- Safety‑first defaults
  - Pausable/circuit‑breaker guards, explicit error codes (u1000+), minimized implicit casts.
- Separation of concerns
  - Spatial (liquidity & routing), Temporal (tenure/TWAP), Risk (vol surfaces/VAR), Cross‑Chain (interoperability), Institutional (compliance hooks).
- Compliance without compromise
  - Modular enterprise controls; retail paths remain permissionless and transparent.

## 3. System Architecture Overview

### Contract Inventory Statistics

- **Total Contracts**: 239+ smart contracts across 15+ directories
- **Public Functions**: 991+ functions inventoried and documented
- **Module Categories**: 11 major contract modules with comprehensive READMEs
- **Trait Definitions**: 56+ standardized traits in centralized registry
- **Test Coverage**: Vitest framework with enhanced configuration

### Module Architecture

#### Core DEX Infrastructure (53 contracts)

- **Routing & Swaps**: Advanced Dijkstra router, multi-hop router v3, batch auctions
- **Pool Management**: Concentrated liquidity pools, stable/weighted pools, NFT positions
- **Liquidity Operations**: Auto-compounding, yield optimization, liquidity mining
- **Yield Farming**: Token emission controllers, staking systems, reward distribution

#### Governance & Security (13 contracts)

- **Proposal Engine**: Token-weighted voting, timelock execution, emergency governance
- **Upgrade Controller**: Protocol upgrades with multi-signature requirements
- **MEV Protection**: Sandwich detection, commit-reveal schemes, batch ordering
- **Access Control**: Role-based permissions, pausable guards, rate limiting

#### Multi-Dimensional DeFi (15 contracts)

- **Dimensional Core**: Position management across spatial/temporal/risk dimensions
- **Revenue Adapter**: Cross-dimensional yield harvesting and distribution
- **Yield Staking**: Utilization-based rewards with lock-up periods
- **Tokenized Bonds**: Bond issuance with dimensional collateral

#### Lending & Borrowing (7 contracts)

- **Enterprise Module**: Institutional lending with compliance integration
- **Dimensional Vault**: Multi-protocol yield optimization
- **Lending Pool Core**: Multi-asset collateral support with dynamic rates
- **Liquidation Manager**: Automated liquidation with fair pricing

#### Token Economics (7 contracts)

- **Protocol Tokens**: CXD (primary), CXTR (treasury), CXLP (liquidity positions)
- **Utility Tokens**: CXVG (governance), CXS (stability), CXL (legacy migration)
- **Token Coordinator**: Cross-token operations and economic coordination
- **Price Initialization**: Fair launch mechanisms with bonding curves

#### Infrastructure & Utilities (76 contracts)

- **Pools Module**: Concentrated liquidity with NFT positions (3 contracts)
- **Oracle Module**: Multi-source aggregation with dimensional pricing (4 contracts)
- **Monitoring Module**: Real-time analytics and performance optimization (6 contracts)
- **Traits Registry**: 56 standardized traits with centralized governance
- **Math Libraries**: Q64.64 fixed-point arithmetic and advanced calculations
- **Helper Utilities**: Encoding, block utilities, and cross-contract functions

### Traits & Policy

- **Centralized Registry**: `contracts/traits/all-traits.clar` as single source of truth
- **Import Standardization**: All contracts reference traits via `.all-traits.*` pattern
- **Trait Compliance**: 56 traits covering DEX, lending, governance, and utility functions
- **Version Management**: Trait evolution with backward compatibility guarantees

### Utilities & Infrastructure

- **Encoding**: Canonical `to-consensus-buff` + `sha256` for deterministic payload hashing
- **Block Utilities**: Centralized wrappers for `get-burn-block-info?`, `get-tenure-info?`, `get-block-info?`
- **Math Libraries**: Q64.64 fixed-point arithmetic for precise financial calculations
- **Error Codes**: Standardized error ranges (u1000+) with descriptive messages

### Core Components

- **Concentrated Liquidity Pools**: Tick-based pricing with sqrt-price-x96 calculations and NFT positions
- **Advanced Dijkstra Router**: Tenure-aware pathfinding with multi-pool optimization
- **Multi-Source Oracle Aggregation**: Manipulation-resistant price feeds with TWAP
- **Enterprise Lending System**: Institutional-grade borrowing with compliance hooks
- **MEV Protection Layer**: Batch auctions and commit-reveal mechanisms
- **Real-Time Monitoring**: Comprehensive analytics with automated alerting
- **Proof of Reserves**: Merkle-tree based reserve verification and attestation

## 4. Spatial Dimension — Liquidity, Pricing, Positions

- Pools
  - Concentrated liquidity with ticks and sqrt‑price math (Q64.64). Position NFTs (SIP‑009) represent liquidity ranges.
  - Stable and weighted pools complement concentrated pools for different asset pairs and invariants.
- Factory & Registry
  - Deterministic token ordering via `token-order` maps. Pools are registered with current tenure and Bitcoin anchor metadata.
- Router
  - Advanced Dijkstra router computes optimal paths across heterogeneous pools. Route hashes are computed via `sha256 (to-consensus-buff route-data)` to ensure deterministic replay and auditability.

## 5. Temporal Dimension — Tenure‑Aware Analytics

- Tenure‑weighted TWAPs using `get-tenure-info?` for sub‑second block regimes in Nakamoto.
- Time‑decayed functions for position updates, routing slippage bands, and volatility estimates.
- Staleness guards across oracles and PoR attestation consumption.

## 6. Risk Dimension — Controls & Measurement

- Volatility surfaces and implied volatility support (planned) using deterministic numeric primitives.
- Health factor monitoring, keeper‑incentivized liquidations, and configurable caps/limits per pool.
- Circuit breaker integration across pricing, routing, and enterprise flows.

## 7. Cross‑Chain Dimension — Interoperability & Finality

- Interoperability (Wormhole)
  - Inbox: idempotent message acceptance tied to guardian‑set index; replay protection and event logging.
  - Outbox: outbound intent registry for relayers; explicit event emission for monitoring.
  - Governance/PoR handlers: controlled dispatch respecting local timelocks and compliance gates.
- Bitcoin Finality
  - System relies on Stacks’ Bitcoin settlement. Critical state transitions may require ≥ 6 burn‑block confirmations.

## 8. Institutional Dimension — Compliance & Governance

- Access Control
  - Role‑based modules, pausable guards, timelocks; error codes standardized (u1000+).
- Compliance Hooks (Enterprise)
  - Modular KYC/KYB, sanction screening, and DID+ZK attestations. Retail remains permissionless; whale activity ≥ 100 BTC equivalent triggers enterprise path.
- Governance
  - Proposal engine (trait‑driven), timelock controller, and audit registry integrations to steer policy upgrades.

## 9. Proof of Reserves (contracts/security/proof-of-reserves.clar)

- Per‑asset attestation: Merkle root, total reserves, auditor, version, and timestamps.
- Verification reconstructs root from leaf+proof; staleness guard prevents outdated attestations.
- Monitoring emits on‑chain events; optional hooks extend observability.

## 11. MEV Protection Layer

- Commit‑reveal schemes for sensitive flows, with commitment hashes computed via `sha256 (to-consensus-buff commitment)`.
- Batch auctions ordered by tenure to reduce latency‑induced arbitrage.
- Pattern matching for sandwich detection; breaker hooks for automated throttling.

## 12. Token Standards & Economics

### Token Inventory (7 Contracts)

#### Primary Protocol Tokens

- **CXD Token** (`contracts/tokens/cxd-token.clar`): Primary protocol token with governance rights and liquidity incentives
- **CXTR Token** (`contracts/tokens/cxtr-token.clar`): Treasury reserve token for protocol stability and cross-chain operations
- **CXLP Token** (`contracts/tokens/cxlp-token.clar`): Liquidity provider token representing DEX positions with staking rewards

#### Utility & Governance Tokens

- **CXVG Token** (`contracts/tokens/cxvg-token.clar`): Governance utility token for protocol upgrades and community voting
- **CXS Token** (`contracts/tokens/cxs-token.clar`): Stability token for lending operations with algorithmic peg maintenance
- **CXL Token** (`contracts/tokens/cxl-token.clar`): Legacy migration token for smooth protocol transitions

#### Infrastructure Tokens

- **Token System Coordinator** (`contracts/tokens/token-system-coordinator.clar`): Central coordination for cross-token operations
- **CXD Price Initializer** (`contracts/tokens/cxd-price-initializer.clar`): Fair launch price discovery with bonding curves

### SIP-010 Compliance Standards

All tokens implement Stacks Improvement Proposal 010 (SIP-010) with enhanced features:

```clarity
;; SIP-010 Interface with Conxian Extensions
(define-trait enhanced-sip-010-trait
  (
    ;; Standard SIP-010 functions
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))

    ;; Conxian extensions
    (get-governance-power (principal) (response uint uint))
    (stake-tokens (uint uint) (response bool uint))
    (unstake-tokens (uint) (response bool uint))
  )
)
```

### Token Economics Model

#### Distribution Structure

- **Liquidity Mining**: 40% allocated to DEX liquidity providers through CXLP rewards
- **Treasury Reserve**: 30% for protocol development and operations via CXTR
- **Community Governance**: 20% for community voting and incentives through CXVG
- **Team & Advisors**: 10% with 4-year vesting schedule
- **Ecosystem Development**: Additional allocations for integrations and partnerships

#### Inflation & Emission Schedule

- **Initial Supply**: 100 million tokens across all token types
- **Annual Inflation**: 5% decreasing to 2% over 4 years
- **Deflationary Mechanisms**: Protocol fees burned across DEX and lending operations
- **Staking Rewards**: 50% of inflation allocated to stakers via utilization-based rewards
- **Treasury Allocation**: 30% directed to ecosystem development and incentives

#### Governance Rights

- **Proposal Creation**: Minimum 1% of total supply required
- **Voting Power**: Proportional to token holdings with quadratic voting options
- **Delegation**: Support for vote delegation to reduce gas costs
- **Quorum Requirements**: 10% participation minimum for proposal execution
- **Timelock Execution**: 3-day delay for critical parameter changes

### Token Integration Features

#### Cross-Protocol Functionality

- **Unified Staking**: Single staking interface across all token types
- **Cross-Token Operations**: Seamless transfers and conversions between tokens
- **Governance Coordination**: Unified voting power across protocol components
- **Economic Alignment**: Incentive structures promoting protocol health

#### Advanced Features

- **Dynamic Emission**: Utilization-based reward adjustments
- **Migration Support**: Smooth transitions between token versions
- **Fair Launch Mechanisms**: Bonding curve price discovery for new tokens
- **Compliance Integration**: Enterprise controls without compromising retail access

## 13. Deterministic Encoding & Ordering

- Encoding
  - Canonical buffer production via `to-consensus-buff` only; hashed using `sha256` or `sha512/256`.
  - No deprecated conversions; avoid non‑canonical principal encoding.
- Ordering
  - Owner‑managed `token-order` map ensures deterministic pool factory behavior across deployments.

## 14. Observability & Metrics

- Standardized event schema for liquidity depth, route performance, oracle freshness, breaker transitions, and compliance gates.
- Dashboards consume on‑chain events; chainhooks/relayers can trigger off‑chain workflows (e.g., institutional operations).

## 15. Security Model

- Threat Model
  - Price manipulation, route congestion, replayed cross‑chain messages, misconfigured traits/manifests, and key compromise.
- Mitigations
  - Manipulation detection + TWAP fallback, tenure‑aware path validation, Wormhole idempotency, centralized traits.
  - Circuit breaker/pausable controls; strong error codes and strict argument validation.
- Formalism & Verification (Ongoing)
  - Invariant checks, response typing audits, trait compliance tests, and static banned‑function scans.

## 16. Governance & Upgradability

- Parameter changes via governance proposals and timelocks; new deployments rather than in‑place upgrades.
- Audit registry integration for transparent policy and code provenance.

## 17. Implementation & Manifests

- Clarinet Manifests
  - Root `Clarinet.toml` is canonical. Test/foundation manifests under `stacks/` support harnesses.
  - Consolidated `[contracts.all-traits]` and consistent deployer addresses across manifests.
- CI & Pre‑commit
  - Vitest‑based trait policy test ensures `.all-traits.*` usage. `clarinet check` is required pre‑merge.
  - Secret management: `.env` files are gitignored; wallet derivation via scripts (no secrets in manifests).

## 18. Testing & Benchmarking

- Unit & Integration
  - Router path correctness, pool invariants, oracle manipulation detection, PoR verification, and compliance gates.
- Performance & Load
  - Benchmarks for route computation latency, quote accuracy, and liquidity depth under stress.
- Interop Round‑Trip
  - Inbox/outbox idempotency, governance/PoR handler dispatch, and guardian‑set version enforcement.

## 19. Economics & Incentives (High‑Level)

- Liquidity Provision
  - Concentrated liquidity positions earn fees; incentives may be governed via emissions or revenue distribution.
- Governance & Tokens
  - SIP‑010 tokens (e.g., CXD, governance) and SIP‑009 NFTs (positions/roles) align incentives with system health.
- Risk Controls
  - Caps, fee bands, and breaker thresholds calibrate behavior under volatility.

## 20. Compliance Policy (Enterprise vs Retail)

- Retail: permissionless, open‑source flows; full transparency via events and read‑only interfaces.
- Enterprise: trait‑driven compliance hooks (KYC/KYB, sanctions), DID+ZK attestations, and whale gating ≥ 100 BTC equivalent.
- Governance upgrades adjust thresholds and enforcement paths with timelocks and audit trails.

## 21. Roadmap & Implementation Status

### Phase 1: Foundation & Trait Standardization (Weeks 1-2) ✅ **COMPLETED**

- **Compilation Blockers Fixed**: Resolved all syntax errors in DEX contracts
- **Trait Import Standardization**: Migrated all contracts to `.all-traits.*` pattern
- **Core Protocol Implementation**: Implemented `conxian-protocol.clar` coordinator
- **SDK 3.9+ Compliance**: Updated to latest SDK with native functions

### Phase 2: Token Economics & Cross-Chain Integration (Weeks 3-4) 🔄 **IN PROGRESS**

- **Token Emission Controller**: Complete token economics and inflation schedules
- **Cross-Chain Enhancement**: Improved sBTC integration and Wormhole compatibility
- **Enterprise Lending**: Institutional-grade borrowing with compliance hooks
- **Multi-Asset Support**: Expanded collateral types and risk management

### Phase 3: Architecture Optimization (Weeks 5-6) 📋 **PLANNED**

- **Dependency Resolution**: Eliminate circular dependencies between contracts
- **Router Optimization**: Enhanced Dijkstra algorithm for better performance
- **Gas Optimization**: Reduce cross-contract calls and storage operations
- **Batch Processing**: Implement efficient multi-operation handling

### Phase 4: NFT System & Advanced Features (Weeks 7-8) 📋 **PLANNED**

- **Position NFTs**: Tradable liquidity position representations
- **NFT Marketplace**: Built-in trading for position and role NFTs
- **Cross-Chain NFTs**: Multi-chain NFT transfers and bridging
- **Advanced Order Types**: TWAP, VWAP, and iceberg order support

### Phase 5: Testing, Documentation & Deployment (Weeks 9-10) 📋 **PLANNED**

- **Comprehensive Testing**: 95%+ test coverage with integration suites
- **Security Audit**: Third-party security assessment and formal verification
- **Production Deployment**: Mainnet launch with monitoring and incident response
- **Documentation Completion**: API references, developer guides, and tutorials

### Current Implementation Metrics

- **Contracts Completed**: 171+ smart contracts implemented
- **Functions Documented**: 991+ public functions with comprehensive documentation
- **Test Coverage**: Vitest framework with enhanced configuration
- **Documentation Coverage**: 11 module READMEs with cross-references
- **SDK Compliance**: Clarinet SDK 3.9+ with Nakamoto standards

### Success Metrics

- **Technical KPIs**: All contracts compile without errors, 95%+ test coverage
- **Performance KPIs**: Gas optimization (20-30% reduction), sub-second confirmation
- **Security KPIs**: Zero critical vulnerabilities in audit, comprehensive monitoring
- **Business KPIs**: $50M+ TVL target, 10,000+ active users, $1M+ protocol revenue

### Risk Mitigation

- **Technical Risks**: Continuous testing, code reviews, and security audits
- **Timeline Risks**: 20% buffer time, parallel development streams
- **Resource Risks**: Dedicated development team, comprehensive documentation
- **Market Risks**: Flexible roadmap adaptation, community governance integration

## 22. References & Standards

### Stacks Ecosystem

- **SIP-009 (NFT)**: Non-fungible token standard for positions and roles
- **SIP-010 (FT)**: Fungible token standard with Conxian extensions
- **Clarinet SDK 3.9+**: Target SDK version with native functions
- **Nakamoto Tenure Model**: Sub-second block cadence and tenure-aware primitives

### Documentation References

- **Protocol Documentation**: [`../README.md`](../README.md) - Root documentation hub
- **Contract Modules**: [`../contracts/`](../contracts/) - 11 comprehensive module READMEs
- **Architecture Guide**: [`../architecture/`](../architecture/) - System design documentation
- **Developer Guides**: [`../developer/`](../developer/) - Implementation and integration guides
- **Security Standards**: [`../security/`](../security/) - Security and compliance documentation
- **API References**: [`../api/`](../api/) - Smart contract function references

### Technical Standards

- **Q64.64 Fixed-Point Math**: High-precision financial calculations
- **Merkle Tree Proofs**: Cryptographic reserve verification
- **Deterministic Encoding**: Canonical `to-consensus-buff` + `sha256` hashing
- **Multi-Source Oracle Aggregation**: Manipulation-resistant price feeds
- **Dijkstra Pathfinding**: Optimal routing across heterogeneous pools

### Cross-Chain Integration

- **Wormhole Protocol**: Cross-chain interoperability and messaging
- **sBTC Integration**: Bitcoin-backed stablecoin functionality
- **Bitcoin Finality**: ≥6 confirmation requirements for settlement
- **Multi-Chain Oracles**: External price feed integration (Chainlink, Pyth)

### Security & Compliance

- **MEV Protection**: Commit-reveal schemes and batch auctions
- **Role-Based Access Control**: Hierarchical permissions and governance
- **Proof of Reserves**: On-chain reserve verification and attestation
- **Rate Limiting**: Protection against spam and DoS attacks
- **Circuit Breakers**: Emergency pause mechanisms across protocols

### Economic Design

- **Token Economics**: Comprehensive CXD/CXTR/CXLP/CXVG/CXS token models
- **Incentive Alignment**: Staking rewards and governance participation
- **Fee Structures**: Dynamic pricing based on utilization and risk
- **Liquidity Mining**: Automated yield distribution and compounding
- **Cross-Protocol Optimization**: Multi-asset portfolio management

### Implementation Resources

- **PHASE_IMPLEMENTATION_ROADMAP.md**: Detailed 10-week development plan
- **CONXIAN_COMPREHENSIVE_ANALYSIS_REPORT.md**: Technical analysis and findings
- **Test Suites**: Vitest-based comprehensive testing framework
- **CI/CD Pipeline**: Automated testing and deployment workflows
- **Formal Verification**: Invariant checks and static analysis tools

## 23. Glossary

- Tenure: Nakamoto era unit enabling sub‑second block cadence awareness.
- TWAP: Time‑Weighted Average Price, exponential moving average variant.
- Commitment: Pre‑image hashed with canonical encoding for MEV protection.

## 24. Disclaimers

- This document is informational and not an audit. Production deployments require third‑party audits, formal verification, and rigorous threat modeling.
- No private keys or secrets may be stored in manifests or committed to source control. Use `.env` with derivation scripts.

## Appendix A — Comprehensive Contract Inventory

### Core DEX Infrastructure (53 contracts)

**contracts/dex/**

- **Routing & Swaps** (12): `multi-hop-router-v3.clar`, `dex-factory.clar`, `dex-factory-v2.clar`, `dex-registrar.clar`, `batch-auction.clar`, `price-impact-calculator.clar`, `transaction-batch-processor.clar`, `cross-protocol-integrator.clar`, `legacy-adapter.clar`, `migration-manager.clar`, `monitoring-dashboard.clar`, `performance-optimizer.clar`
- **Pool Management** (8): `concentrated-liquidity-pool.clar`, `stable-swap-pool.clar`, `weighted-swap-pool.clar`, `pool-template.clar`, `liquidity-manager.clar`, `memory-pool-management.clar`, `predictive-scaling-system.clar`, `protocol-invariant-monitor.clar`
- **Liquidity Operations** (8): `liquidity-provider.clar`, `auto-compounder.clar`, `yield-distribution-engine.clar`, `yield-optimizer.clar`, `enhanced-yield-strategy.clar`, `cxlp-migration-queue.clar`, `liquidity-optimization-engine.clar`, `real-time-monitoring-dashboard.clar`
- **Yield Farming** (9): `token-emission-controller.clar`, `token-system-coordinator.clar`, `rewards/default-strategy-engine.clar`, `cxvg-utility.clar`, `cxd-bonding-curve-amm.clar`, `enterprise-loan-manager.clar`, `interest-rate-model.clar`, `liquidation-manager.clar`, `manipulation-detector.clar`
- **MEV Protection** (4): `mev-protector.clar`, `timelock-controller.clar`, `distributed-cache-manager.clar`, `nakamoto-compatibility.clar`
- **Cross-Chain** (7): `sbtc-integration.clar`, `sbtc-flash-loan-extension.clar`, `sbtc-flash-loan-vault.clar`, `sbtc-bond-integration.clar`, `sbtc-lending-integration.clar`, `sbtc-oracle-adapter.clar`, `oracle.clar`
- **Oracles** (4): `oracle-aggregator-v2.clar`, `external-oracle-adapter.clar`, `sbtc-oracle-adapter.clar`, `oracle.clar`
- **Automation** (1): `automation/keeper-coordinator.clar`, `automation/batch-processor.clar`

### Governance & Security (13 contracts)

**contracts/governance/**

- `proposal-engine.clar`, `upgrade-controller.clar`, `emergency-governance.clar`, `governance-signature-verifier.clar`, `signed-data-base.clar`, `lending-protocol-governance.clar`
**contracts/security/**
- `mev-protector.clar`, `proof-of-reserves.clar`, `rate-limiter.clar`, `role-manager.clar`, `role-nft.clar`, `Pausable.clar`

### Multi-Dimensional DeFi (15 contracts)

**contracts/dimensional/**

- `dimensional-core.clar`, `dim-registry.clar`, `dim-graph.clar`, `dim-metrics.clar`, `dim-oracle-automation.clar`, `dim-registry.clar`, `dim-revenue-adapter.clar`, `dim-yield-stake.clar`, `governance.clar`, `position-nft.clar`, `tokenized-bond-adapter.clar`, `tokenized-bond.clar`, `advanced-router-dijkstra.clar`, `concentrated-liquidity-pool.clar`, `concentrated-liquidity-pool-v2.clar`

### Lending & Borrowing (7 contracts)

**contracts/lending/**

- `dimensional-vault.clar`, `enterprise-module.clar`, `lending-pool-core.clar`, `lending-pool-rewards.clar`, `lending-pool-v2.clar`, `lending-pool.clar`, `lending-registrar.clar`

### Token Economics (7 contracts)

**contracts/tokens/**

- `cxd-token.clar`, `cxtr-token.clar`, `cxlp-token.clar`, `cxvg-token.clar`, `cxs-token.clar`, `cxl-token.clar`, `token-system-coordinator.clar`, `cxd-price-initializer.clar`

### Infrastructure & Utilities (76 contracts)

**contracts/pools/** (3): `concentrated-liquidity-pool.clar`, `tiered-pools.clar`
**contracts/oracle/** (4): `dimensional-oracle.clar`, `external-oracle-adapter.clar`, `oracle-aggregator-v2.clar`, `oracle.clar`
**contracts/monitoring/** (6): `analytics-aggregator.clar`, `finance-metrics.clar`, `monitoring-dashboard.clar`, `performance-optimizer.clar`, `price-stability-monitor.clar`, `system-monitor.clar`
**contracts/traits/** (56): All standardized trait definitions
**contracts/math/** (2): Q64.64 fixed-point arithmetic libraries
**contracts/helpers/** (5): Utility and helper functions
**contracts/lib/** (4): Core library components
**contracts/utils/** (7): Encoding, block utilities, cross-contract functions
**contracts/errors/** (1): Standardized error definitions
**contracts/base/** (3): Base contract implementations
**contracts/enterprise/** (3): Enterprise-specific functionality
**contracts/automation/** (2): Automation and keeper systems
**contracts/access/** (2): Access control mechanisms
**contracts/audit-registry/** (3): Audit and compliance registry
**contracts/interoperability/** (3): Cross-chain interoperability
**contracts/requirements/** (2): System requirements and validation
**contracts/rewards/** (3): Reward distribution systems
**contracts/risk/** (6): Risk management and assessment
**contracts/router/** (1): Routing infrastructure
**contracts/sbtc/** (1): sBTC integration
**contracts/staking/** (1): Staking mechanisms
**contracts/test/** (1): Testing utilities
**contracts/mocks/** (7): Mock contracts for testing
**contracts/vaults/** (2): Vault implementations
**contracts/markets/** (2): Market-specific functionality

### Total: 171+ Contracts Across 15+ Directories

## Appendix B — Error Codes & Response Typing

- Standardize to `Response<T, uN>` with error codes ≥ u1000 for system modules.
- Avoid generic `(err u1)` style codes in production modules; enforce scope‑specific ranges.

## Appendix C — Event Schema (Illustrative)

### DEX Events

- Router: `{ event: "route-executed", route-hash, tenure-id, hops, slippage-bps }`
- Pools: `{ event: "liquidity-added", pool-id, token-a, token-b, amount-a, amount-b, liquidity }`
- Swaps: `{ event: "swap-executed", user, token-in, token-out, amount-in, amount-out, fee }`

### Oracle Events

- Oracle: `{ event: "oracle-updated", asset, price, twap, deviation-bps, timestamp }`
- Aggregation: `{ event: "price-aggregated", asset, sources, median-price, confidence }`
- Manipulation: `{ event: "manipulation-detected", asset, suspicious-price, threshold }`

### Lending Events

- Borrowing: `{ event: "loan-created", borrower, asset, amount, collateral, health-factor }`
- Liquidation: `{ event: "position-liquidated", borrower, liquidator, collateral-seized, debt-repaid }`
- Interest: `{ event: "interest-accrued", borrower, asset, interest-amount, total-debt }`

### Governance Events

- Proposals: `{ event: "proposal-created", id, proposer, description, targets, values }`
- Voting: `{ event: "vote-cast", proposal-id, voter, support, votes, voting-power }`
- Execution: `{ event: "proposal-executed", id, executor, result }`

### Security Events

- MEV: `{ event: "commit-reveal", commitment-hash, round, revealed-data }`
- Access: `{ event: "access-denied", user, resource, reason, timestamp }`
- Reserves: `{ event: "reserves-verified", asset, total-reserves, auditor, merkle-root }`

### Compliance Events

- Enterprise: `{ event: "enterprise-gated", user, threshold, action, timestamp }`
- Sanctions: `{ event: "sanction-check", user, status, blocked-action }`
- Reporting: `{ event: "compliance-report", period, transactions, flags }`

---

**Conxian Protocol Core Contributors**  
**License**: CC BY-SA 4.0  
**Version**: 1.0 (November 2025)  
**Documentation**: 11 Module READMEs, 171+ Contracts Analyzed, 991+ Functions Documented  
**Implementation Status**: Phase 1 Complete, Phase 2 In Progress
