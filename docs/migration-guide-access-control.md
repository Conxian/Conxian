# Migration Guide: Updating to New Access Control System

This guide explains how to update your existing contracts to use the new AccessControl system implemented in AIP-7.

## Overview

The new AccessControl system provides:
- Role-based access control (RBAC)
- Time-delayed execution of sensitive operations
- Emergency pause functionality
- Multi-signature requirements for critical operations

## Step 1: Update Contract Dependencies

1. Add the new access control trait to your contract:

```clarity
(use-trait access-control .access-control-trait.access-control-trait)
```

2. Update your contract's trait implementation to include the access control trait:

```clarity
(impl-trait 
  'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.your-contract-trait
  .access-control-trait.access-control-trait
)
```

## Step 2: Replace Ownable with AccessControl

### Before:

```clarity
(define-constant contract-owner tx-sender)

(define-public (only-owner)
  (asserts! (is-eq tx-sender contract-owner) (err u1001))
  (ok true)
)
```

### After:

```clarity
(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.access-control.access-control-trait)

;; Use the access control functions directly
(define-public (only-admin)
  (contract-call? .access-control only-role 'ADMIN)
)
```

## Step 3: Update Function Access Control

### Before:

```clarity
(define-public (set-parameter (new-value uint))
  (let ((sender tx-sender))
    (asserts! (is-eq sender contract-owner) (err u1001))
    (var-set parameter new-value)
    (ok true)
  )
)
```

### After:

```clarity
(define-public (set-parameter (new-value uint))
  (let ((sender tx-sender))
    (try! (contract-call? .access-control only-role 'OPERATOR))
    (var-set parameter new-value)
    (ok true)
  )
)
```

## Step 4: Add Time-Delayed Operations

For sensitive operations, use the time-delay functionality:

```clarity
(define-public (update-risk-parameters (params {high: uint, medium: uint, low: uint}))
  (let ((operation-id (unwrap! 
    (contract-call? 
      .access-control 
      schedule 
      'UPDATE_RISK_PARAMS 
      (to-utf8 (to-json-string params)) 
      u5760  ;; 24 hours in blocks (assuming 15s block time)
    ) 
    (err u1001)
  )))
    (ok operation-id)
  )
)

;; Call this after the delay has passed
(define-public (execute-update-risk-params (operation-id uint))
  (let ((result (contract-call? .access-control execute operation-id)))
    (match result
      (ok success) (ok success)
      (err error) (err error)
    )
  )
)
```

## Step 5: Implement Emergency Pause

Add emergency pause functionality to critical functions:

```clarity
(define-public (withdraw (amount uint) (to principal))
  (begin
    (try! (contract-call? .access-control when-not-paused))
    ;; Withdraw logic here
    (ok true)
  )
)
```

## Step 6: Update Tests

Update your tests to work with the new access control system:

```typescript
// Before
describe('Admin functions', () => {
  it('should allow owner to update parameters', async () => {
    const result = await simnet.callPublicFn(
      'your-contract',
      'set-parameter',
      [Cl.uint(100)],
      admin
    );
    expect(result).toBeOk(Cl.bool(true));
  });
});

// After
describe('Admin functions', () => {
  it('should allow admin to update parameters', async () => {
    // First grant admin role
    await simnet.callPublicFn(
      'access-control',
      'grant-role',
      [Cl.principal(admin), Cl.buffFromHex('0x41444d494e')], // ADMIN role
      admin
    );
    
    const result = await simnet.callPublicFn(
      'your-contract',
      'set-parameter',
      [Cl.uint(100)],
      admin
    );
    expect(result).toBeOk(Cl.bool(true));
  });
});
```

## Migration Checklist

- [ ] Update contract dependencies
- [ ] Replace Ownable with AccessControl
- [ ] Update function access control
- [ ] Implement time-delayed operations for sensitive functions
- [ ] Add emergency pause functionality
- [ ] Update tests
- [ ] Deploy to testnet for verification
- [ ] Schedule mainnet deployment

## Best Practices

1. **Principle of Least Privilege**: Only grant the minimum permissions necessary
2. **Use Roles**: Define clear roles with specific responsibilities
3. **Time-Delay Critical Operations**: Add delays for sensitive operations
4. **Test Thoroughly**: Ensure all access control paths are tested
5. **Monitor Events**: Set up monitoring for role changes and access control events

## Troubleshooting

### Error: "Missing role"
Ensure the caller has been granted the appropriate role before calling restricted functions.

### Error: "Contract call not allowed"
Verify that the contract calling the access control functions is properly whitelisted if using call restrictions.

### Error: "Operation not ready"
Check that the time delay has passed before executing time-delayed operations.
