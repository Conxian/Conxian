# Contract Size & Deployment Footprint

Purpose: Provide a current snapshot of contract source byte sizes as a proxy for deployment cost and to monitor proximity to Clarity size limits (exact on-chain cost depends on compiled representation & opcode usage). This table feeds gas optimization prioritization.

Generated: 2025-08-18 (simnet working tree)  
Method: `wc -c stacks/contracts/*.clar` (raw source bytes)  
Note: Source byte size is not a direct deterministic indicator of runtime execution costs, but large files increase audit overhead and may approach protocol limits; track trends.

| Rank | Contract | Bytes | Notes / Observations |
|------|----------|-------|----------------------|
| 1 | vault.clar | 33,320 | Largest; includes precision math, flash loans, liquidation, autonomics; candidate for modularization (separate flash/liq extensions) |
| 2 | treasury.clar | 26,424 | Multi-sig + growth strategies + auto-buyback; review for feature flag segmentation |
| 3 | vault-original.clar | 22,445 | Legacy baseline; slated for removal (audit reference only) |
| 4 | bounty-system.clar | 20,574 | Includes AIP-4 dispute system; pruning optional logging may reduce size |
| 5 | dao-automation.clar | 19,068 | Automation orchestration; evaluate splitting strategy adapters |
| 6 | weighted-pool.clar | 17,613 | DEX weighted math incl. invariant; opportunity to move math to library (`math-lib`) for reuse |
| 7 | analytics.clar | 17,089 | Event aggregation; consider off-chain indexing reliance to slim on-chain logic |
| 8 | dao-governance.clar | 16,220 | Integrated AIP-2 & test-mode; removal of duplicates will not shrink this directly |
| 9 | bounty-system-original.clar | 14,998 | Pre AIP-4 version; removal planned |
| 10 | timelock.clar | 14,080 | Core governance safety; monitor if function pruning possible without reducing guarantees |
| 11 | dao-governance-original.clar | 13,486 | Duplicate; removal planned |
| 12 | oracle-aggregator.clar | 12,877 | Oracle logic; future sBTC integration hooks expected (watch size growth) |
| 13 | cxlp-token.clar | 11,715 | LP token; standard SIP-010 overhead |
| 14 | multi-hop-router.clar | 11,646 | Pathfinding complexity; potential optimization of list operations |
| 15 | dex-pool.clar | 11,643 | Base DEX pool; compare with weighted & stable variants for consolidation |
| 16 | math-lib.clar | 10,086 | Shared math; ensure weighted invariant migration here to dedupe |
| 17 | cxvg-token.clar | 9,787 | Governance token with migration logic; review for unnecessary duplication |
| 18 | enterprise-monitoring.clar | 9,666 | Operational analytics; some events may migrate off-chain |
| 19 | circuit-breaker.clar | 8,686 | Full circuit breaker; gas-critical pathways to benchmark |
| 20 | creator-token.clar | 8,673 | Creator incentive token; ensure mint controls audited |
| 21 | stable-pool.clar | 5,094 | Stable swap; compare function overlap with dex-pool & weighted-pool |
| 22 | automated-bounty-system.clar | 4,744 | Automation overlay; verify event necessity |
| 23 | circuit-breaker-simple.clar | 3,460 | Minimal breaker variant; candidate for removal or retention as fallback |
| 24 | CXVG.clar | 3,188 | Lightweight governance token support |
| 25 | dex-router.clar | 3,115 | Routing aggregator; potential inlining trade-offs |
| 26 | mock-ft.clar | 2,817 | Test fixture; ensure excluded from mainnet deploy set |
| 27 | enhanced-dao-governance.clar | 2,711 | Redundant time-weight file; removal planned |
| 28 | dex-factory.clar | 2,126 | Factory pattern; succinct |
| 29 | dao.clar | 2,097 | Legacy DAO placeholder; evaluate necessity vs governance + timelock |
| 30 | state-anchor.clar | (Not in wc snapshot) | (Add in next run) |

## Observations & Recommendations

1. Modularization Targets: `vault.clar` (extract flash loan & liquidation into extension traits) to shrink core invariant surface (SEC, AUDIT).  
2. Duplicate Removal: Eliminate `*-original.clar`, `enhanced-dao-governance.clar` post-archive; expect ~70KB reduction in total repository surface.  
3. Math Consolidation: Move weighted pool power / invariant helpers into `math-lib.clar` to avoid drift and enable shared gas optimizations.  
4. Event Rationalization: Audit high-verbosity contracts (`analytics.clar`, `vault.clar`) for event necessity vs indexer derivable data (gas).  
5. Governance Execution Stubs: Re-enable treasury spend execution path with tests; ensure size increase justified (functionality > bytes).  
6. Circuit Breaker Duplication: Decide on keeping either full or simple variant (cannot justify both long-term).  
7. Stable vs Weighted Pools: Evaluate code sharing (e.g., pricing, fee logic) via trait & library to decrease aggregate size.

## Next Metrics (Planned)

| Metric | Method | Status |
|--------|--------|--------|
| Per-function estimated runtime cost | Clarinet analyze / targeted simulation harness | Pending tooling selection |
| Storage writes per critical path | Static scan (grep var-set/map-set counts) | Planned |
| Upgrade diff size (delta LOC) | Git diff PR gating rule | To implement |
| Trait compliance audit (SIP-010 & internal) | Automated CI script | Planned |

---
Prepared by: Conxian Core Agent  
Focus: Maintain security & auditability while optimizing for Bitcoin-aligned minimalism.
