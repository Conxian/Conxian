# GitHub Secrets Reference

This document outlines the GitHub Secrets configured for the Conxian project.

## Deployment Secrets

### Testnet
- `TESTNET_DEPLOYER_KEY`: Private key for testnet deployment
- `TESTNET_DEPLOYER_MNEMONIC`: Mnemonic phrase for testnet deployer
- `TESTNET_WALLET1_MNEMONIC`: Mnemonic for test wallet 1
- `TESTNET_WALLET2_MNEMONIC`: Mnemonic for test wallet 2

### Mainnet
- `MAINNET_DEPLOYER_KEY`: Private key for mainnet deployment
- `MAINNET_DEPLOYER_MNEMONIC`: Mnemonic phrase for mainnet deployer

### API Keys
- `HIRO_API_KEY`: API key for Hiro services
- `STACKS_PRIVKEY`: Private key for Stacks operations

### Vault Configuration
- `VAULT_CONTRACT_ADDRESS`: Address of the vault contract

## Usage in Workflows

### Testnet Deployment
```yaml
env:
  TESTNET_DEPLOYER_KEY: ${{ secrets.TESTNET_DEPLOYER_KEY }}
  HIRO_API_KEY: ${{ secrets.HIRO_API_KEY }}
  TESTNET_DEPLOYER_MNEMONIC: ${{ secrets.TESTNET_DEPLOYER_MNEMONIC }}
  TESTNET_WALLET1_MNEMONIC: ${{ secrets.TESTNET_WALLET1_MNEMONIC }}
  TESTNET_WALLET2_MNEMONIC: ${{ secrets.TESTNET_WALLET2_MNEMONIC }}
```

### Keeper Configuration
```yaml
env:
  STACKS_PRIVKEY: ${{ secrets.STACKS_PRIVKEY }}
  VAULT_CONTRACT: ${{ secrets.VAULT_CONTRACT_ADDRESS }}
```

## Security Notes
- All secrets are stored in GitHub's encrypted secrets store
- Access is restricted to repository administrators
- Rotate secrets regularly, especially after team member changes
- Never hardcode these values in the codebase
