
import { deployContract, getDeployer } from '@stacks/clarinet-sdk';

async function main() {
  const deployer = getDeployer();
  console.log(`Deploying with ${deployer.address}`);

  // Core Traits
  await deployContract('traits/core-traits.clar', 'core-traits');
  await deployContract('traits/defi-traits.clar', 'defi-traits');
  await deployContract('traits/sip-standards.clar', 'sip-standards');

  // Security
  await deployContract('security/mev-protector.clar', 'mev-protector');

  // DEX Core
  await deployContract('dex/concentrated-liquidity-pool.clar', 'concentrated-liquidity-pool');
  await deployContract('dex/dex-factory-v2.clar', 'dex-factory-v2');
  await deployContract('router/multi-hop-router-v3.clar', 'multi-hop-router-v3');
  await deployContract('dex/oracle-aggregator-v2.clar', 'oracle-aggregator-v2');

  // Lending
  await deployContract('lending/interest-rate-model.clar', 'interest-rate-model');
  await deployContract('lending/comprehensive-lending-system.clar', 'comprehensive-lending-system');

  // Enterprise & Yield
  await deployContract('enterprise/enterprise-api.clar', 'enterprise-api');
  await deployContract('yield/yield-optimizer.clar', 'yield-optimizer');

  console.log('Deployment complete.');
}

main().catch(console.error);
