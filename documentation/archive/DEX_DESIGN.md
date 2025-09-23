# Conxian DEX Design (Phase B)

This document specifies the architecture for the Conxian decentralized exchange subsystem prior to implementation.

## Scope (Phase B Ordered First)

1. Constant Product Pool Contract (`dex-pool`)
2. Factory & Registry (`dex-factory`) for deterministic pool deployment
3. Router (`dex-router`) for add/remove liquidity + single hop swaps (multi-hop deferred)
4. Oracle (embedded cumulative price + TWAP view fn) inside pool (external contract deferred)
5. Events & Accounting (fee growth per share; protocol fee skim)
6. Treasury Buyback Integration (treasury -> router path STX->CXVG)
7. Analytics hooks to existing `analytics` contract (best-effort)

Deferred to Phase A (after design):

- Stable swap & weighted pool variants
- Multi-hop path routing & pathfinder
- Compliance hook system & circuit breakers
- Concentrated liquidity (tick ranges)
- External `dex-oracle` aggregator
- Router slippage protection (will include min-out args initially though)

## Contracts & Traits

- `dex-pool.clar`: Implements pool-trait: add-liquidity, remove-liquidity, swap, get-reserves, get-fee-info, get-price.
- `dex-factory.clar`: create-pool(token-x, token-y, fee-bps) -> pool-id; stores mapping for lookup and prevents duplicates.
- `dex-router.clar`: user-friendly interface; orchestrates calls to pools; maintains allowance workflow for mock-ft tokens.

### pool-trait (draft)

```clarinet

(define-trait pool-trait
    (
        (add-liquidity (dx uint) (dy uint) (min-shares uint) (deadline uint) (response uint uint))
        (remove-liquidity (shares uint) (min-dx uint) (min-dy uint) (deadline uint) (response uint uint))
        (swap-exact-in (amount-in uint) (min-out uint) (x-to-y bool) (deadline uint) (response uint uint))
        (get-reserves () (response (tuple (rx uint) (ry uint)) uint))
        (get-fee-info () (response (tuple (lp-fee-bps uint) (protocol-fee-bps uint)) uint))
        (get-price () (response (tuple (price-x-y uint) (price-y-x uint)) uint))
    )
)

```

## Data Model (dex-pool)

- token-x, token-y principals (SIP-010 tokens OR STX sentinel principal `.stx` placeholder) – initial version supports STX + one fungible.
- reserve-x, reserve-y
- total-shares, user-shares map
- lp-fee-bps (e.g. 30), protocol-fee-bps (e.g. 5 / 30 split), protocol-fee-accum-x/y
- price-cumulative-x-y, price-cumulative-y-x, last-block (for TWAP)

## Algorithms

### Add Liquidity

If total-shares == 0: mint shares = sqrt(dx *dy)
Else required ratio check: dx / reserve-x ≈ dy / reserve-y; shares = min( dx* total-shares / reserve-x, dy * total-shares / reserve-y )
Apply min-shares slippage guard.

### Swap (Constant Product)

Given amount-in minus lp fee: amount-in-net = amount-in * (BPS_DENOM - fee-bps) / BPS_DENOM.
amount-out = reserve-out - (k / (reserve-in + amount-in-net)) (standard formula)
Check amount-out >= min-out.
Update reserves; accrue protocol fee portion (subset of fee) to protocol buckets.

### Remove Liquidity

 amounts: dx = shares * reserve-x / total-shares; dy similar.
 Check min-dx/dy guards.
 Burn shares; update reserves.

### Oracle (Cumulative)

On each state-changing call (add, remove, swap) update cumulative price as price-x-y += price(x->y) * blocks-since-last.
TWAP consumer queries reserves & cumulative values to compute average over window.

## Buyback Flow

Treasury calls router.swapExactIn STX->CXVG path using pool id, with min-out based on on-chain spot minus tolerance (initial) – later replace with TWAP consult.

## Security Considerations

- Deadline parameter to prevent stale tx execution.
- Min-out / min-shares for slippage.
- Overflow safe (Clarity checks); still guard division by zero.
- Protocol fee adjustable only via governance (store governance principal) – future param update function adopted from dao-governance.

## Parameter Constants (initial)

- BPS_DENOM = 10_000
- DEFAULT_LP_FEE_BPS = 30
- DEFAULT_PROTOCOL_FEE_BPS = 5
- MINIMUM_LIQUIDITY = 1000 (lock to prevent division extremes)

## Events

- add-liquidity, remove-liquidity, swap, protocol-fee-skimm, pool-created

## Integration Points

- `treasury.execute-auto-buyback` -> router
- `analytics` contract can be invoked inside pool events (best effort) similar pattern seen in `vault.clar`.
- Future: strategy contract can hold shares for yield strategies.

## Migration Strategy

- Keep mock-dex until new system passes tests; then remove and update treasury.

## Testing Plan

1. Create pool (factory) & add initial liquidity – verify shares minted.
2. Add second liquidity provider – proportionate shares.
3. Swap exact in; assert invariant roughly maintained (k non-decreasing after fees) & slippage within expectation.
4. Remove liquidity; verify proportional return.
5. Protocol fee accumulation & skim.
6. Buyback path call from treasury (simulate stx reserve deposit then swap) – ensures integration.
7. Oracle cumulative update – verify TWAP over synthetic block advances.

## Deferred Items

- Multi-hop, stable/weighted pools, compliance hooks, concentrated liquidity, external oracle, on-chain pathfinder.

-- End of Phase B Design
