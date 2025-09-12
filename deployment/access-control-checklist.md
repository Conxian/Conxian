# Access Control Deployment Checklist

## Pre-Deployment

### 1. Testing
- [ ] Run all unit tests: `npm test`
- [ ] Run integration tests: `npm run test:integration`
- [ ] Test emergency pause functionality
- [ ] Test role-based access control
- [ ] Test time-delayed operations
- [ ] Test multi-signature proposals

### 2. Security Review
- [ ] Verify all admin functions are protected
- [ ] Confirm emergency pause works as expected
- [ ] Check role assignments and permissions
- [ ] Review time delays for critical operations
- [ ] Verify multi-signature requirements

### 3. Deployment Plan
- [ ] Deploy to testnet first
- [ ] Verify contract deployment
- [ ] Initialize with admin roles
- [ ] Test all critical functions
- [ ] Schedule mainnet deployment

## Deployment Steps

### 1. Deploy AccessControl Contract
```bash
npm run deploy:access-control --network=mainnet
```

### 2. Initialize Roles
```bash
npm run init:roles --network=mainnet \
  --admin=SP3FBR2AGK5H9QBDH3EBN6Q87HWJ3H15Y8EP5J2S6
```

### 3. Update Existing Contracts
```bash
npm run migrate:access-control --network=mainnet
```

### 4. Verify Deployment
```bash
npm run verify:deployment --network=mainnet
```

## Post-Deployment

### 1. Monitoring
- [ ] Set up event monitoring
- [ ] Monitor for failed transactions
- [ ] Track role changes
- [ ] Monitor time-delayed operations

### 2. Documentation
- [ ] Update contract addresses
- [ ] Document role assignments
- [ ] Update API documentation
- [ ] Update user guides

### 3. Team Training
- [ ] Train team on new access control
- [ ] Document emergency procedures
- [ ] Review incident response plan

## Rollback Plan

### If issues occur:
1. Pause all critical operations
2. Deploy previous version
3. Restore from backup if needed
4. Investigate root cause

## Emergency Contacts
- **Security Lead**: security@example.com
- **DevOps**: ops@example.com
- **Management**: management@example.com

## Verification Scripts

### Check Role Assignment
```typescript
import { simnet } from '../.stacks/Clarigen';

async function checkRole(account: string, role: string) {
  const result = await simnet.callReadOnlyFn(
    'access-control',
    'has-role',
    [Cl.principal(account), Cl.buffFromHex(role)],
    simnet.deployer
  );
  console.log(`Account ${account} has role ${role}:`, result);
}
```

### Verify Time-Delayed Operations
```typescript
async function verifyOperation(operationId: number) {
  const op = await simnet.callReadOnlyFn(
    'access-control',
    'get-operation',
    [Cl.uint(operationId)],
    simnet.deployer
  );
  console.log('Operation status:', op);
}
```
