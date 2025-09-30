# Traits (Centralized)

- Source of truth: `contracts/traits/all-traits.clar`
- Usage pattern:

```clarity
(use-trait pool-trait .all-traits.pool-trait)
(impl-trait .pool-trait)
```

## Core Traits
- sip-010-ft-trait, sip-010-ft-mintable-trait
- sip-009-nft-trait
- sip-018-trait
- oracle-trait, oracle-aggregator-trait, dimensional-oracle-trait
- vault-trait, vault-admin-trait, strategy-trait
- access-control-trait, ownable-trait, pausable-trait
- circuit-breaker-trait
- math-trait, fixed-point-math-trait
- pool-trait, factory-trait, router-trait, fee-manager-trait
- mev-protector-trait, performance-optimizer-trait

## Guidelines
- Always import from `.all-traits`.
- Use consistent alias names matching the trait name.
- Prefer read-only views for getters; avoid dynamic string concatenations.
