import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "Enhanced Yield Strategy - Basic functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        // Setup
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        const tokenContract = `${deployer.address}.test-token`;
        const strategyContract = `${deployer.address}.enhanced-yield-strategy`;
        
        // Initialize test token
        chain.mineBlock([
            Tx.contractCall('test-token', 'mint', [types.uint(1000000), types.principal(user1.address)], deployer.address)
        ]);
        
        // Test deposit
        const depositAmount = 1000;
        let block = chain.mineBlock([
            Tx.contractCall(tokenContract, 'approve', [
                types.principal(strategyContract),
                types.uint(depositAmount)
            ], user1.address),
            Tx.contractCall(strategyContract, 'deposit', [
                types.principal(tokenContract),
                types.uint(depositAmount)
            ], user1.address)
        ]);
        assertEquals(block.receipts.length, 2);
        block.receipts[1].result.expectOk().expectUint(depositAmount);
        
        // Test get-tvl
        const tvl = chain.callReadOnlyFn(strategyContract, 'get-tvl', [], user1.address);
        tvl.result.expectOk().expectUint(depositAmount);
        
        // Test harvest (simulate growth)
        chain.mineEmptyBlock(10); // Advance blocks to simulate time
        block = chain.mineBlock([
            Tx.contractCall(strategyContract, 'harvest', [], deployer.address)
        ]);
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Test withdraw
        const withdrawAmount = 500;
        block = chain.mineBlock([
            Tx.contractCall(strategyContract, 'withdraw', [
                types.principal(tokenContract),
                types.uint(withdrawAmount)
            ], user1.address)
        ]);
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk().expectUint(withdrawAmount);
        
        // Test admin functions
        block = chain.mineBlock([
            Tx.contractCall(strategyContract, 'pause', [], deployer.address),
            Tx.contractCall(strategyContract, 'set-performance-fee', [types.uint(1500)], deployer.address)
        ]);
        block.receipts[0].result.expectOk().expectBool(true);
        block.receipts[1].result.expectOk().expectBool(true);
    }
});

Clarinet.test({
    name: "Enhanced Yield Strategy - Security checks",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        // Setup
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        const user2 = accounts.get('wallet_2')!;
        const tokenContract = `${deployer.address}.test-token`;
        const strategyContract = `${deployer.address}.enhanced-yield-strategy`;
        
        // Test: Non-admin can't pause
        let block = chain.mineBlock([
            Tx.contractCall(strategyContract, 'pause', [], user1.address)
        ]);
        block.receipts[0].result.expectErr().expectUint(1001); // ERR_UNAUTHORIZED
        
        // Test: Can't deposit when paused
        chain.mineBlock([
            Tx.contractCall(strategyContract, 'pause', [], deployer.address)
        ]);
        block = chain.mineBlock([
            Tx.contractCall(strategyContract, 'deposit', [
                types.principal(tokenContract),
                types.uint(1000)
            ], user1.address)
        ]);
        block.receipts[0].result.expectErr().expectUint(1002); // ERR_PAUSED
    }
});
