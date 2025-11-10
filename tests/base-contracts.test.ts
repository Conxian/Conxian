import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v0.31.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// Helper function to get error name from code
function getErrorName(code: number): string {
  const errors: { [key: number]: string } = {
    1001: 'ERR_NOT_OWNER',
    1003: 'ERR_PAUSED',
    1004: 'ERR_INVALID_INPUT',
    1100: 'ERR_UNAUTHORIZED',
  };
  return errors[code] || `UNKNOWN_ERROR_${code}`;
}

Clarinet.test({
  name: "Ownable - Basic ownership transfer",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Test initial owner is deployer
    let call = await chain.callReadOnlyFn(
      'ownable',
      'get-owner',
      [],
      deployer.address
    );
    assertEquals(call.result, `(ok ${deployer.address})`);
    
    // Transfer ownership
    let block = chain.mineBlock([
      Tx.contractCall(
        'ownable',
        'transfer-ownership',
        [`'${wallet1.address}`],
        deployer.address
      )
    ]);
    
    // Should have a pending owner now
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Claim ownership
    block = chain.mineBlock([
      Tx.contractCall(
        'ownable',
        'claim-ownership',
        [],
        wallet1.address
      )
    ]);
    
    // Verify new owner
    call = await chain.callReadOnlyFn(
      'ownable',
      'get-owner',
      [],
      wallet1.address
    );
    assertEquals(call.result, `(ok ${wallet1.address})`);
  }
});

Clarinet.test({
  name: "Pausable - Pause/Unpause functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    // Pause the contract
    let block = chain.mineBlock([
      Tx.contractCall('pausable', 'pause', [], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Check if paused
    let call = await chain.callReadOnlyFn(
      'pausable',
      'is-paused',
      [],
      deployer.address
    );
    call.result.expectOk().expectBool(true);
    
    // Unpause
    block = chain.mineBlock([
      Tx.contractCall('pausable', 'unpause', [], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Verify unpaused
    call = await chain.callReadOnlyFn(
      'pausable',
      'is-paused',
      [],
      deployer.address
    );
    call.result.expectOk().expectBool(false);
  }
});

Clarinet.test({
  name: "Roles - Role management",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const ROLE_ADMIN = 1;
    
    // Grant admin role
    let block = chain.mineBlock([
      Tx.contractCall(
        'roles',
        'grant-role',
        [`'${wallet1.address}`, types.uint(ROLE_ADMIN)],
        deployer.address
      )
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Check role
    let call = await chain.callReadOnlyFn(
      'roles',
      'has-role',
      [`'${wallet1.address}`, types.uint(ROLE_ADMIN)],
      deployer.address
    );
    call.result.expectOk().expectBool(true);
    
    // Revoke role
    block = chain.mineBlock([
      Tx.contractCall(
        'roles',
        'revoke-role',
        [`'${wallet1.address}`, types.uint(ROLE_ADMIN)],
        deployer.address
      )
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Verify role revoked
    call = await chain.callReadOnlyFn(
      'roles',
      'has-role',
      [`'${wallet1.address}`, types.uint(ROLE_ADMIN)],
      deployer.address
    );
    call.result.expectOk().expectBool(false);
  }
});

// Add more test cases for error conditions and edge cases
Clarinet.test({
  name: "Ownable - Unauthorized transfer",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    // Wallet 1 tries to transfer ownership (not the owner)
    let block = chain.mineBlock([
      Tx.contractCall(
        'ownable',
        'transfer-ownership',
        [`'${wallet2.address}`],
        wallet1.address
      )
    ]);
    
    // Should fail with ERR_NOT_OWNER (1001)
    block.receipts[0].result.expectErr().expectUint(1001);
  }
});
