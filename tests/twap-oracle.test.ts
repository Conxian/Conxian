import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "twap-oracle: update-twap success",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get('deployer')!;
        let wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall(
                'twap-oracle',
                'update-twap',
                [
                    types.principal(wallet1.address),
                    types.uint(3600),
                    types.uint(1000)
                ],
                deployer.address
            ),
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.bool(true));
        assertEquals(block.receipts[0].events[0].data.event, "twap-updated");

        let twap = chain.callReadOnlyFn(
            'twap-oracle',
            'get-twap',
            [
                types.principal(wallet1.address),
                types.uint(3600)
            ],
            deployer.address
        );
        assertEquals(twap.result.expectOk(), types.uint(1000));
    },
});

Clarinet.test({
    name: "twap-oracle: update-twap unauthorized failure",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall(
                'twap-oracle',
                'update-twap',
                [
                    types.principal(wallet1.address),
                    types.uint(3600),
                    types.uint(1000)
                ],
                wallet1.address
            ),
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectErr(), types.uint(6000));
    },
});

Clarinet.test({
    name: "twap-oracle: update-twap invalid period failure",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get('deployer')!;
        let wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall(
                'twap-oracle',
                'update-twap',
                [
                    types.principal(wallet1.address),
                    types.uint(0),
                    types.uint(1000)
                ],
                deployer.address
            ),
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectErr(), types.uint(6001));
    },
});

Clarinet.test({
    name: "twap-oracle: get-twap no data failure",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get('deployer')!;
        let wallet1 = accounts.get('wallet_1')!;

        let twap = chain.callReadOnlyFn(
            'twap-oracle',
            'get-twap',
            [
                types.principal(wallet1.address),
                types.uint(3600)
            ],
            deployer.address
        );
        assertEquals(twap.result.expectErr(), types.uint(6002));
    },
});

Clarinet.test({
    name: "twap-oracle: set-contract-owner success",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get('deployer')!;
        let wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall(
                'twap-oracle',
                'set-contract-owner',
                [types.principal(wallet1.address)],
                deployer.address
            ),
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.bool(true));

        let owner = chain.callReadOnlyFn(
            'twap-oracle',
            'get-contract-owner',
            [],
            deployer.address
        );
        assertEquals(owner.result.expectOk(), types.principal(wallet1.address));
    },
});

Clarinet.test({
    name: "twap-oracle: set-contract-owner unauthorized failure",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let wallet1 = accounts.get('wallet_1')!;
        let wallet2 = accounts.get('wallet_2')!;

        let block = chain.mineBlock([
            Tx.contractCall(
                'twap-oracle',
                'set-contract-owner',
                [types.principal(wallet2.address)],
                wallet1.address
            ),
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectErr(), types.uint(6000));
    },
});

Clarinet.test({
    name: "twap-oracle: set-governance-address success",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get('deployer')!;
        let wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall(
                'twap-oracle',
                'set-governance-address',
                [types.principal(wallet1.address)],
                deployer.address
            ),
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.bool(true));

        let governance = chain.callReadOnlyFn(
            'twap-oracle',
            'get-governance-address',
            [],
            deployer.address
        );
        assertEquals(governance.result.expectOk(), types.principal(wallet1.address));
    },
});

Clarinet.test({
    name: "twap-oracle: set-governance-address unauthorized failure",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let wallet1 = accounts.get('wallet_1')!;
        let wallet2 = accounts.get('wallet_2')!;

        let block = chain.mineBlock([
            Tx.contractCall(
                'twap-oracle',
                'set-governance-address',
                [types.principal(wallet2.address)],
                wallet1.address
            ),
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectErr(), types.uint(6000));
    },
});