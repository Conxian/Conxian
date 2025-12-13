# Strategy Testing & Validation Plan

## Backtesting
- Historical windows: bull/bear/sideways markets (per category)
- Metrics: APY (bps), drawdown, volatility, slippage
- Data sources: oracle history (aggregated), strategy performance logs
- Method: simulate deposit/withdraw/rebalance events under historical prices

## Stress Testing
- Extreme volatility shocks (+/- 30% intrablock)
- Liquidity crunch (TVL drop; slippage spike)
- Oracle delayed/erroneous updates (deviation triggers)
- Circuit breaker engaged scenarios

## Benchmarks
- Stable: min APY floor, max drawdown <= threshold
- Loans: health factor maintained > 1.1 under stress
- Money-market: utilization-based APY responses within bounds
- Assets: price impact controlled; fee APR steady
- Bonds: coupon yield realized; duration risk within target bands

## Automation Validation
- Rebalance triggers activated under predefined thresholds
- Risk params enforced (min-liquidity, max-slippage)
- No write operations in read-only endpoints
- Error codes returned for boundary conditions

## Tooling
- Clarinet-based unit tests for contract logic
- Vitest JS tests for integration harness (SDK calls)
- Python simulation scripts leveraging orchestration modules

## Reporting
- Per-category backtest summary tables
- Stress test event logs
- Rebalance decision traces with metrics snapshots
