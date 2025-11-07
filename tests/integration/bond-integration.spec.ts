import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.190.0/testing/asserts.ts';

Clarinet.test({
  name: "Bond Factory: Create bond",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const issuer = accounts.get('wallet_1')!;
    
    // Set bond token template
    let block = chain.mineBlock([
      Tx.contractCall('bond-factory', 'set-bond-token-code', [
        types.utf8('(define-constant BOND_ISSUER \'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ)')
      ], deployer.address)
    ]);
    assertEquals(block.receipts.length, 1);

    // Create bond
    block = chain.mineBlock([
      Tx.contractCall('bond-factory', 'create-bond', [
        types.uint(100000000),  // 1.0 token
        types.uint(500),        // 5% coupon
        types.uint(1000),       // 1000 blocks
        types.uint(120000000),  // 1.2 collateral
        types.principal(`${deployer.address}.mock-token`),
        types.bool(false),      // Not callable
        types.uint(0)           // No premium
      ], issuer.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectTuple();
  }
});

Clarinet.test({
  name: "DEX Router: Register bond market",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    // Register bond market
    const block = chain.mineBlock([
      Tx.contractCall('dex-router', 'register-bond-market', [
        types.principal('STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.bond-token'),
        types.uint(1000000),  // min trade
        types.uint(1000000000), // max trade
        types.uint(30)        // 0.3% fee
      ], deployer.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
  }
});
