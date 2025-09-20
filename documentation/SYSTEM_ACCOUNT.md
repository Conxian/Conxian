# System Account Management

This document outlines the management and security practices for the Conxian protocol's system account.

## Overview

The system account is a privileged account used for protocol operations, including:
- Contract deployments
- Protocol parameter updates
- Emergency interventions
- Fee collection and distribution

## Current System Account

```
Address: SP2ED6H1EHHTZA1NTWR2GKBMT0800Y6F081EEJ45R
Public Key: 0321397ade90f85e6d634bba310633f442cef6f9dae4df054c7a3a244e78192573
```

## Security Measures

### Key Management
- The private key and mnemonic are stored in the `.env` file
- Access to the `.env` file is restricted to authorized personnel only
- The private key is never committed to version control

### Operational Security
1. **Development Environment**
   - Use the test system account for development and testing
   - Never use production credentials in development

2. **Production Environment**
   - Generate a new mnemonic and private key for production
   - Store the mnemonic in a secure, offline location
   - Consider using a hardware wallet for the production system account
   - Implement multi-signature controls for critical operations

3. **Key Rotation**
   - Rotate the system account keys periodically
   - Rotate immediately if a key compromise is suspected

## Usage in Contracts

Contracts can reference the system account using the `system` principal:

```clarity
(define-constant SYSTEM_CONTRACT 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.system)
```

## Emergency Procedures

### Key Compromise
1. Immediately transfer all assets to a new, secure account
2. Update all contract references to the new system account
3. Update environment variables and deployment configurations
4. Notify affected stakeholders

### Account Recovery
1. Use the mnemonic to recover the account
2. If mnemonic is lost, use the private key
3. If both are lost, follow the emergency recovery procedures for each contract

## Best Practices

1. **Least Privilege**
   - Only grant necessary permissions to the system account
   - Use separate accounts for different functions when possible

2. **Monitoring**
   - Monitor all transactions from the system account
   - Set up alerts for unusual activity

3. **Documentation**
   - Keep this document updated with current account information
   - Document all changes to system account permissions

## Generating a New System Account

To generate a new system account for production:

1. Use a secure, offline environment
2. Generate a new mnemonic:
   ```bash
   stx make_keychain
   ```
3. Securely store the mnemonic and private key
4. Update the `.env` file with the new credentials
5. Deploy a new version of the system contract with the new address
