import { ClarityAbi, ClarityValue, cvToValue, hexToCV } from '@stacks/transactions';
import { TestAccount, createAccount, createChain } from '@clarigen/core';
import { createMockTestContracts, TestContracts } from './token-helpers';

export interface TestContext {
  chain: any;
  accounts: Map<string, TestAccount>;
  contracts: TestContracts;
}

// Create test accounts
export function createTestAccounts() {
  const accounts = new Map<string, TestAccount>();
  
  // Deployer account (contract owner)
  const deployer = createAccount('deployer');
  accounts.set('deployer', deployer);
  
  // Regular user accounts
  for (let i = 1; i <= 10; i++) {
    const account = createAccount(`wallet_${i}`);
    accounts.set(`wallet_${i}`, account);
  }
  
  return accounts;
}

// Setup test environment
export function setup(): TestContext {
  // Create test accounts
  const accounts = createTestAccounts();
  const deployer = accounts.get('deployer')!;
  
  // Create a mock chain
  const chain = createChain({
    accounts: Array.from(accounts.values()),
    deployer: deployer.address,
  });
  
  // Create mock contracts
  const contracts = createMockTestContracts(deployer.address);
  
  return {
    chain,
    accounts,
    contracts,
  };
}

// Helper to get deployer account
export function getDeployer(chain: any, accounts: Map<string, any>) {
  return accounts.get('deployer')!;
}

// Helper to get test contracts
export function getTestContracts(chain: any, address?: string): TestContracts {
  const deployer = chain.deployer;
  return createMockTestContracts(address || deployer);
}

// Helper to get contract by name
export function getContractByName(contracts: any, name: string) {
  const contract = contracts[name];
  if (!contract) {
    throw new Error(`Contract ${name} not found`);
  }
  return contract;
}

// Helper to get contract owner
export async function getContractOwner(contract: any) {
  const result = await contract.getOwner();
  return result.value;
}

// Helper to get contract name
export async function getContractName(contract: any) {
  const result = await contract.getName();
  return result.value;
}

// Helper to get contract symbol
export async function getContractSymbol(contract: any) {
  const result = await contract.getSymbol();
  return result.value;
}

// Helper to get contract decimals
export async function getContractDecimals(contract: any) {
  const result = await contract.getDecimals();
  return result.value;
}

// Helper to get contract total supply
export async function getContractTotalSupply(contract: any) {
  const result = await contract.getTotalSupply();
  return result.value;
}

// Helper to get token balance
export async function getTokenBalance(contract: any, owner: string) {
  const result = await contract.getBalance(owner);
  return result.value;
}

// Helper to mint tokens
export async function mintTokens(contract: any, recipient: string, amount: bigint, sender: any) {
  return contract.mint(recipient, amount, { sender });
}

// Helper to transfer tokens
export async function transferTokens(
  contract: any, 
  sender: any, 
  recipient: string, 
  amount: bigint
) {
  return contract.transfer(amount, sender.address, recipient, null, { sender });
}
