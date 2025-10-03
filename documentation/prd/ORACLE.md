# Oracles

## Oracle Aggregator
- `contracts/oracle/oracle-aggregator.clar`
- Trait: `oracle-aggregator-trait`
- Stores submitted prices by block, last observation per asset.

## Dimensional Oracle
- `contracts/oracle/dimensional-oracle.clar`
- Heartbeat, max deviation, multiple feeds per token
- Aggregation via median of valid feeds; deviation checks against prior

## Mock Oracle
- `contracts/mocks/mock-oracle.clar`
- Minimal trait implementation for tests
