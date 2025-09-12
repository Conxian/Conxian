# Conxian Protocol Error Codes

This document outlines the standardized error codes used across the Conxian protocol.

## Error Code Ranges

| Component | Range | Description |
|-----------|-------|-------------|
| Common Errors | 1000-1999 | Shared across all contracts |
| Liquidation Manager | 1000-1099 | Liquidation-specific errors |
| Lending System | 2000-2999 | Core lending protocol errors |
| Vault System | 3000-3999 | Vault and strategy errors |
| Oracle | 4000-4999 | Price feed and oracle errors |
| Governance | 5000-5999 | Governance and access control |
| Token System | 6000-6999 | Token-related errors |
| Staking | 7000-7999 | Staking and rewards errors |
| Bridge | 8000-8999 | Cross-chain bridge errors |
| Migration | 9000-9999 | Migration and upgrade errors |

## Common Errors (1000-1999)

| Code | Constant | Description |
|------|----------|-------------|
| 1000 | ERR_UNKNOWN | An unknown error occurred |
| 1001 | ERR_LIQUIDATION_PAUSED | Liquidation is currently paused |
| 1002 | ERR_UNAUTHORIZED | Caller is not authorized |
| 1003 | ERR_INVALID_AMOUNT | Invalid amount specified |
| 1004 | ERR_POSITION_NOT_UNDERWATER | Position is not underwater |
| 1005 | ERR_SLIPPAGE_TOO_HIGH | Slippage exceeds maximum allowed |
| 1006 | ERR_LIQUIDATION_NOT_PROFITABLE | Liquidation would not be profitable |
| 1007 | ERR_MAX_POSITIONS_EXCEEDED | Maximum number of positions exceeded |
| 1008 | ERR_ASSET_NOT_WHITELISTED | Asset is not whitelisted |
| 1009 | ERR_INSUFFICIENT_COLLATERAL | Insufficient collateral |
| 1010 | ERR_INSUFFICIENT_LIQUIDITY | Insufficient liquidity |

## Lending System Errors (2000-2999)

| Code | Constant | Description |
|------|----------|-------------|
| 2000 | ERR_INVALID_ASSET | Invalid or unsupported asset |
| 2001 | ERR_INSUFFICIENT_BALANCE | Insufficient balance |
| 2002 | ERR_HEALTH_FACTOR_TOO_LOW | Health factor below minimum threshold |
| 2003 | ERR_INVALID_INTEREST_RATE | Invalid interest rate parameters |
| 2004 | ERR_RESERVE_FACTOR_TOO_HIGH | Reserve factor exceeds maximum |

## Vault System Errors (3000-3999)

| Code | Constant | Description |
|------|----------|-------------|
| 3000 | ERR_VAULT_PAUSED | Vault operations are paused |
| 3001 | ERR_INSUFFICIENT_SHARES | Insufficient shares to redeem |
| 3002 | ERR_STRATEGY_ACTIVE | Strategy is already active |
| 3003 | ERR_STRATEGY_INACTIVE | Strategy is not active |
| 3004 | ERR_STRATEGY_DEBT_LIMIT | Strategy debt limit exceeded |

## Oracle Errors (4000-4999)

| Code | Constant | Description |
|------|----------|-------------|
| 4000 | ERR_PRICE_STALE | Price data is too old |
| 4001 | ERR_PRICE_INVALID | Invalid price data |
| 4002 | ERR_ORACLE_DISPUTED | Price is disputed |
| 4003 | ERR_ORACLE_NOT_FOUND | Oracle not found for asset |

## Governance Errors (5000-5999)

| Code | Constant | Description |
|------|----------|-------------|
| 5000 | ERR_GOVERNANCE_ONLY | Caller is not governance |
| 5001 | ERR_TIMELOCK_NOT_EXPIRED | Timelock has not expired |
| 5002 | ERR_INSUFFICIENT_VOTES | Insufficient voting power |
| 5003 | ERR_VOTING_CLOSED | Voting is closed |

## Token System Errors (6000-6999)

| Code | Constant | Description |
|------|----------|-------------|
| 6000 | ERR_TRANSFER_FAILED | Token transfer failed |
| 6001 | ERR_APPROVAL_FAILED | Token approval failed |
| 6002 | ERR_INSUFFICIENT_ALLOWANCE | Insufficient allowance |

## Staking Errors (7000-7999)

| Code | Constant | Description |
|------|----------|-------------|
| 7000 | ERR_STAKING_PAUSED | Staking is paused |
| 7001 | ERR_INSUFFICIENT_STAKE | Insufficient stake |
| 7002 | ERR_STAKE_LOCKED | Stake is still locked |
| 7003 | ERR_REWARDS_NOT_CLAIMABLE | Rewards not yet claimable |

## Bridge Errors (8000-8999)

| Code | Constant | Description |
|------|----------|-------------|
| 8000 | ERR_INVALID_CHAIN | Invalid chain ID |
| 8001 | ERR_INVALID_MESSAGE | Invalid bridge message |
| 8002 | ERR_ALREADY_PROCESSED | Message already processed |
| 8003 | ERR_INVALID_SIGNATURE | Invalid bridge signature |

## Migration Errors (9000-9999)

| Code | Constant | Description |
|------|----------|-------------|
| 9000 | ERR_MIGRATION_NOT_STARTED | Migration has not started |
| 9001 | ERR_MIGRATION_COMPLETED | Migration already completed |
| 9002 | ERR_INVALID_MIGRATION_DATA | Invalid migration data |
| 9003 | ERR_MIGRATION_PAUSED | Migration is paused |

## Best Practices

1. Always use the named constants instead of raw error codes
2. When adding new errors, use the next available code in the appropriate range
3. Update this documentation when adding new error codes
4. Include descriptive error messages in the contract code
5. Log relevant context with errors when possible
