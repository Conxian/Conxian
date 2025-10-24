import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "insurance-fund: deposit-fund succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        // Mock token transfer (assuming token-a exists and can be transferred)
        // In a real test, you'd interact with an actual fungible token contract
        // For simplicity, we'll assume the transfer succeeds here.

        let block = chain.mineBlock([
            Tx.contractCall("insurance-fund", "deposit-fund", [
                types.principal(deployer.address + ".token-a"),
                types.uint(1000)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.ok(types.bool(true)));

        let fundBalance = chain.callReadOnlyFn("insurance-fund", "get-fund-balance", [
            types.principal(deployer.address + ".token-a")
        ], deployer.address);
        assertEquals(fundBalance.result, types.uint(1000));
    },
});

Clarinet.test({
    name: "insurance-fund: deposit-fund fails for invalid amount",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("insurance-fund", "deposit-fund", [
                types.principal(deployer.address + ".token-a"),
                types.uint(0)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.err(types.uint(4001)));
    },
});

Clarinet.test({
    name: "insurance-fund: withdraw-fund succeeds by governance",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        // Set governance and deposit funds first
        chain.mineBlock([
            Tx.contractCall("insurance-fund", "set-governance-address", [
                types.principal(wallet_1.address)
            ], deployer.address)
        ]);
        chain.mineBlock([
            Tx.contractCall("insurance-fund", "deposit-fund", [
                types.principal(deployer.address + ".token-a"),
                types.uint(1000)
            ], deployer.address)
        ]);

        let block = chain.mineBlock([
            Tx.contractCall("insurance-fund", "withdraw-fund", [
                types.principal(deployer.address + ".token-a"),
                types.uint(500),
                types.principal(wallet_1.address)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.ok(types.bool(true)));

        let fundBalance = chain.callReadOnlyFn("insurance-fund", "get-fund-balance", [
            types.principal(deployer.address + ".token-a")
        ], deployer.address);
        assertEquals(fundBalance.result, types.uint(500));
    },
});

Clarinet.test({
    name: "insurance-fund: withdraw-fund fails if not authorized",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;
        let wallet_2 = accounts.get("wallet_2")!;

        // Deposit funds first
        chain.mineBlock([
            Tx.contractCall("insurance-fund", "deposit-fund", [
                types.principal(deployer.address + ".token-a"),
                types.uint(1000)
            ], deployer.address)
        ]);

        let block = chain.mineBlock([
            Tx.contractCall("insurance-fund", "withdraw-fund", [
                types.principal(deployer.address + ".token-a"),
                types.uint(500),
                types.principal(wallet_2.address)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.err(types.uint(4000)));
    },
});

Clarinet.test({
    name: "insurance-fund: withdraw-fund fails for insufficient funds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        // Set governance and deposit some funds
        chain.mineBlock([
            Tx.contractCall("insurance-fund", "set-governance-address", [
                types.principal(wallet_1.address)
            ], deployer.address)
        ]);
        chain.mineBlock([
            Tx.contractCall("insurance-fund", "deposit-fund", [
                types.principal(deployer.address + ".token-a"),
                types.uint(1000)
            ], deployer.address)
        ]);

        let block = chain.mineBlock([
            Tx.contractCall("insurance-fund", "withdraw-fund", [
                types.principal(deployer.address + ".token-a"),
                types.uint(1500), // Try to withdraw more than available
                types.principal(wallet_1.address)
            ], wallet_1.address)
        ]);
        assertEquals(block.receipts[0].result, types.err(types.uint(4002)));
    },
});

Clarinet.test({
    name: "insurance-fund: set-contract-owner succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("insurance-fund", "set-contract-owner", [
                types.principal(wallet_1.address)
            ], deployer.address)
        ]);
        assertEquals(block.receipts[0].result, types.ok(types.bool(true)));

        let owner = chain.callReadOnlyFn("insurance-fund", "get-contract-owner", [], deployer.address);
        assertEquals(owner.result, types.ok(types.principal(wallet_1.address)));
    },
});

Clarinet.test({
    name: "insurance-fund: set-governance-address succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("insurance-fund", "set-governance-address", [
                types.principal(wallet_1.address)
            ], deployer.address)
        ]);
        assertEquals(block.receipts[0].result, types.ok(types.bool(true)));

        let governance = chain.callReadOnlyFn("insurance-fund", "get-governance-address", [], deployer.address);
        assertEquals(governance.result, types.ok(types.principal(wallet_1.address)));
    },
});

Clarinet.test({
    name: "insurance-fund: set-emergency-multisig succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("insurance-fund", "set-emergency-multisig", [
                types.principal(wallet_1.address)
            ], deployer.address)
        ]);
        assertEquals(block.receipts[0].result, types.ok(types.bool(true)));

        let multisig = chain.callReadOnlyFn("insurance-fund", "get-emergency-multisig", [], deployer.address);
        assertEquals(multisig.result, types.ok(types.principal(wallet_1.address)));
    },
});