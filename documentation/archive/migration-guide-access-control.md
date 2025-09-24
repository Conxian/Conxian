# Access Control Migration Guide

This guide provides step-by-step instructions for integrating the new AccessControl contract with existing Conxian protocol contracts.

## Overview

The new AccessControl system provides:
- Role-based access control (RBAC)
- Emergency pause functionality
- Time-delayed role changes
- Multi-signature support
- Comprehensive event logging

## Prerequisites

- Conxian contracts v2.0.0 or later
- Clarinet v3.5.0+
- Node.js v18+

## Migration Steps

### 1. Update Contract Dependencies

Add the AccessControl trait to your contract:

```clarity
(use-trait access-control-trait .access-control.access-control-trait)
```

### 2. Define Required Roles

Add role constants to your contract:

```clarity
;; Role identifiers (keccak256 hashes of role names)
(define-constant ROLE_ADMIN 0x41444d494e000000000000000000000000000000000000000000000000000000)
(define-constant ROLE_OPERATOR 0x4f50455241544f52000000000000000000000000000000000000000000000000)
```

### 3. Add Access Control Checks

Modify your public functions to include role checks:

```clarity
(define-public (protected-function)
  (begin
    ;; Check if caller has required role
    (try! (contract-call? .access-control has-role ROLE_OPERATOR (as-contract tx-sender)))
    
    ;; Function logic here
    (ok true)
  )
)
```

### 4. Handle Emergency Pause

Add pause checks to critical functions:

```clarity
(define-public (critical-function)
  (begin
    (try! (contract-call? .access-control when-not-paused))
    
    ;; Function logic here
    (ok true)
  )
)
```

### 5. Update Deployment Scripts

Modify your deployment scripts to initialize roles:

```typescript
// Initialize admin role
await simnet.callPublicFn(
  'access-control',
  'grant-role',
  [
    Cl.buffer(hexToBuffer(ROLES.ADMIN)),
    Cl.principal(adminAddress)
  ],
  adminAddress
);
```

## Testing

1. Test role-based access control
2. Verify emergency pause functionality
3. Test time-delayed role changes
4. Validate multi-signature operations

## Troubleshooting

### Common Issues

1. **Missing Role**: Ensure the role is properly granted before calling protected functions.
2. **Paused Contract**: Check if the contract is paused before performing operations.
3. **Insufficient Signatures**: Verify the required number of signatures for multi-sig operations.

## Best Practices

1. Use the principle of least privilege when assigning roles
2. Implement comprehensive event logging
3. Test all access control scenarios
4. Document role assignments and permissions

## Security Considerations

1. Always use time delays for critical role changes
2. Implement multi-signature requirements for admin operations
3. Monitor for unauthorized access attempts
4. Regularly review and audit role assignments
