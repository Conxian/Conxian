#!/usr/bin/env node
/**
 * Deployment script for Conxian Core Contracts (Testnet)
 * Deploys the core contracts in the correct order
 */
const path = require('path');
const fs = require('fs');
const { 
  makeContractDeploy,
  broadcastTransaction,
  AnchorMode,
  getAddressFromPrivateKey,
  StacksTestnet,
  StacksMainnet
} = require('@stacks/transactions');

// Configuration
const PROJECT_ROOT = path.resolve(__dirname, '..');
const CONTRACTS_DIR = path.join(PROJECT_ROOT, 'contracts');
const NETWORK = process.env.NETWORK || 'testnet';
const PRIV_KEY = process.env.DEPLOYER_PRIVKEY;

if (!PRIV_KEY) {
  console.error('Error: DEPLOYER_PRIVKEY environment variable is required');
  process.exit(1);
}

// Define the deployment order
const CONTRACT_ORDER = [
  // Core Traits (now centralized in all-traits.clar)
  'all-traits',
  
  // Token Contracts
  'cxd-token',
  'governance-token',
  'cxtr-token',
  'cxlp-token',
  'cxvg-token',
  
  // Core System Contracts
  'trait-registry',
  'system-monitor',
  'yield-distribution-engine',
  'token-emission-controller',
  'token-system-coordinator',
  
  // DEX Core
  'dex-factory',
  'dex-pool',
  'dex-router',
  'vault',
  'yield-optimizer',
  
  // Governance
  'governance-timelock',
  'governance-token',
  'governor',
  'proposal-factory',
  
  // Additional Modules
  'tokenized-bond',
  'flash-loan-vault',
  'mev-protector'
];

// Initialize network
const network = NETWORK === 'mainnet' 
  ? new StacksMainnet() 
  : new StacksTestnet();

// Set the API URL for the network
network.coreApiUrl = NETWORK === 'mainnet'
  ? 'https://api.hiro.so'
  : 'https://api.testnet.hiro.so';

// Add API key if available
if (process.env.HIRO_API_KEY) {
  network.headers = {
    'x-hiro-api-key': process.env.HIRO_API_KEY
  };
}

// Utility functions
async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function getAccountInfo(address) {
  try {
    const response = await fetch(`${network.coreApiUrl}/v2/accounts/${address}?proof=0`);
    if (!response.ok) {
      throw new Error(`Failed to fetch account info: ${response.statusText}`);
    }
    return await response.json();
  } catch (error) {
    console.error('Error fetching account info:', error);
    throw error;
  }
}

async function deployContract(contractName, privKey) {
  console.log(`\n🔨 Deploying ${contractName}...`);
  
  // Handle trait files that are now in all-traits
  const contractPath = contractName.endsWith('-trait')
    ? path.join(CONTRACTS_DIR, 'traits', 'all-traits.clar')
    : path.join(CONTRACTS_DIR, contractName.endsWith('.clar') ? contractName : `${contractName}.clar`);
  
  if (!fs.existsSync(contractPath)) {
    console.error(`❌ Contract file not found: ${contractPath}`);
    return { success: false, error: 'File not found' };
  }

  const source = fs.readFileSync(contractPath, 'utf8');
  
  try {
    const transaction = await makeContractDeploy({
      contractName: contractName.replace('.clar', ''),
      codeBody: source,
      senderKey: privKey,
      network,
      anchorMode: AnchorMode.Any,
      fee: 10000, // 0.01 STX fee
    });

    console.log(`📤 Broadcasting transaction for ${contractName}...`);
    const broadcastResponse = await broadcastTransaction(transaction, network);
    
    if (!broadcastResponse.txid) {
      throw new Error(`No transaction ID returned: ${JSON.stringify(broadcastResponse)}`);
    }

    console.log(`✅ Transaction broadcast: ${broadcastResponse.txid}`);
    console.log(`   Explorer: https://explorer.hiro.so/txid/${broadcastResponse.txid}?chain=${NETWORK}`);
    
    // Wait for transaction to complete
    console.log('⏳ Waiting for transaction confirmation...');
    const result = await waitForTransaction(broadcastResponse.txid);
    
    if (result.success) {
      console.log(`🎉 Successfully deployed ${contractName} in block ${result.blockHeight}`);
      return { 
        success: true, 
        txId: broadcastResponse.txid, 
        blockHeight: result.blockHeight 
      };
    } else {
      throw new Error(`Transaction failed: ${result.error}`);
    }
  } catch (error) {
    console.error(`❌ Error deploying ${contractName}:`, error.message);
    return { 
      success: false, 
      error: error.message,
      contract: contractName
    };
  }
}

