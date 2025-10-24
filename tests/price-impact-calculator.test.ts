import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "price-impact-calculator: update-reserves succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;

        let block = chain.mineBlock([
            Tx.contractCall("price-impact-calculator", "update-reserves", [
                types.uint(0),
                types.uint(100000),
                types.uint(100000)
            ], deployer.address)
        ]);
        assertEquals(block.receipts[0].result, types.ok(types.bool(true)));
    },
});

Clarinet.test({
    name: "price-impact-calculator: update-reserves fails if not authorized",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let wallet_1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("price-impact-calculator", "update-reserves", [
                types.uint(0),
                types.uint(100000),
                types.uint(100000)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.err(types.uint(1000)));
    },
});

Clarinet.test({
    name: "price-impact-calculator: calculate-impact-buy-x succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        // Update reserves first
        chain.mineBlock([
            Tx.contractCall("price-impact-calculator", "update-reserves", [
                types.uint(0),
                types.uint(100000),
                types.uint(100000)
            ], deployer.address)
        ]);

        let block = chain.mineBlock([
            Tx.contractCall("price-impact-calculator", "calculate-impact-buy-x", [
                types.uint(0),
                types.uint(1000)
            ], wallet_1.address)
        ]);
        // Expected impact for 1000 units from 100000 reserve: (100000 / (100000 - 1000)) - 1 = 100000/99000 - 1 = 1.0101 - 1 = 0.0101
        // 0.0101 * 10000 = 101 bps (approx)
        assertEquals(block.receipts[0].result, types.ok(types.uint(101)));
    },
});

Clarinet.test({
    name: "price-impact-calculator: calculate-impact-buy-x fails for invalid amount",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        // Update reserves first
        chain.mineBlock([
            Tx.contractCall("price-impact-calculator", "update-reserves", [
                types.uint(0),
                types.uint(100000),
                types.uint(100000)
            ], deployer.address)
        ]);

        let block = chain.mineBlock([
            Tx.contractCall("price-impact-calculator", "calculate-impact-buy-x", [
                types.uint(0),
                types.uint(0)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.err(types.uint(2001)));
    },
});

Clarinet.test({
    name: "price-impact-calculator: calculate-impact-buy-x fails for insufficient liquidity",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        // Update reserves first
        chain.mineBlock([
            Tx.contractCall("price-impact-calculator", "update-reserves", [
                types.uint(0),
                types.uint(1000),
                types.uint(1000)
            ], deployer.address)
        ]);

        let block = chain.mineBlock([
            Tx.contractCall("price-impact-calculator", "calculate-impact-buy-x", [
                types.uint(0),
                types.uint(1500) // Try to buy more than available
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.err(types.uint(2002)));
    },
});