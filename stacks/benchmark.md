# Benchmark: Conxian vs Top DeFi Protocols (Stacks + EVM)

Living comparative analysis tracking how Conxian ranks vs best-in-class DeFi systems across security, governance, UX, cost, and sustainability. Product requirement sources are centralized in `documentation/prd/` and this file reflects measured outcomes against those PRDs.

## Scope & Methodology

- Protocols tracked:
  - Stacks: ALEX, Arkadiko, StackingDAO
  - EVM exemplars: Yearn v3, Beefy, Aave v3 (as reference for lending/gov maturity)
- Categories:
  - Security & Governance: timelock, admin model, emergency controls, audits
  - UX & Ops: steps to deposit/withdraw, wallet/tooling, docs, runbooks
  - Costs: deposit/withdraw bps, performance fee, on-chain tx fees (median)
  - Risk Controls: caps, rate limits, pause, allowlists, controller flags
  - Observability: events, indexer coverage, read-only metrics
  - Strategy Engine: trait/modularity, harvest flows, performance fee realization
  - Upgradeability: patterns, migration, proxy usage (if any)
  - BTC-Native Edge: sBTC readiness, Bitcoin anchoring/finality messaging, BTC LSTs
- Data sources: public docs, GitHub repos, on-chain explorers, indexers (Hiro, Etherscan, DefiLlama for reference), and our own tx/event logs.

## Conxian Positioning (current)

- Security/Governance: timelock-admin MVP; DAO governor planned post-MVP. Explicit invariants and tests.
- UX: Hiro API scripts; Clarinet devnet; dApp UI TBD.
- Costs: bps fees set per `docs/economics.md`; tx costs minimized by simple state changes.
- Risk Controls: pause, caps, rate-limit; autonomic controllers gated by admin flag.
- Observability: compact events; monitoring script in `scripts/monitor-health.sh`.
- Strategy: trait defined; integration and mock strategy planned.
- BTC-native: Stacks settlement; sBTC integration on roadmap.

## Snapshot Comparisons (qualitative)

- Yearn v3 (EVM):
  - Strengths: mature vault/strategy architecture, multi-chain, robust governance/process.
  - Tradeoffs: higher L1 gas; complex ops; governance overhead.
  - Benchmark notes: performance fee on realized yield; share token accounting; sophisticated automation.

- Beefy (EVM):
  - Strengths: broad chain coverage, auto-compounding strategies, strong UX.
  - Tradeoffs: strategy risk surface; varied security posture across chains.
  - Benchmark notes: performance fee model; heavy off-chain bots for harvest.

- ALEX (Stacks):
  - Strengths: native to Stacks; product breadth (AMM, launchpad, etc.).
  - Tradeoffs: product complexity; generalized architecture rather than minimal vault.
  - Benchmark notes: tx fees consistent with Stacks; strong ecosystem reach.

- Arkadiko (Stacks):
  - Strengths: CDP design; DAO-governed parameters; integrated staking.
  - Tradeoffs: different product type; risk profile tied to collateral and peg.

- StackingDAO (Stacks):
  - Strengths: BTC staking derivative; treasury/governance design.
  - Tradeoffs: different product scope; yields tied to Stacks PoX dynamics.

## Quantitative Metrics (to collect)

- Fees (bps): deposit, withdraw, performance.
- On-chain costs: median tx fee for deposit/withdraw/harvest (Stacks vs EVM references).
- Latency: blocks-to-finality for admin actions (timelock delay), deposits, withdrawals.
- TVL and activity: per vault (once live), compared to peers on Stacks.

Template JSON (fill per release cycle):

```json
{
  "Conxian": {
    "fees_bps": {"deposit": 30, "withdraw": 10, "performance": 0},
    "tx_costs": {"deposit": null, "withdraw": null, "harvest": null},
    "governance": {"timelock": true, "dao_governor": false},
    "risk_controls": {"caps": true, "rate_limit": true, "pause": true}
  },
  "alex": {"fees_bps": {}, "tx_costs": {}, "governance": {}, "risk_controls": {}},
  "arkadiko": {"fees_bps": {}, "tx_costs": {}, "governance": {}, "risk_controls": {}},
  "stackingdao": {"fees_bps": {}, "tx_costs": {}, "governance": {}, "risk_controls": {}},
  "yearn_v3": {"fees_bps": {}, "tx_costs": {}, "governance": {}, "risk_controls": {}},
  "beefy": {"fees_bps": {}, "tx_costs": {}, "governance": {}, "risk_controls": {}}
}
```

## Continuous Benchmarking Cadence

- Update this document per milestone (see `docs/plan.md`).
- Record tx IDs and events for each release; capture median gas/fees.
- Maintain a short scorecard summary at the top for quick stakeholder read.

## Immediate Next Data Tasks

- Measure current Stacks tx fees on local devnet/testnet for deposit/withdraw.
- Enumerate ALEX/Arkadiko admin models and timelock usage; collect references.
- Draft scorecard v0.1 and include in PRs for feature additions.
