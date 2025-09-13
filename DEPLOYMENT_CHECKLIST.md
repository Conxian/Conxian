# Conxian Deployment Checklist

## Pre-Deployment Checks
- [ ] All contracts pass `clarinet check`
- [ ] All tests pass `clarinet test`
- [ ] Version numbers are updated in all contracts
- [ ] All dependencies are properly specified
- [ ] Access control roles are properly configured

## Testnet Deployment
1. Deploy Core Traits
   - [ ] access-control-trait
   - [ ] sip-010-trait
   - [ ] ft-mintable-trait
   - [ ] strategy-trait
   - [ ] pool-trait
   - [ ] vault-trait

2. Deploy Tokens
   - [ ] cxd-token
   - [ ] cxvg-token
   - [ ] cxtr-token
   - [ ] cxlp-token
   - [ ] cxs-token

3. Deploy DEX Core
   - [ ] dex-factory
   - [ ] dex-pool
   - [ ] dex-router
   - [ ] oracle

4. Deploy Lending & Yield
   - [ ] lending-protocol-governance
   - [ ] loan-liquidation-manager
   - [ ] yield-distribution-engine

5. Deploy Dimensional Module
   - [ ] dim-registry
   - [ ] dim-metrics
   - [ ] concentrated-liquidity-pool

## Mainnet Deployment
1. Verify all testnet deployments
2. Update contract addresses in configuration
3. Repeat deployment steps from testnet
4. Verify all contract interactions

## Manual Deployment (Fallback)
1. Install stacks-cli: `npm install @stacks/cli`
2. Deploy a contract:
   ```powershell
   npx @stacks/cli deploy_contract ./path/to/contract.clar -t -n testnet -k $env:TESTNET_DEPLOYER_KEY
   ```
3. Repeat for all contracts in dependency order

## Post-Deployment
- [ ] Verify all contract interactions
- [ ] Test emergency shutdown procedures
- [ ] Document all contract addresses
- [ ] Update deployment documentation

## Verification Steps
- [ ] Verify contract source code matches deployed bytecode
- [ ] Verify all access controls are properly set
- [ ] Verify all pause/unpause functionality works
- [ ] Test upgrade paths if applicable

## Emergency Procedures
- [ ] Document emergency contacts
- [ ] Prepare emergency transaction templates
- [ ] Test emergency response procedures
