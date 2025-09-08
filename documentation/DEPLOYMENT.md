# Conxian Deployment Strategy

## 🎯 Current Status: Production-Ready Testnet Deployment Workflow

**Last Updated**: September 08, 2025  
**Status**: Deployment workflow implemented in GitHub Actions with dry-run and live modes. Contracts compile (42) and deployment plan generation/verification pass.  
**Next Phase**: Execute live testnet deployment and system validation

### ✅ What’s Implemented

Testnet deployment orchestration using Clarinet and CI/CD:

- **Workflow**: `.github/workflows/deploy-testnet.yml`
- **Commands**: `clarinet deployments generate --testnet`, `clarinet deployments apply --testnet`, `clarinet deployments check --testnet`
- **Secrets Validation**: Ensures required secrets exist before live deployment
- **Config**: `settings/Testnet.toml`
- **Compilation**: `clarinet check` in CI

## 🚀 How to Deploy (GitHub Actions)

1. Ensure repository secrets are configured:
   - `TESTNET_DEPLOYER_KEY` (required)
   - `HIRO_API_KEY` (required)
   - `TESTNET_DEPLOYER_MNEMONIC` (required)
   - `TESTNET_WALLET1_MNEMONIC` (required)
   - `TESTNET_WALLET2_MNEMONIC` (required)
   - `MAINNET_DEPLOYER_KEY` (optional, for mainnet)

2. Trigger the workflow from CLI:

   ```bash
   # Dry run (no broadcast)
   gh workflow run deploy-testnet.yml --field dry_run=true

   # Live deployment (requires manual confirmation in workflow input)
   gh workflow run deploy-testnet.yml --field dry_run=false
   ```

3. Monitor the run in GitHub Actions and review the summary and verification steps.

## 🔄 Testnet Iterations (Post-Deploy)

### Priority 1: Critical Fixes

1. **Oracle Aggregator**: Authorization improvements (ready to deploy)
2. **Test Infrastructure**: Minor integration enhancements
3. **Monitoring**: Enhanced health checks

### Priority 2: Feature Enhancements

1. **Advanced Governance**: Enhanced time-weighted voting
2. **DEX Optimization**: Improved routing algorithms
3. **Analytics**: Enhanced enterprise monitoring

## 🚀 Mainnet Migration (Planned)

Mainnet deployment strategy based on testnet validation:

Deploy governance and monitoring:

1. **DAO**: dao (basic governance)
2. **Analytics**: analytics (metrics and events)
3. **Treasury**: treasury (fund management)

## Phase 4: Advanced Features

Deploy advanced governance and bounty system:

1. **DAO Governance**: dao-governance (full governance)
2. **Bounty System**: bounty-system (development incentives)

## Phase 5: Integration

Enable cross-contract calls after all contracts are deployed:

- Update contract principals in each contract
- Enable analytics hooks
- Enable governance hooks
- Enable treasury integrations

## Production Configuration

All contracts must be production-ready with:

- No placeholder code
- Proper error handling
- Complete functionality
- Security checks
- Event emission
