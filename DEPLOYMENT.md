# Conxian Testnet Deployment Guide

This guide explains how to deploy the Conxian smart contracts to the Stacks testnet.

## Prerequisites

1. Install [GitHub CLI](https://cli.github.com/)
2. Install [jq](https://stedolan.github.io/jq/download/)
3. Install [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/)
4. Authenticate with GitHub: `gh auth login`

## Deployment Steps

### 1. Set Up Deployment Environment

1. Clone the repository:
   ```bash
   git clone https://github.com/Anya-org/Conxian.git
   cd Conxian
   ```

2. Run the deployment setup script:
   ```powershell
   .\scripts\deploy-testnet.ps1
   ```

   This will:
   - Update all contract files with the new deployer address
   - Set up the GitHub secret for deployment
   - Commit the changes

### 2. Push Changes to GitHub

Push the changes to trigger the deployment workflow:
```bash
git push
```

### 3. Deploy to Testnet

1. Go to the [GitHub Actions](https://github.com/Anya-org/Conxian/actions) tab
2. Select the "Deploy to Testnet" workflow
3. Click "Run workflow"
4. Enter `DEPLOY` in the confirmation field
5. Set `dry_run` to `false` for an actual deployment
6. Click "Run workflow"

### 4. Monitor Deployment

Monitor the deployment progress in the GitHub Actions tab. The workflow will:

1. Run pre-deployment checks
2. Compile all contracts
3. Deploy to the Stacks testnet
4. Verify the deployment

## Environment Variables

The following secrets need to be set in your GitHub repository:

- `TESTNET_DEPLOYER_KEY`: Private key for the deployer account
- `HIRO_API_KEY`: API key for Hiro services (optional but recommended)
- `TESTNET_DEPLOYER_MNEMONIC`: Mnemonic for the deployer account (optional)
- `TESTNET_WALLET1_MNEMONIC`: Test wallet 1 mnemonic (optional)
- `TESTNET_WALLET2_MNEMONIC`: Test wallet 2 mnemonic (optional)

## Manual Deployment (Alternative)

If you prefer to deploy manually:

1. Install Clarinet:
   ```bash
   curl -L https://github.com/hirosystems/clarinet/releases/download/v3.5.0/clarinet-linux-x64-glibc.tar.gz | tar xz
   chmod +x clarinet
   sudo mv clarinet /usr/local/bin/
   ```

2. Deploy to testnet:
   ```bash
   export STACKS_DEPLOYER_KEY=your-private-key-here
   clarinet deployments apply -p testnet
   ```

## Verification

After deployment, you can verify the contracts on the [Stacks Explorer](https://explorer.hiro.so/).

## Troubleshooting

- **Deployment fails with "insufficient balance"**: Fund the deployer address with testnet STX from the [Stacks Testnet Faucet](https://explorer.hiro.so/sandbox/faucet?chain=testnet)
- **Permission denied when running scripts**: Make the script executable with `chmod +x scripts/*.sh`
- **GitHub API rate limits**: Authenticate with GitHub using `gh auth login`

## Security Considerations

- Never commit private keys or mnemonics to version control
- Use environment variables for sensitive information
- Always test deployments on testnet before mainnet
- Keep your deployer keys secure
