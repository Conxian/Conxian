# DEX

## Factory
- `contracts/dex/dex-factory.clar`
- Registers pool implementations, deploys pools via traits.

## Pools
- Stable/Weighted: `contracts/dex/stable-swap-pool.clar`, `contracts/dex/weighted-swap-pool.clar`
- Concentrated: `contracts/dimensional/concentrated-liquidity-pool.clar`, `contracts/dimensional/concentrated-liquidity-pool-v2.clar`
- Traits: `pool-trait`, `fee-manager-trait`

## Router
- `contracts/dex/dex-router.clar`
- Multi-hop routing, amount-in/out helpers.

## Fees
- Fee tiers constants in concentrated pools; fee manager trait for dynamic tiers.

## Security
- Circuit breaker hooks recommended for swap/liq functions.
- Pausable for emergency halts.
