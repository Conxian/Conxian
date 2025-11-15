# Default Strategy System for Conxian Vaults

This document specifies the methodology, configuration, and reporting standards for the default strategy system spanning multiple DeFi dimensions: stablecoins, loans, money markets, assets, and bonds.

## Overview

The Default Strategy Engine assigns category-optimized strategies to vault-managed assets, monitors performance metrics, and triggers rebalancing according to predefined risk parameters. It targets capital efficiency with protected risk bounds and transparent reporting for both regular and advanced users.

## Core Strategy Categories

- Stable: low-volatility yield sources; emphasis on liquidity, slippage control, and stable APY.
- Loans: overcollateralized lending; emphasis on health factor, liquidation thresholds, and borrow APR spreads.
- Money-Market: variable-rate lending markets; emphasis on utilization, reserve ratio, and dynamic APY.
- Assets: spot/liquidity provisioning; emphasis on price impact, fee APR, and volatility controls.
- Bonds: fixed-income tokenized positions; emphasis on duration/convexity and coupon yield.

Each category maps to a default strategy contract implementing `.all-traits.strategy-trait`.

## Assignment and Automation

1. Category defaults are configured via `set-category-default(category, strategy)`.
2. Assets receive defaults via `apply-default-to-asset(asset, category)`.
3. Optimization parameters per asset are set via `set-asset-params(asset, min-liquidity, max-slippage-bps, risk-score)`.
4. The engine exposes `select-default-strategy(asset, category)` for optimizers (e.g., yield-optimizer) and routers.
5. Performance snapshots are recorded via `update-performance(asset)`.
6. Rebalancing is initiated via `rebalance-asset(asset)` (future expansions to withdraw/deposit hooks with vault).

## Metrics-Driven Selection

Primary metrics:
- APY (basis points), TVL, efficiency scores
- Liquidity depth, slippage bounds
- Risk score (protocol-defined scale)

The engine integrates with `finance-metrics-trait` for aggregated metrics and uses per-strategy `get-apy`/`get-tvl` for local performance.

## Risk and Rebalancing

- Risk parameters define minimum liquidity and maximum slippage per asset.
- Rebalancing is triggered when efficiency/apy deviates beyond thresholds or risk bounds are breached.
- Circuit-breakers (if present) must be respected to halt rebalancing under adverse conditions.

## User Interface Requirements

- Regular users: show the default strategy selection prominently as the recommended option.
- Advanced users: allow manual override (swap or customize strategies), with warnings and risk disclosures.
- Display driving metrics (APY, TVL, efficiency, slippage bounds) and historical performance.

## Testing and Validation

- Backtests across historical market conditions per category.
- Stress tests for extreme scenarios (volatility spikes, liquidity crunches, oracle manipulation). 
- Benchmarks: target minimum APY, maximum drawdown, time-to-liquidity metrics per category.

## Reporting & Transparency

- Publish periodic performance snapshots (block-based) for each asset-strategy pair.
- Provide category-level dashboards with aggregated KPIs.
- Document methodology, parameter changes, and rebalancing events for auditability.

## Integration Plan

- Hook yield-optimizer via `get-default-strategy(asset, category)`.
- Integrate vault deposit/withdraw hooks into `rebalance-asset` (future work) after enabling vault support.
- Expand metrics ingestion from oracle/monitoring modules.
