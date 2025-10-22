# Conxian Protocol - Traits & Error System

## ⚠️ IMPORTANT NOTICE

**As of SDK 3.7.0 (October 2025)**:

- All trait definitions are centralized in `all-traits.clar`
- Standardized error codes are defined in `errors.clar`
- Individual trait files in subdirectories are **DEPRECATED**

## Overview

The Conxian protocol uses:

1. **Centralized Traits**: All interfaces in `all-traits.clar`
1. **Standardized Errors**: Comprehensive error codes in `errors.clar`
1. **Consistent Patterns**: Unified approach across all contracts

## Current Status

### Traits

- **Centralized**: 40+ traits in `all-traits.clar`
- **Well Organized**: Grouped by functionality
- **Documented**: Each trait has usage examples
- **Legacy Files**: Individual trait files are deprecated

### Error System

- **Comprehensive**: 100+ error codes
- **Categorized**: Grouped by error type
- **Documented**: Clear usage guidelines

## Error Code Ranges

| Range | Category | Example Errors |
|-------|----------|----------------|
| 1000-1999 | General | `ERR_UNAUTHORIZED`, `ERR_INVALID_INPUT` |
| 2000-2999 | Arithmetic | `ERR_OVERFLOW`, `ERR_UNDERFLOW` |
| 3000-3999 | Token Ops | `ERR_TOKEN_TRANSFER_FAILED` |
| 4000-4999 | Protocol | `ERR_EMISSION_LIMIT_EXCEEDED` |
| 5000-5999 | Oracle | `ERR_ORACLE_STALE_PRICE` |
| 6000-6999 | Governance | `ERR_PROPOSAL_NOT_FOUND` |
| 7000-7999 | Access | `ERR_ROLE_REQUIRED` |
| 8000-8999 | Validation | `ERR_INVALID_ADDRESS` |
| 9000-9999 | System | `ERR_INTEGRATION_DISABLED` |
| 10000+ | Advanced | `ERR_CIRCUIT_TRIPPED` |

## Trait Categories

### Core Protocol Traits

- **Token Standards**: `sip-010-ft-trait`, `sip-009-nft-trait`
- **Access Control**: `access-control-trait`, `ownable-trait`
- **Circuit Breaker**: `circuit-breaker-trait`, `pausable-trait`

### DeFi Components

- **Lending**: `lending-system-trait`, `liquidation-trait`
- **Vaults**: `vault-trait`, `vault-admin-trait`
- **Strategies**: `strategy-trait`, `yield-optimizer-trait`
- **Staking**: `staking-trait`

### Governance & DAO

- **Governance**: `dao-trait`
- **Oracle**: `oracle-trait`, `dimensional-oracle-trait`
- **Registry**: `dim-registry-trait`

### Infrastructure

- **Monitoring**: `monitoring-trait`
- **Compliance**: `compliance-hooks-trait`
- **Constants**: `standard-constants-trait`
- **Math**: `math-trait`

### DEX & Trading

- **Pool**: `pool-trait`, `pool-creation-trait`
- **Factory**: `factory-trait`
- **Router**: `router-trait`

## Usage

### Import Traits

```clarity
(use-trait <trait-name> .all-traits.<trait-name>)
```

### Example Contract Implementation

```clarity
(use-trait vault-trait .all-traits.vault-trait)

(define-trait my-vault-implementation
  (
    (implements .all-traits.vault-trait)
    ;; Additional functions specific to this implementation
  )
)
```

## Migration Guide

### For Existing Contracts

1. Replace individual trait imports with centralized imports:

   ```clarity
   ;; Old (deprecated)
   (use-trait vault-trait .all-traits.vault-trait)

   ;; New (recommended)
   (use-trait vault-trait .all-traits.vault-trait)
   ```

1. Update trait references to use standardized names

1. Remove any local trait definitions

### For New Contracts

- Always import from `all-traits.clar`
- Follow the established trait patterns
- Ensure consistency with existing interfaces

## Development Guidelines

### Adding New Traits

1. Add new trait definitions to `all-traits.clar`
1. Organize by category using comments
1. Include comprehensive function signatures
1. Add appropriate error codes
1. Update this README

### Trait Standards

- Use consistent naming conventions
- Include comprehensive error handling
- Provide both read-only and state-changing functions
- Follow Clarity best practices
- Include proper documentation comments

## Error Code Standards

### Access Control Errors (u100-u199)

- `ERR_NOT_AUTHORIZED` (u100)
- `ERR_INVALID_ROLE` (u101)
- `ERR_ROLE_ALREADY_GRANTED` (u102)

### Pausing Errors (u200-u299)

- `ERR_PAUSED` (u200)
- `ERR_NOT_PAUSED` (u201)

### Liquidation Errors (u1000-u1099)

- `ERR_LIQUIDATION_PAUSED` (u1001)
- `ERR_POSITION_NOT_UNDERWATER` (u1004)
- `ERR_SLIPPAGE_TOO_HIGH` (u1005)

## Error Code Usage

Always reference errors from `errors.clar`:

```clarity
(asserts! (is-eq caller sender) ERR_UNAUTHORIZED)
```

## Testing

All traits should be tested using the protocol's testing framework. Ensure:

- Trait implementations conform to specifications
- Error conditions are properly handled
- Integration with other traits works correctly
- Performance meets requirements

## Maintenance

- Regularly review trait definitions for consistency
- Update deprecated traits appropriately
- Maintain backward compatibility where possible
- Keep documentation current
