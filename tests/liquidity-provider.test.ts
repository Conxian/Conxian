import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "liquidity-provider: create-pool succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("liquidity-provider", "create-pool", [
                types.principal(deployer.address + ".token-x"),
                types.principal(deployer.address + ".token-y"),
                types.principal(deployer.address + ".lp-token"),
                types.uint(100)
            ], deployer.address)
        ]);
        assertEquals(block.receipts[0].result, types.ok(types.uint(0)));
    },
});

Clarinet.test({
    name: "liquidity-provider: create-pool fails if not authorized",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let wallet_1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("liquidity-provider", "create-pool", [
                types.principal(wallet_1.address + ".token-x"),
                types.principal(wallet_1.address + ".token-y"),
                types.principal(wallet_1.address + ".lp-token"),
                types.uint(100)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.err(types.uint(1000)));
    },
});

Clarinet.test({
    name: "liquidity-provider: add-liquidity succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        // Create a pool first
        chain.mineBlock([
            Tx.contractCall("liquidity-provider", "create-pool", [
                types.principal(deployer.address + ".token-x"),
                types.principal(deployer.address + ".token-y"),
                types.principal(deployer.address + ".lp-token"),
                types.uint(100)
            ], deployer.address)
        ]);

        // Mock token transfers (assuming tokens exist and can be transferred)
        // In a real test, you'd interact with actual fungible token contracts
        // For simplicity, we'll assume the transfers succeed here.

        let block = chain.mineBlock([
            Tx.contractCall("liquidity-provider", "add-liquidity", [
                types.uint(0),
                types.uint(1000),
                types.uint(1000)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.ok(types.uint(1000))); // Simplified LP token calculation

        let lpBalance = chain.callReadOnlyFn("liquidity-provider", "get-lp-balance", [
            types.uint(0),
            types.principal(wallet_1.address)
        ], deployer.address);
        assertEquals(lpBalance.result, types.uint(1000));
    },
});

Clarinet.test({
    name: "liquidity-provider: add-liquidity fails for invalid amount",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        // Create a pool first
        chain.mineBlock([
            Tx.contractCall("liquidity-provider", "create-pool", [
                types.principal(deployer.address + ".token-x"),
                types.principal(deployer.address + ".token-y"),
                types.principal(deployer.address + ".lp-token"),
                types.uint(100)
            ], deployer.address)
        ]);

        let block = chain.mineBlock([
            Tx.contractCall("liquidity-provider", "add-liquidity", [
                types.uint(0),
                types.uint(0),
                types.uint(1000)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.err(types.uint(1001)));
    },
});

Clarinet.test({
    name: "liquidity-provider: remove-liquidity succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        // Create a pool and add liquidity first
        chain.mineBlock([
            Tx.contractCall("liquidity-provider", "create-pool", [
                types.principal(deployer.address + ".token-x"),
                types.principal(deployer.address + ".token-y"),
                types.principal(deployer.address + ".lp-token"),
                types.uint(100)
            ], deployer.address)
        ]);
        chain.mineBlock([
            Tx.contractCall("liquidity-provider", "add-liquidity", [
                types.uint(0),
                types.uint(1000),
                types.uint(1000)
            ], wallet_1.address)
        ]);

        let block = chain.mineBlock([
            Tx.contractCall("liquidity-provider", "remove-liquidity", [
                types.uint(0),
                types.uint(500)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.ok(types.tuple({
            "amount-x": types.uint(250),
            "amount-y": types.uint(250)
        })));

        let lpBalance = chain.callReadOnlyFn("liquidity-provider", "get-lp-balance", [
            types.uint(0),
            types.principal(wallet_1.address)
        ], deployer.address);
        assertEquals(lpBalance.result, types.uint(500));
    },
});

Clarinet.test({
    name: "liquidity-provider: remove-liquidity fails for insufficient liquidity",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        // Create a pool and add some liquidity
        chain.mineBlock([
            Tx.contractCall("liquidity-provider", "create-pool", [
                types.principal(deployer.address + ".token-x"),
                types.principal(deployer.address + ".token-y"),
                types.principal(deployer.address + ".lp-token"),
                types.uint(100)
            ], deployer.address)
        ]);
        chain.mineBlock([
            Tx.contractCall("liquidity-provider", "add-liquidity", [
                types.uint(0),
                types.uint(1000),
                types.uint(1000)
            ], wallet_1.address)
        ]);

        let block = chain.mineBlock([
            Tx.contractCall("liquidity-provider", "remove-liquidity", [
                types.uint(0),
                types.uint(1500) // Try to remove more than available
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.err(types.uint(1004)));
    },
});

Clarinet.test({
    name: "liquidity-provider: set-contract-owner succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("liquidity-provider", "set-contract-owner", [
                types.principal(wallet_1.address)
            ], deployer.address)
        ]);
        assertEquals(block.receipts[0].result, types.ok(types.bool(true)));

        let owner = chain.callReadOnlyFn("liquidity-provider", "get-contract-owner", [], deployer.address);
        assertEquals(owner.result, types.ok(types.principal(wallet_1.address)));
    },
});

Clarinet.test({
    name: "liquidity-provider: set-contract-owner fails if not authorized",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let wallet_1 = accounts.get("wallet_1")!;
        let wallet_2 = accounts.get("wallet_2")!;

        let block = chain.mineBlock([
            Tx.contractCall("liquidity-provider", "set-contract-owner", [
                types.principal(wallet_2.address)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.err(types.uint(1000)));
    },
});

Clarinet.test({
    name: "liquidity-provider: set-governance-address succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("liquidity-provider", "set-governance-address", [
                types.principal(wallet_1.address)
            ], deployer.address)
        ]);
        assertEquals(block.receipts[0].result, types.ok(types.bool(true)));

        let governance = chain.callReadOnlyFn("liquidity-provider", "get-governance-address", [], deployer.address);
        assertEquals(governance.result, types.ok(types.principal(wallet_1.address)));
    },
});

Clarinet.test({
    name: "liquidity-provider: set-emergency-multisig succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("liquidity-provider", "set-emergency-multisig", [
                types.principal(wallet_1.address)
            ], deployer.address)
        ]);
        assertEquals(block.receipts[0].result, types.ok(types.bool(true)));

        let multisig = chain.callReadOnlyFn("liquidity-provider", "get-emergency-multisig", [], deployer.address);
        assertEquals(multisig.result, types.ok(types.principal(wallet_1.address)));
    },
});