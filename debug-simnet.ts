
import { initSimnet } from '@hirosystems/clarinet-sdk';

async function main() {
    try {
        console.log("Initializing simnet...");
        const simnet = await initSimnet();
        console.log("Simnet initialized.");

        const accounts = simnet.getAccounts();
        console.log("Accounts found:", accounts.keys());

        if (accounts.has('deployer')) {
            console.log("Deployer address:", accounts.get('deployer'));
        } else {
            console.error("Deployer account NOT found!");
        }
    } catch (error) {
        console.error("Error during initialization:", error);
    }
}

main();
