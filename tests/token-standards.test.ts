import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

// Test all tokens for SIP-010 compliance
Clarinet.test({
    name: 'Ensure all tokens implement SIP-010 standard',
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // List of all token contracts to test
        const tokens = [
            { name: 'cxd-token', symbol: 'CXD' },
            { name: 'cxvg-token', symbol: 'CXVG' },
            { name: 'cxtr-token', symbol: 'CXTR' },
            { name: 'cxlp-token', symbol: 'CXLP' },
        ];

        for (const token of tokens) {
            // Test get-name
            let call = await chain.callReadOnlyFn(
                token.name,
                'get-name',
                [],
                deployer.address
            );
            assertEquals(call.result.expectSome().expectUtf8().includes(token.symbol), true, 
                `${token.name}: get-name failed`);

            // Test get-symbol
            call = await chain.callReadOnlyFn(
                token.name,
                'get-symbol',
                [],
                deployer.address
            );
            assertEquals(call.result.expectSome().expectAscii(), token.symbol, 
                `${token.name}: get-symbol failed`);

            // Test get-decimals
            call = await chain.callReadOnlyFn(
                token.name,
                'get-decimals',
                [],
                deployer.address
            );
            call.result.expectUint(6); // All our tokens use 6 decimals
            
            // Test get-balof
            call = await chain.callReadOnlyFn(
                token.name,
                'get-balance',
                [types.principal(wallet1.address)],
                deployer.address
            );
            call.result.expectUint(0);
            
            console.log(`✓ ${token.name} passed SIP-010 compliance tests`);
        }
    },
});

// Test token-specific functionality
Clarinet.test({
    name: 'Test token minting and transfers',
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Test each token
        const tokens = ['cxd-token', 'cxvg-token', 'cxtr-token', 'cxlp-token'];
        
        for (const token of tokens) {
            // Mint tokens to wallet1
            const mintBlock = chain.mineBlock([
                Tx.contractCall(
                    token,
                    'mint',
                    [types.uint(1000000), types.principal(wallet1.address)],
                    deployer.address
                )
            ]);
            
            // Verify mint was successful
            assertEquals(mintBlock.receipts[0].result.expectOk(), 'true');
            
            // Check balance
            let call = await chain.callReadOnlyFn(
                token,
                'get-balance',
                [types.principal(wallet1.address)],
                deployer.address
            );
            call.result.expectUint(1000000);
            
            // Test transfer
            const transferBlock = chain.mineBlock([
                Tx.contractCall(
                    token,
                    'transfer',
                    [
                        types.uint(500000),
                        types.principal(wallet1.address),
                        types.principal(wallet2.address),
                        types.none()
                    ],
                    wallet1.address
                )
            ]);
            
            // Verify transfer was successful
            assertEquals(transferBlock.receipts[0].result.expectOk(), 'true');
            
            // Check balances after transfer
            call = await chain.callReadOnlyFn(
                token,
                'get-balance',
                [types.principal(wallet1.address)],
                deployder.address
            );
            call.result.expectUint(500000);
            
            call = await chain.callReadOnlyFn(
                token,
                'get-balance',
                [types.principal(wallet2.address)],
                deployer.address
            );
            call.result.expectUint(500000);
            
            console.log(`✓ ${token} passed minting and transfer tests`);
        }
    },
});

// Test token-specific features
Clarinet.test({
    name: 'Test token-specific features',
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Test CXD token features
        let call = await chain.callReadOnlyFn(
            'cxd-token',
            'get-total-supply',
            [],
            deployer.address
        );
        call.result.expectUint(0);
        
        // Test CXLP token migration features
        call = await chain.callReadOnlyFn(
            'cxlp-token',
            'get-migration-status',
            [],
            deployer.address
        );
        // Add assertions based on expected migration status
        
        console.log('✓ Token-specific features tested');
    },
});
