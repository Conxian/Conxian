import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';

Clarinet.test({
    name: "deploy all new contracts",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get('deployer')!;

        let block = chain.mineBlock([
            Tx.deployContract(
                'liquidity-provider',
                './contracts/dex/liquidity-provider.clar',
                deployer.address
            ),
            Tx.deployContract(
                'price-impact-calculator',
                './contracts/dex/price-impact-calculator.clar',
                deployer.address
            ),
            Tx.deployContract(
                'position-factory',
                './contracts/position-factory.clar',
                deployer.address
            ),
            Tx.deployContract(
                'insurance-fund',
                './contracts/risk/insurance-fund.clar',
                deployer.address
            ),
            Tx.deployContract(
                'chainlink-adapter',
                './contracts/integrations/chainlink-adapter.clar',
                deployer.address
            ),
            Tx.deployContract(
                'twap-oracle',
                './contracts/integrations/twap-oracle.clar',
                deployer.address
            ),
        ]);

        block.receipts.forEach(receipt => {
            receipt.result.expectOk();
        });

        console.log("All new contracts deployed successfully!");
    },
});