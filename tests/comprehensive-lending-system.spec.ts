import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
  name: 'Ensure that supply works',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Initialize contract
    const block = chain.mineBlock([
      Tx.contractCall('comprehensive-lending-system', 'init', [], deployer.address)
    ]);
    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 2);
    
    // Test supply function
    const supplyCall = Tx.contractCall(
      'comprehensive-lending-system', 
      'supply', 
      [types.principal('ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.token'), types.uint(1000)], 
      wallet1.address
    );
    
    const supplyBlock = chain.mineBlock([supplyCall]);
    supplyBlock.receipts[0].result.expectOk().expectUint(1000);
  }
});
