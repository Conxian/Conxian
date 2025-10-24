import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "position-factory: create-position succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("position-factory", "create-position", [
                types.principal(deployer.address + ".token-a"),
                types.uint(1000),
                types.principal(deployer.address + ".token-b"),
                types.uint(500)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.ok(types.uint(0)));

        let positionMetadata = chain.callReadOnlyFn("position-factory", "get-position-metadata", [
            types.uint(0)
        ], deployer.address);
        positionMetadata.result.expectSome().expectTuple();
    },
});

Clarinet.test({
    name: "position-factory: create-position fails for invalid collateral amount",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("position-factory", "create-position", [
                types.principal(deployer.address + ".token-a"),
                types.uint(0),
                types.principal(deployer.address + ".token-b"),
                types.uint(500)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.err(types.uint(3001)));
    },
});

Clarinet.test({
    name: "position-factory: create-position fails for invalid debt amount",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("position-factory", "create-position", [
                types.principal(deployer.address + ".token-a"),
                types.uint(1000),
                types.principal(deployer.address + ".token-b"),
                types.uint(0)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.err(types.uint(3001)));
    },
});

Clarinet.test({
    name: "position-factory: set-contract-owner succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("position-factory", "set-contract-owner", [
                types.principal(wallet_1.address)
            ], deployer.address)
        ]);
        assertEquals(block.receipts[0].result, types.ok(types.bool(true)));

        let owner = chain.callReadOnlyFn("position-factory", "get-contract-owner", [], deployer.address);
        assertEquals(owner.result, types.ok(types.principal(wallet_1.address)));
    },
});

Clarinet.test({
    name: "position-factory: set-contract-owner fails if not authorized",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let wallet_1 = accounts.get("wallet_1")!;
        let wallet_2 = accounts.get("wallet_2")!;

        let block = chain.mineBlock([
            Tx.contractCall("position-factory", "set-contract-owner", [
                types.principal(wallet_2.address)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.err(types.uint(3000)));
    },
});

Clarinet.test({
    name: "position-factory: set-governance-address succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("position-factory", "set-governance-address", [
                types.principal(wallet_1.address)
            ], deployer.address)
        ]);
        assertEquals(block.receipts[0].result, types.ok(types.bool(true)));

        let governance = chain.callReadOnlyFn("position-factory", "get-governance-address", [], deployer.address);
        assertEquals(governance.result, types.ok(types.principal(wallet_1.address)));
    },
});