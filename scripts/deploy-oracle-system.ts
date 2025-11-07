import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';

// Contract names
const CONTRACTS = {
  ORACLE: 'dimensional-oracle',
  MOCK_ORACLE: 'mock-oracle',
  CIRCUIT_BREAKER: 'circuit-breaker',
  MONITORING: 'system-monitor'
};

// Helper function to get contract address
const contractPrincipal = (deployer: Account, contractName: string) =>
  `${deployer.address}.${contractName}`;

// Default configuration
const DEFAULT_CONFIG = {
  // Oracle configuration
  ORACLE_ADMIN: 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ',
  
  // Circuit breaker configuration
  FAILURE_THRESHOLD: 300, // 3% in basis points
  RESET_TIMEOUT: 100,     // ~16 hours in blocks
  
  // Monitoring configuration
  ALERT_THRESHOLDS: {
    'oracle': {
      'price-deviation': 500,  // 5% deviation
      'stale-data': 1440       // ~1 day in blocks
    },
    'vault': {
      'withdrawal-limit': 1000000000000,  // 1M STX
      'health-factor': 11000              // 110% in basis points
    }
  }
};

// Deploy the Oracle system
async function deployOracleSystem(chain: Chain, accounts: Map<string, Account>, config = DEFAULT_CONFIG) {
  const deployer = accounts.get('deployer')!;
  const contracts = {} as Record<string, string>;
  
  // Deploy Oracle
  console.log('Deploying Oracle...');
  let block = chain.mineBlock([
    Tx.contractPublish(
      CONTRACTS.ORACLE,
      'contracts/oracle/dimensional-oracle.clar',
      config.ORACLE_ADMIN
    ),
  ]);
  
  if (block.receipts[0].result.expectErr()) {
    console.error('Failed to deploy Oracle:', block.receipts[0].result);
    throw new Error('Failed to deploy Oracle');
  }
  
  contracts.oracle = contractPrincipal(deployer, CONTRACTS.ORACLE);
  console.log(`Oracle deployed at: ${contracts.oracle}`);
  
  // Deploy Circuit Breaker
  console.log('\nDeploying Circuit Breaker...');
  block = chain.mineBlock([
    Tx.contractPublish(
      CONTRACTS.CIRCUIT_BREAKER,
      'contracts/risk/circuit-breaker.clar',
      config.ORACLE_ADMIN
    ),
  ]);
  
  if (block.receipts[0].result.expectErr()) {
    console.error('Failed to deploy Circuit Breaker:', block.receipts[0].result);
    throw new Error('Failed to deploy Circuit Breaker');
  }
  
  contracts.circuitBreaker = contractPrincipal(deployer, CONTRACTS.CIRCUIT_BREAKER);
  console.log(`Circuit Breaker deployed at: ${contracts.circuitBreaker}`);
  
  // Configure Circuit Breaker
  console.log('\nConfiguring Circuit Breaker...');
  block = chain.mineBlock([
    Tx.contractCall(
      CONTRACTS.CIRCUIT_BREAKER,
      'set-failure-threshold',
      [types.ascii('oracle-update'), types.uint(config.FAILURE_THRESHOLD)],
      deployer.address
    ),
    Tx.contractCall(
      CONTRACTS.CIRCUIT_BREAKER,
      'set-reset-timeout',
      [types.ascii('oracle-update'), types.uint(config.RESET_TIMEOUT)],
      deployer.address
    )
  ]);
  
  if (block.receipts[0].result.expectErr() || block.receipts[1].result.expectErr()) {
    console.error('Failed to configure Circuit Breaker:', block.receipts.map(r => r.result));
    throw new Error('Failed to configure Circuit Breaker');
  }
  
  // Deploy Monitoring
  console.log('\nDeploying Monitoring System...');
  block = chain.mineBlock([
    Tx.contractPublish(
      CONTRACTS.MONITORING,
      'contracts/monitoring/system-monitor.clar',
      config.ORACLE_ADMIN
    ),
  ]);
  
  if (block.receipts[0].result.expectErr()) {
    console.error('Failed to deploy Monitoring System:', block.receipts[0].result);
    throw new Error('Failed to deploy Monitoring System');
  }
  
  contracts.monitoring = contractPrincipal(deployer, CONTRACTS.MONITORING);
  console.log(`Monitoring System deployed at: ${contracts.monitoring}`);
  
  // Configure Monitoring
  console.log('\nConfiguring Monitoring System...');
  const alertCalls = [];
  
  for (const [component, thresholds] of Object.entries(config.ALERT_THRESHOLDS)) {
    for (const [alertType, threshold] of Object.entries(thresholds)) {
      alertCalls.push(
        Tx.contractCall(
          CONTRACTS.MONITORING,
          'set-alert-threshold',
          [
            types.ascii(component),
            types.ascii(alertType),
            types.uint(threshold as number)
          ],
          deployer.address
        )
      );
    }
  }
  
  // Execute alert threshold configurations in batches to avoid block size limits
  const BATCH_SIZE = 5;
  for (let i = 0; i < alertCalls.length; i += BATCH_SIZE) {
    const batch = alertCalls.slice(i, i + BATCH_SIZE);
    block = chain.mineBlock(batch);
    
    const failed = block.receipts.some(r => r.result.expectErr());
    if (failed) {
      console.warn('Some alert thresholds failed to configure:', block.receipts.map(r => r.result));
    }
  }
  
  // Deploy Mock Oracle (for testing)
  console.log('\nDeploying Mock Oracle (for testing)...');
  block = chain.mineBlock([
    Tx.contractPublish(
      CONTRACTS.MOCK_ORACLE,
      'contracts/mocks/mock-oracle.clar',
      config.ORACLE_ADMIN
    ),
  ]);
  
  if (block.receipts[0].result.expectErr()) {
    console.error('Failed to deploy Mock Oracle:', block.receipts[0].result);
    throw new Error('Failed to deploy Mock Oracle');
  }
  
  contracts.mockOracle = contractPrincipal(deployer, CONTRACTS.MOCK_ORACLE);
  console.log(`Mock Oracle deployed at: ${contracts.mockOracle}`);
  
  console.log('\n=== Oracle System Deployment Complete ===');
  console.log('Contracts deployed:');
  console.log(JSON.stringify(contracts, null, 2));
  
  return contracts;
}

// Main deployment function
async function main() {
  const clarinet = new Clarinet();
  const accounts = new Map();
  
  // Initialize accounts
  for (let i = 0; i < 10; i++) {
    accounts.set(`wallet_${i}`, {
      address: `ST3J2GVMMM2R07ZFBJDWTYEYAR8FZH5WK${i}${i}${i}${i}${i}`,
      balance: 1_000_000_000_000n
    });
  }
  
  // Add deployer account
  accounts.set('deployer', {
    address: DEFAULT_CONFIG.ORACLE_ADMIN,
    balance: 1_000_000_000_000n
  });
  
  // Create a test chain
  const chain = new Chain(accounts);
  
  try {
    await deployOracleSystem(chain, accounts);
    console.log('\nDeployment successful!');
  } catch (error) {
    console.error('\nDeployment failed:', error);
    Deno.exit(1);
  }
}

// Run the deployment
main().catch(console.error);