async function waitForTransaction(txId, maxAttempts = 30) {
  let attempts = 0;
  
  while (attempts < maxAttempts) {
    try {
      const response = await fetch(`${network.coreApiUrl}/extended/v1/tx/${txId}`);
      const data = await response.json();
      
      if (data.tx_status === 'success') {
        return { 
          success: true, 
          blockHeight: data.block_height,
          status: data.tx_status 
        };
      } else if (data.tx_status === 'pending' || data.tx_status === 'received') {
        console.log(`   Transaction status: ${data.tx_status} (${attempts + 1}/${maxAttempts})`);
        await sleep(10000); // Wait 10 seconds before checking again
        attempts++;
      } else {
        return { 
          success: false, 
          error: `Transaction failed with status: ${data.tx_status}`,
          status: data.tx_status
        };
      }
    } catch (error) {
      console.error('Error checking transaction status:', error.message);
      await sleep(5000); // Wait 5 seconds before retrying
      attempts++;
    }
  }
  
  return { 
    success: false, 
    error: 'Transaction confirmation timed out' 
  };
}

// Main deployment function
async function main() {
  console.log('🚀 Starting Conxian Core Contracts Deployment 🚀');
  console.log('==============================================');
  console.log(`Network: ${NETWORK}`);
  
  const address = getAddressFromPrivateKey(PRIV_KEY, network.version);
  console.log(`Deployer: ${address}`);
  
  // Check account balance
  try {
    const accountInfo = await getAccountInfo(address);
    const balance = parseInt(accountInfo.balance) / 1000000;
    console.log(`Account Balance: ${balance} STX`);
    
    if (balance < 10) {
      console.warn('⚠️  Low balance - ensure you have enough STX for deployment');
    }
  } catch (error) {
    console.warn('⚠️  Could not fetch account balance:', error.message);
  }
  
  console.log('\n📋 Deployment Order:');
  CONTRACT_ORDER.forEach((contract, index) => {
    console.log(`  ${index + 1}. ${contract}`);
  });
  
  console.log('\n🚀 Starting deployment process...');
  
  // Deploy contracts in order
  const results = [];
  
  for (const contract of CONTRACT_ORDER) {
    console.log(`\n📦 Deploying: ${contract}`);
    const result = await deployContract(contract, PRIV_KEY);
    results.push({
      contract,
      ...result
    });
    
    // Add a small delay between deployments
    if (result.success) {
      console.log('⏳ Waiting before next deployment...');
      await sleep(5000); // 5 second delay
    } else {
      console.error(`❌ Failed to deploy ${contract}. Stopping deployment.`);
      break;
    }
  }
  
  // Print summary
  console.log('\n📊 Deployment Summary:');
  console.log('===================');
  
  let successCount = 0;
  let failureCount = 0;
  
  results.forEach((result, index) => {
    const status = result.success ? '✅' : '❌';
    console.log(`${index + 1}. ${status} ${result.contract}`);
    
    if (result.success) {
      console.log(`   TX: ${result.txId}`);
      console.log(`   Block: ${result.blockHeight}`);
      successCount++;
    } else {
      console.log(`   Error: ${result.error}`);
      failureCount++;
    }
    
    console.log('   ' + '-'.repeat(50));
  });
  
  console.log(`\n🎉 Deployment complete!`);
  console.log(`✅ Success: ${successCount}`);
  console.log(`❌ Failed: ${failureCount}`);
  
  if (failureCount > 0) {
    process.exit(1);
  }
}

// Run the deployment
main().catch(error => {
  console.error('❌ Deployment failed:', error);
  process.exit(1);
});
