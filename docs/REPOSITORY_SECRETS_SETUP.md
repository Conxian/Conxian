# Repository Secrets Setup Guide

This document provides step-by-step instructions for configuring the required GitHub repository secrets for Conxian's CI/CD workflows.

## Required Secrets

The following secrets must be configured in your GitHub repository for the workflows to function properly:

| Secret Name | Purpose | Used In | Required |
|-------------|---------|---------|----------|
| `TESTNET_DEPLOYER_KEY` | Stacks testnet private key for contract deployment | `.github/workflows/deploy-testnet.yml` | Yes |
| `HIRO_API_KEY` | API key for Hiro Platform services | `.github/workflows/deploy-testnet.yml`, `chainhook-register.yml` | Yes |
| `TESTNET_DEPLOYER_MNEMONIC` | Deployer wallet mnemonic (testnet) | `.github/workflows/deploy-testnet.yml` | Yes |
| `TESTNET_WALLET1_MNEMONIC` | Secondary wallet mnemonic (testnet) | `.github/workflows/deploy-testnet.yml` | Yes |
| `TESTNET_WALLET2_MNEMONIC` | Secondary wallet mnemonic (testnet) | `.github/workflows/deploy-testnet.yml` | Yes |
| `MAINNET_DEPLOYER_KEY` | Stacks mainnet private key for contract deployment | Mainnet workflows (future) | Optional |

## Setup Instructions

### 1. Navigate to Repository Settings

1. Go to your GitHub repository: `https://github.com/your-org/Conxian`
2. Click on **Settings** tab
3. In the left sidebar, navigate to **Security** → **Secrets and variables** → **Actions**

### 2. Add Repository Secrets

Click **New repository secret** and add each of the following:

#### TESTNET_DEPLOYER_KEY

- **Name**: `TESTNET_DEPLOYER_KEY`
- **Value**: Your Stacks testnet private key (64-character hex string)
- **Example format**: `a1b2c3d4e5f6789012345678901234567890123456789012345678901234567890`
- **Security**: Ensure this key has only testnet STX for testing

#### HIRO_API_KEY  

- **Name**: `HIRO_API_KEY`
- **Value**: Your Hiro Platform API key
- **How to obtain**:
  1. Visit [Hiro Platform](https://platform.hiro.so)
  2. Create an account or log in
  3. Generate an API key in your dashboard
- **Example format**: `hiro_sk_01234567890abcdef`

#### STACKS_PRIVKEY

- **Name**: `STACKS_PRIVKEY`
- **Value**: Private key for keeper operations
- **Security**: Use a dedicated key with minimal STX balance
- **Example format**: `a1b2c3d4e5f6789012345678901234567890123456789012345678901234567890`

#### VAULT_CONTRACT_ADDRESS

- **Name**: `VAULT_CONTRACT_ADDRESS`
- **Value**: Deployed vault contract principal address
- **Example format**: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.vault-v1`
- **Note**: Update this after deploying your vault contract

## Security Best Practices

### Private Key Security

- **Never commit private keys to code**
- **Use testnet keys for development/staging**
- **Rotate keys regularly**
- **Use dedicated keys with minimal balances**
- **Enable 2FA on GitHub account**

### API Key Security

- **Regenerate API keys periodically**
- **Use minimum required permissions**
- **Monitor API usage for anomalies**

## Validation

Once all secrets are configured, the workflows will automatically validate them before execution:

- ✅ **Success**: Workflows proceed normally
- ❌ **Failure**: Clear error message indicating missing secrets

### Testing Secret Configuration

1. Push a commit to trigger the workflows
2. Check the workflow runs in **Actions** tab
3. Look for the "Validate secrets" step in each workflow
4. Verify all validations pass with "✅ Required secrets validated"

## Workflow-Specific Requirements

### Conxian CI/CD Pipeline (`ci.yml`)

- Purpose: Compile contracts (`clarinet check`) and run tests (`vitest`)
- Requires: none (no secrets)

### Testnet Deployment (`deploy-testnet.yml`)

- Requires: `TESTNET_DEPLOYER_KEY`, `HIRO_API_KEY`, `TESTNET_DEPLOYER_MNEMONIC`, `TESTNET_WALLET1_MNEMONIC`, `TESTNET_WALLET2_MNEMONIC`
- Triggers: Manual workflow dispatch (with `dry_run` field)
- Purpose: Generate plan (dry run) and optionally broadcast live deployment

### Chainhook Registration (`chainhook-register.yml`)  

- Requires: `HIRO_API_KEY`
- Triggers: Manual workflow dispatch
- Purpose: Register blockchain event hooks

### Keeper Operations (`keeper-cron.yml`)

- Requires: `STACKS_PRIVKEY`, `VAULT_CONTRACT_ADDRESS`
- Triggers: Scheduled (cron) execution
- Purpose: Automated vault maintenance

## Troubleshooting

### Common Issues

#### "Secret not configured" Error

```
⚠️ TESTNET_DEPLOYER_KEY secret not configured
Please add this secret in repository Settings → Secrets and variables → Actions
```

**Solution**: Add the missing secret following the setup instructions above.

#### Invalid Private Key Format

**Symptoms**: Deployment failures with key format errors
**Solution**: Ensure private key is 64-character hex string without `0x` prefix

#### API Key Permission Errors

**Symptoms**: 401/403 errors when calling Hiro APIs
**Solution**: Verify API key has correct permissions and hasn't expired

#### Contract Address Not Found

**Symptoms**: Keeper operations fail with contract not found
**Solution**: Verify `VAULT_CONTRACT_ADDRESS` matches deployed contract

### Getting Help

1. **Check workflow logs** in GitHub Actions tab
2. **Verify secret names** match exactly (case-sensitive)
3. **Test on testnet first** before mainnet deployment
4. **Contact team** if issues persist

## Environment-Specific Notes

### Development

- Use testnet keys and contracts only
- API keys should have limited scope

### Production  

- Use mainnet keys with appropriate security measures
- Monitor all automated operations
- Set up alerting for failures

---

**Last Updated**: September 08, 2025
**Maintainer**: Conxian Development Team
