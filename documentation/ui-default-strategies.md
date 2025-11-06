# UI Specification: Default Strategies Management

## Goals
- Present default strategies as primary options for regular users.
- Allow advanced users to customize or manually swap strategies.
- Transparently display metrics driving selections.

## User Personas
- Regular User: non-technical; prefers recommended defaults.
- Advanced User: power user; wants control over strategy selection and parameters.

## Key Screens

1. Vault Asset Overview
- Asset list with category badges (stable, loans, money-market, assets, bonds)
- Applied default strategy name and quick metrics (APY bps, TVL, efficiency)
- CTA: "Use Default" (primary), "Customize" (secondary)

2. Strategy Details
- Strategy info: description, risks, fees
- Metrics panel: historical APY chart, TVL, rebalance events
- Buttons: "Apply to Asset", "Backtest", "Stress Test"

3. Advanced Customization
- Strategy selector (dropdown from available strategies implementing strategy-trait)
- Parameter inputs: min-liquidity, max-slippage-bps, risk-score
- Preview: estimated APY, risk warnings
- Actions: "Apply", "Reset to Default"

## Data Binding (Read-only endpoints)
- `default-strategy-engine.get-asset-strategy(asset)`
- `default-strategy-engine.get-performance(asset)`
- `yield-optimizer.get-default-strategy(asset, category)`
- Oracle/TWAP endpoints for price context

## Event Logging & Audit
- Record user overrides, parameter changes, and rebalancing actions
- Provide exportable reports for governance/audits

## Accessibility & UX
- Clear risk disclosures on overrides
- Tooltips for metrics definitions
- Consistent color coding per category