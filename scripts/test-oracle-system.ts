import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

const CONTRACTS = {
  ORACLE: 'dimensional-oracle',
  MOCK_ORACLE: 'mock-oracle',
  CIRCUIT_BREAKER: 'circuit-breaker',
  MONITORING: 'system-monitor'
};

// Helper function to get contract address
const contractPrincipal = (deployer: Account, contractName: string) =>
  `${deployer.address}.${contractName}`;

// Test token address
const TEST_TOKEN = 'ST3J2GVMMM2R07ZFBJDWTYEYAR8FZH5WKDTFJ9AHA';

async function setupContracts(chain: Chain, accounts: Map<string, Account>) {
  const deployer = accounts.get('deployer')!;
  
  // Initialize mock oracle with a test price
  let block = chain.mineBlock([
    Tx.contractCall(
      CONTRACTS.MOCK_ORACLE,
      'set-mock-price',
      [types.principal(TEST_TOKEN), types.uint(1_00000000), types.uint(500)], // $100 with 8 decimals, 5% deviation
      deployer.address
    ),
  ]);
  block.receipts[0].result.expectOk().expectBool(true);
  
  return {
    deployer,
    oracle: contractPrincipal(deployer, CONTRACTS.ORACLE),
    mockOracle: contractPrincipal(deployer, CONTRACTS.MOCK_ORACLE),
    circuitBreaker: contractPrincipal(deployer, CONTRACTS.CIRCUIT_BREAKER),
    monitoring: contractPrincipal(deployer, CONTRACTS.MONITORING)
  };
}

// Test Oracle Functionality
async function testOracle(chain: Chain, accounts: Map<string, Account>) {
  const { mockOracle } = await setupContracts(chain, accounts);
  const caller = accounts.get('deployer')!;
  
  // Test getting price
  let block = chain.mineBlock([
    Tx.contractCall(
      CONTRACTS.MOCK_ORACLE,
      'get-price',
      [types.principal(TEST_TOKEN)],
      caller.address
    ),
  ]);
  
  const price = block.receipts[0].result.expectOk();
  console.log(`Price of test token: ${price}`);
  
  // Test updating price
  block = chain.mineBlock([
    Tx.contractCall(
      CONTRACTS.MOCK_ORACLE,
      'update-price',
      [types.principal(TEST_TOKEN), types.uint(1_05000000)],
      caller.address
    ),
  ]);
  
  block.receipts[0].result.expectOk().expectBool(true);
  
  // Verify price update
  block = chain.mineBlock([
    Tx.contractCall(
      CONTRACTS.MOCK_ORACLE,
      'get-price',
      [types.principal(TEST_TOKEN)],
      caller.address
    ),
  ]);
  
  const updatedPrice = block.receipts[0].result.expectOk();
  console.log(`Updated price: ${updatedPrice}`);
  assertEquals(updatedPrice, types.uint(1_05000000));
}

// Test Circuit Breaker
async function testCircuitBreaker(chain: Chain, accounts: Map<string, Account>) {
  const { circuitBreaker } = await setupContracts(chain, accounts);
  const caller = accounts.get('deployer')!;
  const operation = 'test-operation';
  
  // Record some successes and failures
  for (let i = 0; i < 5; i++) {
    chain.mineBlock([
      Tx.contractCall(
        CONTRACTS.CIRCUIT_BREAKER,
        'record-success',
        [types.ascii(operation)],
        caller.address
      ),
    ]);
  }
  
  // Record enough failures to trip the circuit
  for (let i = 0; i < 10; i++) {
    chain.mineBlock([
      Tx.contractCall(
        CONTRACTS.CIRCUIT_BREAKER,
        'record-failure',
        [types.ascii(operation)],
        caller.address
      ),
    ]);
  }
  
  // Check circuit state
  const block = chain.mineBlock([
    Tx.contractCall(
      CONTRACTS.CIRCUIT_BREAKER,
      'get-circuit-state',
      [types.ascii(operation)],
      caller.address
    ),
  ]);
  
  const state = block.receipts[0].result.expectOk().expectTuple();
  console.log(`Circuit state: ${JSON.stringify(state, null, 2)}`);
  state['state'].expectUint(1); // Should be OPEN
}

// Test Monitoring
async function testMonitoring(chain: Chain, accounts: Map<string, Account>) {
  const { monitoring } = await setupContracts(chain, accounts);
  const caller = accounts.get('deployer')!;
  const component = 'test-component';
  
  // Log some events
  for (let i = 0; i < 3; i++) {
    const block = chain.mineBlock([
      Tx.contractCall(
        CONTRACTS.MONITORING,
        'log-event',
        [
          types.ascii(component),
          types.ascii('test-event'),
          types.uint(1), // INFO
          types.ascii(`Test event ${i + 1}`),
          types.none()
        ],
        caller.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
  }
  
  // Get events
  const block = chain.mineBlock([
    Tx.contractCall(
      CONTRACTS.MONITORING,
      'get-events',
      [types.ascii(component), types.uint(10), types.uint(0)],
      caller.address
    ),
  ]);
  
  const events = block.receipts[0].result.expectOk().expectList();
  console.log(`Retrieved ${events.length} events`);
  assertEquals(events.length, 3);
  
  // Check health status
  const healthBlock = chain.mineBlock([
    Tx.contractCall(
      CONTRACTS.MONITORING,
      'get-health-status',
      [types.ascii(component)],
      caller.address
    ),
  ]);
  
  const health = healthBlock.receipts[0].result.expectOk().expectTuple();
  console.log(`Component health: ${JSON.stringify(health, null, 2)}`);
}

// Main test function
async function runTests() {
  const clarinet = new Clarinet();
  const accounts = new Map();
  
  // Initialize accounts
  for (let i = 0; i < 10; i++) {
    accounts.set(`wallet_${i}`, {
      address: `ST3J2GVMMM2R07ZFBJDWTYEYAR8FZH5WK${i}${i}${i}${i}${i}`,
      balance: 1_000_000_000_000n
    });
  }
  
  // Create a test chain
  const chain = new Chain(accounts);
  
  console.log('=== Testing Oracle ===');
  await testOracle(chain, accounts);
  
  console.log('\n=== Testing Circuit Breaker ===');
  await testCircuitBreaker(chain, accounts);
  
  console.log('\n=== Testing Monitoring ===');
  await testMonitoring(chain, accounts);
  
  console.log('\nAll tests completed successfully!');
}

// Run the tests
runTests().catch(console.error);
