import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

const CONTRACT_NAME = 'dimensional-oracle';
const MOCK_ORACLE = 'mock-oracle';
const CIRCUIT_BREAKER = 'circuit-breaker';
const MONITORING = 'system-monitor';

// Helper function to get contract address
const contractPrincipal = (deployer: Account, contractName: string) =>
  `${deployer.address}.${contractName}`;

// Test token address for testing
const TEST_TOKEN = 'ST3J2GVMMM2R07ZFBJDWTYEYAR8FZH5WKDTFJ9AHA';

Clarinet.test({
  name: 'Oracle system integration test',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const oracle = contractPrincipal(deployer, CONTRACT_NAME);
    const mockOracle = contractPrincipal(deployer, MOCK_ORACLE);
    const circuitBreaker = contractPrincipal(deployer, CIRCUIT_BREAKER);
    const monitoring = contractPrincipal(deployer, MONITORING);

    // 1. Initialize mock oracle with a test price
    let block = chain.mineBlock([
      Tx.contractCall(
        MOCK_ORACLE,
        'set-mock-price',
        [types.principal(TEST_TOKEN), types.uint(1_00000000), types.uint(500)], // $100 with 8 decimals, 5% deviation
        deployer.address
      ),
    ]);
    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 2);
    block.receipts[0].result.expectOk().expectBool(true);

    // 2. Test getting price from mock oracle
    block = chain.mineBlock([
      Tx.contractCall(
        MOCK_ORACLE,
        'get-price',
        [types.principal(TEST_TOKEN)],
        deployer.address
      ),
    ]);
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectUint(1_00000000);

    // 3. Test circuit breaker with successful operation
    block = chain.mineBlock([
      Tx.contractCall(
        CIRCUIT_BREAKER,
        'record-success',
        [types.ascii('oracle-update')],
        deployer.address
      ),
    ]);
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);

    // 4. Test monitoring system
    block = chain.mineBlock([
      Tx.contractCall(
        MONITORING,
        'log-event',
        [
          types.ascii('oracle'),
          types.ascii('price-update'),
          types.uint(1), // INFO
          types.ascii('Price updated for token'),
          types.some(types.tuple({
            'token': types.principal(TEST_TOKEN),
            'price': types.uint(1_00000000)
          }))
        ],
        deployer.address
      ),
    ]);
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);

    // 5. Verify the event was logged
    block = chain.mineBlock([
      Tx.contractCall(
        MONITORING,
        'get-events',
        [types.ascii('oracle'), types.uint(10), types.uint(0)],
        deployer.address
      ),
    ]);
    assertEquals(block.receipts.length, 1);
    const events = block.receipts[0].result.expectOk().expectList();
    assertEquals(events.length, 1);
    events[0].expectTuple()['event-type'].expectAscii('price-update');
  },
});

Clarinet.test({
  name: 'Circuit breaker failure scenario',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const circuitBreaker = contractPrincipal(deployer, CIRCUIT_BREAKER);

    // Record enough failures to trip the circuit
    for (let i = 0; i < 10; i++) {
      chain.mineBlock([
        Tx.contractCall(
          CIRCUIT_BREAKER,
          'record-failure',
          [types.ascii('oracle-update')],
          deployer.address
        ),
      ]);
    }

    // Check circuit state
    const block = chain.mineBlock([
      Tx.contractCall(
        CIRCUIT_BREAKER,
        'get-circuit-state',
        [types.ascii('oracle-update')],
        deployer.address
      ),
    ]);
    
    const state = block.receipts[0].result.expectOk().expectTuple();
    state['state'].expectUint(1); // OPEN state
    const failureRate = state['failure-rate'].expectUint();
    if (failureRate < 9000) { // Expecting ~100% failure rate
      throw new Error(`Unexpected failure rate: ${failureRate}`);
    }
  },
});
