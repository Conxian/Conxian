import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.190.0/testing/asserts.ts';

Clarinet.test({
  name: 'DEX Factory - Create Pool',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Deploy test tokens
    const tokenA = chain.deployContract('test-token-a', 'tests/mocks/test-token-a.clar');
    const tokenB = chain.deployContract('test-token-b', 'tests/mocks/test-token-b.clar');
    
    // Initialize tokens
    let block = chain.mineBlock([
      Tx.contractCall('test-token-a', 'initialize', [
        types.principal(deployer.address),
        types.uint(1000000)
      ], deployer.address),
      Tx.contractCall('test-token-b', 'initialize', [
        types.principal(deployer.address),
        types.uint(1000000)
      ], deployer.address)
    ]);
    assertEquals(block.receipts.length, 2);
    assertEquals(block.receipts[0].result, '(ok true)');
    assertEquals(block.receipts[1].result, '(ok true)');
    
    // Deploy DEX factory
    const factory = chain.deployContract('dex-factory', 'contracts/dex/dex-factory.clar');
    
    // Set up access control
    block = chain.mineBlock([
      Tx.contractCall('dex-factory', 'set-access-control-contract', [
        types.principal(deployer.address)
      ], deployer.address)
    ]);
    assertEquals(block.receipts.length, 1);
    assertEquals(block.receipts[0].result, '(ok true)');
    
    // Test creating a pool
    block = chain.mineBlock([
      Tx.contractCall('dex-factory', 'create-pool', [
        types.principal(tokenA),
        types.principal(tokenB),
        types.uint(30) // 0.3% fee
      ], deployer.address)
    ]);
    
    // Check the result
    const receipt = block.receipts[0];
    assertEquals(receipt.result.includes('ok'), true, `Expected successful pool creation, got ${receipt.result}`);
    
    // Verify the pool was created in the factory
    const poolAddress = chain.callReadOnlyFn(
      'dex-factory',
      'get-pool',
      [
        types.principal(tokenA),
        types.principal(tokenB)
      ],
      deployer.address
    );
    
    assertEquals(poolAddress.result.includes('some'), true, 'Pool should be created');
  }
});

Clarinet.test({
  name: 'DEX Factory - Create Pool with Invalid Tokens',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    // Deploy test tokens
    const tokenA = chain.deployContract('test-token-a', 'tests/mocks/test-token-a.clar');
    
    // Initialize token
    let block = chain.mineBlock([
      Tx.contractCall('test-token-a', 'initialize', [
        types.principal(deployer.address),
        types.uint(1000000)
      ], deployer.address)
    ]);
    
    // Deploy DEX factory
    const factory = chain.deployContract('dex-factory', 'contracts/dex/dex-factory.clar');
    
    // Set up access control
    block = chain.mineBlock([
      Tx.contractCall('dex-factory', 'set-access-control-contract', [
        types.principal(deployer.address)
      ], deployer.address)
    ]);
    
    // Try to create pool with same tokens (should fail)
    block = chain.mineBlock([
      Tx.contractCall('dex-factory', 'create-pool', [
        types.principal(tokenA),
        types.principal(tokenA), // Same token as both A and B
        types.uint(30)
      ], deployer.address)
    ]);
    
    // Should fail with ERR_INVALID_TOKENS (2002)
    assertEquals(block.receipts[0].result, '(err u2002)');
  }
});

Clarinet.test({
  name: 'DEX Factory - Create Pool with Invalid Fee',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    // Deploy test tokens
    const tokenA = chain.deployContract('test-token-a', 'tests/mocks/test-token-a.clar');
    const tokenB = chain.deployContract('test-token-b', 'tests/mocks/test-token-b.clar');
    
    // Initialize tokens
    let block = chain.mineBlock([
      Tx.contractCall('test-token-a', 'initialize', [
        types.principal(deployer.address),
        types.uint(1000000)
      ], deployer.address),
      Tx.contractCall('test-token-b', 'initialize', [
        types.principal(deployer.address),
        types.uint(1000000)
      ], deployer.address)
    ]);
    
    // Deploy DEX factory
    const factory = chain.deployContract('dex-factory', 'contracts/dex/dex-factory.clar');
    
    // Set up access control
    block = chain.mineBlock([
      Tx.contractCall('dex-factory', 'set-access-control-contract', [
        types.principal(deployer.address)
      ], deployer.address)
    ]);
    
    // Try to create pool with invalid fee (should fail)
    block = chain.mineBlock([
      Tx.contractCall('dex-factory', 'create-pool', [
        types.principal(tokenA),
        types.principal(tokenB),
        types.uint(10001) // Invalid fee > 100%
      ], deployer.address)
    ]);
    
    // Should fail with ERR_INVALID_FEE (2004)
    assertEquals(block.receipts[0].result, '(err u2004)');
  }
});
