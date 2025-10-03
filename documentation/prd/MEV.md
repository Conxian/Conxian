# MEV Protection

## Commit-Reveal & Batch Ordering
- `contracts/security/mev-protector.clar` and `contracts/mev-protector.clar`
- Commitments with start block, reveal window checks, batch order queues.

## Guidance
- Use commit periods and reveal periods sized for expected latency.
- Integrate with DEX settlement to ensure fair ordering.
