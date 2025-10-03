# Vaults & Strategies

## Vault
- Contract: `contracts/dex/vault.clar`
- Traits: `vault-trait`, `vault-admin-trait`
- Features: strategy mapping, distribution hooks via `token-system-coordinator` principal variable.

## Strategies
- Example: `contracts/dex/enhanced-yield-strategy.clar`
- Trait: `strategy-trait`
- Functions: deploy/withdraw, harvest, dimensional weights update, performance history.

## Flash Loan Vaults
- Contracts: `contracts/dex/flash-loan-vault.clar`, `contracts/dex/sbtc-flash-loan-extension.clar`
- Trait: `flash-loan-receiver-trait`
- Notes: MEV integration planned; circuit-breaker hooks recommended.
