# Conxian Metrics Dashboard Specification

## Purpose
Provide a unified, automated view of protocol health across contracts (DEX, lending, oracle, strategies) with multi-dimensional KPIs.

## Dashboard Sections

1. Compilation & Trait Health
- Contracts compiled: total, errors, warnings
- Traits: implemented vs used ratio, unresolved references

2. Oracle & Pricing
- Price update frequency per asset
- TWAP window coverage (e.g., 30/60/120 blocks)
- Deviation alerts (threshold breaches)

3. Strategy & Vault Performance
- APY per strategy (bps)
- TVL per strategy/asset
- Efficiency scores (reward per unit risk)
- Rebalance events (count, amount, rationale)

4. Risk & Liquidations
- Health factor distribution for borrowers
- Liquidation events (count/value)
- Close-factor usage analytics

5. MEV & Protection
- Commitments pending
- Batch executions
- Sandwich detection alerts

## Data Sources
- Strategy contracts (get-apy, get-tvl)
- Oracle aggregator/adapter (get-price, TWAP, deviation checks)
- Lending system (health factor, liquidation metrics)
- MEV protector (commitment/reveal status)
- System graph artifacts and clarinet check outputs (compilation health)

## Implementation Notes
- On-chain read endpoints: expose minimal read-only getters for metrics aggregation.
- Off-chain aggregator: scripts/orchestration to ingest and render dashboard (CLI/web).
- Reporting cadence: per N blocks; rolling windows for TWAP and APY smoothing.

## Benchmarks & Targets
- Oracle data freshness: < 60 blocks
- Strategy APY floor per category
- Liquidation rate thresholds
- MEV alerts trend baseline
