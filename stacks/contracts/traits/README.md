# Conxian Protocol - Traits

## ⚠️ IMPORTANT DEPRECATION NOTICE

**As of SDK 3.7.0 (October 2025)**: All trait definitions are centralized in `all-traits.clar`. Individual trait files in subdirectories (`core/`, `defi/`, `security/`, etc.) are **DEPRECATED** and maintained only for reference.

## Overview

The Conxian protocol uses a centralized trait system for consistency and maintainability. All trait definitions are contained in `all-traits.clar`, ensuring standardized interfaces across the entire protocol.

## Current Status ✅

- ✅ **Centralized**: All traits defined in `all-traits.clar` (718 lines, 40+ traits)
- ✅ **No Duplicates**: Individual trait files deprecated
- ✅ **Well Organized**: Traits categorized by functionality within `all-traits.clar`
- ✅ **Enhanced Features**: Comprehensive trait definitions with advanced functionality
- ⚠️ **Legacy Files**: Individual trait files in subdirectories are deprecated (for removal in future version)

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
2. Organize by category using comments
3. Include comprehensive function signatures
4. Add appropriate error codes
5. Update this README

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
