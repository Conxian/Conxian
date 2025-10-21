import { test, expect, beforeAll } from 'vitest';
import { setup, getDeployer } from '../utils/setup';
import { fetchCallReadOnlyFunction, cvToValue, standardPrincipalCV } from '@stacks/transactions';
import { ClarityAbi } from '@stacks/transactions';

test('should maintain total supply invariant', async () => {
  const { chain, contracts } = setup();
  const deployer = getDeployer(chain);
  
  // Get initial total supply
  const initialSupply = await contracts.token.totalSupply({ sender: deployer.address });
  
  // Perform some token operations
  await chain.mineBlock([
    contracts.token.mint(1000n, deployer.address, deployer.address),
    contracts.token.transfer(500n, 'wallet_1', deployer.address),
    contracts.token.burn(100n, deployer.address)
  ]);
  
  // Get final total supply with proper typing
  const finalSupply = await contracts.token.totalSupply({ sender: deployer.address });
  
  // Calculate expected supply
  const expectedSupply = initialSupply + 1000n - 100n; // mint 1000, burn 100
  
  // Verify invariant
  expect(finalSupply).toBe(expectedSupply);
});

test('should maintain sum of balances equal to total supply', async () => {
  const { chain, contracts, accounts } = setup();
  const deployer = getDeployer(chain);
  
  // Get all account addresses
  const accountList = Array.from(accounts.values()).map(acc => acc.address);
  accountList.push(deployer.address); // Include deployer
  
  // Get total supply
  const totalSupply = await contracts.token.totalSupply({ sender: deployer.address });
  
  // Sum all balances
  let sumOfBalances = 0n;
  for (const address of accountList) {
    const balance = await contracts.token.balanceOf(address, { sender: deployer.address });
    sumOfBalances += balance;
  }
  
  // Verify invariant
  expect(sumOfBalances).toBe(totalSupply);
});

test('should maintain non-negative balances', async () => {
  const { chain, contracts } = setup();
  const deployer = getDeployer(chain);
  
  // Get token balance with proper typing
  const balance = await contracts.token.balanceOf(deployer.address, { sender: deployer.address });
  const transferAmount = balance + 1n;
  
  const result = await chain.mineBlock([
    contracts.token.transfer(transferAmount, 'wallet_1', deployer.address)
  ]);
  
  // Transfer should fail
  expect(result[0].result).toMatch(/insufficient-balance/);
  
  // Balance should remain unchanged
  const newBalance = await contracts.token.balanceOf(deployer.address);
  expect(newBalance).toBe(balance);
});
