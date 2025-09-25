# Conxian Trait Registry

## Overview
The Trait Registry is a central contract that manages trait implementations in the Conxian protocol. It provides a standardized way to discover and use traits across different contracts.

## Key Features

1. **Centralized Trait Management**
   - Single source of truth for all trait implementations
   - Easy discovery of available traits
   - Versioning support for traits

2. **Trait Lifecycle**
   - Register new trait implementations
   - Deprecate old traits
   - Suggest replacements for deprecated traits

3. **Metadata**
   - Rich metadata for each trait
   - Version tracking
   - Descriptions and documentation

## Usage

### Registering a New Trait

```clarity
(register-trait 
  "my-trait"  ;; trait name
  1           ;; version
  "Description of my trait"
  'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.my-contract
  false       ;; deprecated
  none        ;; replacement (optional)
)
```

### Using a Trait in Your Contract

```clarity
;; 1. Define the trait registry constant
(define-constant TRAIT_REGISTRY 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.trait-registry)

;; 2. Resolve the trait at deployment time
(use-trait my-trait (unwrap! (contract-call? TRAIT_REGISTRY get-trait-contract 'my-trait) (err u1000)))

;; 3. Implement the trait
(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.my-trait)
```

### Checking if a Trait is Deprecated

```clarity
(contract-call? TRAIT_REGISTRY is-trait-deprecated 'my-trait)
```

### Finding a Replacement for a Deprecated Trait

```clarity
(contract-call? TRAIT_REGISTRY get-trait-replacement 'deprecated-trait)
```

## Best Practices

1. **Always Use the Registry**
   - Never hardcode trait principals in your contracts
   - Always resolve traits through the registry

2. **Versioning**
   - Increment version numbers for breaking changes
   - Document changes between versions

3. **Deprecation**
   - Mark old traits as deprecated when replacing them
   - Always provide a replacement when deprecating
   - Keep deprecated traits in the registry for backward compatibility

4. **Error Handling**
   - Always handle cases where a trait might not be found
   - Use meaningful error codes

## Initialization

Use the provided initialization script to register standard traits:

```typescript
import { initializeTraitRegistry } from '../scripts/init-trait-registry';

// In your test or deployment script
await initializeTraitRegistry(chain, deployer);
```

## Security Considerations

- Only the contract owner can register or update traits
- Always verify the trait contract address before using it
- Be cautious when updating existing trait implementations
