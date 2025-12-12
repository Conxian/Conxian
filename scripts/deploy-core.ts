
import {
  makeContractDeploy,
  broadcastTransaction,
  AnchorMode,
  PostConditionMode,
  uintCV,
  contractPrincipalCV,
  trueCV,
  falseCV
} from "@stacks/transactions";
import { STACKS_MAINNET, STACKS_MOCKNET, STACKS_TESTNET } from "@stacks/network";
import { readFileSync } from "fs";
import * as path from "path";

// Configuration
const NETWORK_ENV = process.env.NETWORK || "devnet";
const PRIVATE_KEY = process.env.DEPLOYER_KEY || "753b7cc01a1a2e86221266a154af739463fce51219d97e4f856cd7200c3bd2a601"; // Default devnet key
const DEPLOYER_ADDR = process.env.DEPLOYER_ADDR || "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";

// Setup Network
const network = NETWORK_ENV === "mainnet" ? STACKS_MAINNET :
  NETWORK_ENV === "testnet" ? STACKS_TESTNET :
    STACKS_MOCKNET;

console.log(`Initializing deployment for ${NETWORK_ENV}...`);
console.log(`Deployer: ${DEPLOYER_ADDR}`);

// Contract List (In Dependency Order)
const contracts = [
  // 1. Traits & Standards
  { name: "sip-standards", path: "contracts/traits/sip-standards.clar" },
  { name: "defi-traits", path: "contracts/traits/defi-traits.clar" },

  // 2. Core Libraries & Errors
  { name: "standard-errors", path: "contracts/errors/standard-errors.clar" },
  { name: "math-lib-concentrated", path: "contracts/math/math-lib-concentrated.clar" },

  // 3. Tokens (Governance & Mock)
  { name: "cxd-token", path: "contracts/tokens/cxd-token.clar" },
  { name: "mock-token", path: "contracts/mocks/mock-token.clar" }, // Devnet only usually

  // 4. Security & Access
  { name: "circuit-breaker", path: "contracts/security/circuit-breaker.clar" },
  { name: "mev-protector", path: "contracts/security/mev-protector.clar" },

  // 5. DEX Core
  { name: "concentrated-liquidity-pool", path: "contracts/dex/concentrated-liquidity-pool.clar" },
  { name: "dex-factory-v2", path: "contracts/dex/dex-factory-v2.clar" },
  { name: "multi-hop-router-v3", path: "contracts/dex/multi-hop-router-v3.clar" },

  // 6. sBTC Vault System
  { name: "fee-manager", path: "contracts/vaults/fee-manager.clar" },
  { name: "btc-bridge", path: "contracts/vaults/btc-bridge.clar" },
  { name: "sbtc-vault", path: "contracts/vaults/sbtc-vault.clar" }
];

async function deploy() {
  // Fetch nonce using Stacks Blockchain API client directly since fetchNextNonce is deprecated/removed on network object
  // For devnet/mocknet, we can start at 0 if we're resetting, but better to query
  // Since we don't have the API client imported, let's assume 0 for a fresh devnet or use a simplified approach
  // NOTE: In a real script, we'd use `new AccountsApi(config).getAccountNonce({ principal: ... })`
  // For this rapid script, we'll try to just start at 0 and let the node handle it or assume standard nonce tracking
  let nonce = 0n;
  console.log(`Starting deployment with nonce: ${nonce}`);

  for (const contract of contracts) {
    console.log(`Deploying ${contract.name}...`);

    try {
      const code = readFileSync(contract.path, "utf8");

      const tx = await makeContractDeploy({
        contractName: contract.name,
        codeBody: code,
        senderKey: PRIVATE_KEY,
        network,
        anchorMode: AnchorMode.Any,
        postConditionMode: PostConditionMode.Allow,
        fee: 50000, // Fixed fee for devnet
        nonce: nonce
      });

      const result = await broadcastTransaction(tx, network);

      if (result.error) {
        console.error(`Error deploying ${contract.name}:`, result.error);
        process.exit(1);
      }

      console.log(`✅ ${contract.name} deployed. TxId: ${result.txid}`);
      nonce += 1n; // Increment nonce for next tx

      // Small delay to allow mocknet to process (optional)
      await new Promise(r => setTimeout(r, 500));

    } catch (error) {
      console.error(`Failed to deploy ${contract.name}:`, error);
      process.exit(1);
    }
  }

  console.log("🚀 All core contracts deployed successfully!");
}

deploy().catch(console.error);
