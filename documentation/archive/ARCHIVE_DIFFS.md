# Archived Contract Diffs (Conxian)

Purpose: Document differences between removed variant contracts and their active counterparts for audit trail and potential future reference.

Date: 2025-08-18  
Removal Reason: Reduce audit surface, eliminate redundant code paths, maintain only production-ready contracts.

## Removed Files Summary

| Removed File | Active Equivalent | Key Differences | Removal Rationale |
|--------------|-------------------|-----------------|-------------------|
| `vault-original.clar` | `vault.clar` | Original lacks: performance fees, flash loans, liquidation, precision shares, revenue stats | Active is strict superset; original simpler but less capable |
| `dao-governance-original.clar` | `dao-governance.clar` | Original lacks test-mode, AIP-2 time-weighted voting integration | Active implements full governance requirements |
| `enhanced-dao-governance.clar` | `dao-governance.clar` | Enhanced version duplicates time-weighted snapshot subset | Merged into active; redundancy removed |
| `bounty-system-original.clar` | `bounty-system.clar` | Original lacks AIP-4 dispute + proof system | Active includes full security hardening |
| `weighted-pool.clar.disabled` | `weighted-pool.clar` | Disabled had richer swap return `{ amount-out, fee }` | Fee transparency restored via read-only getter |
| `backup-20250816-090206/*` | Various active contracts | Backup copies from before major refactor | Superseded by current implementations |

## Hash Records

Pre-removal file hashes for audit trail:

```bash
# Generated 2025-08-18 before cleanup
4577d38afc616bc46cd7568e818a9ffd41bdc96425b3b1651f16a7331a11e3ad  stacks/contracts/vault-original.clar
7714eeff55cc26ff9388ccef51981290b9eb507ae520e1b175dadb66298c2cbc  stacks/contracts/dao-governance-original.clar
e87eb6c9bf36209410f1f241ee468dcf457fd008b518d77ee8681a4c539dff84  stacks/contracts/enhanced-dao-governance.clar
23ef50db7c6e624c3de5f16e504a0bf8ed6bff41753528a161d4baf8f625f4f2  stacks/contracts/bounty-system-original.clar
59108a90015fde2d9e7c6eaf25aa060cf070acfa11318515c8fee6767ff1eafb  stacks/contracts/weighted-pool.clar.disabled
c5a3b8b5020d128bd8b3a84c7cc66111caecde6a645dcef4811224610316267e  stacks/contracts/backup-20250816-090206/treasury.clar
```

## Verification

- ✅ No tests reference removed variants (grep confirmed)
- ✅ Clarinet.toml does not deploy removed variants
- ✅ All unique functionality preserved in active contracts
- ✅ Weighted pool fee transparency restored via `get-last-swap-fee`
- ✅ Test coverage: 113/113 passing after restoration

## Restoration Completeness

All identified enhancements from archive audit have been accounted for:

1. **Vault Enhancements**: Active vault includes all performance fees, flash loans, liquidation, precision shares, revenue stats
2. **Governance Enhancements**: Active DAO includes time-weighted voting (AIP-2), test mode, full lifecycle management  
3. **Bounty Security**: Active bounty system includes AIP-4 dispute/proof hardening
4. **Treasury Management**: Active treasury includes multisig, growth strategies, automated buybacks
5. **DEX Fee Transparency**: Weighted pool fee visibility restored via read-only accessor + test coverage

No functionality lost in cleanup process.

---
Prepared by: Conxian Core Agent  
Rationale: Maintain audit trail while reducing attack surface for mainnet deployment.
