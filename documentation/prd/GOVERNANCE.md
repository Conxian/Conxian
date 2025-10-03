# Governance & Access Control

## Access Control
- `contracts/governance/access-control.clar`
- Trait: `access-control-trait`
- Roles: ADMIN, OPERATOR, EMERGENCY etc.; multi-sig proposals, delayed operations, circuit-breaker checks.

## Governance (Lending Protocol)
- `contracts/governance/lending-protocol-governance.clar`
- Proposal lifecycle, voting thresholds, queue/execute windows.
- Integrates with `cxvg-utility` for voting power queries.
