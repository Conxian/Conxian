// tests/refactor-verification.test.ts
//
// This test suite is designed to verify the correct functionality of the
// refactored Lending and Governance modules. It will test the end-to-end
// functionality through the facade contracts to ensure that the delegated
// architecture is working as expected.

import { describe, it, expect, beforeEach } from 'vitest';
import { TestProvider, getTestProvider, tx, RO } from '@stacks/clarinet-sdk';
import { principal, uint } from '@stacks/transactions';

describe('Refactor Verification Suite', () => {
  let provider: TestProvider;
  let deployer: string;
  let wallet1: string;

  beforeEach(async () => {
    provider = await getTestProvider();
    const accounts = await provider.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  it('Lending Module - should supply and withdraw through the facade', async () => {
    const asset = `${deployer}.mock-token`;
    const amount = 1000;

    // Supply
    let receipt = await provider.eval(
      tx(
        {
          sender: wallet1,
          contract: `${deployer}.comprehensive-lending-system`,
          method: 'supply',
          args: [principal(asset), uint(amount)],
        },
        {
          accounts: {
            wallet_1: {
              balances: {
                stx: 1000000,
                'mock-token': 10000,
              },
            },
          },
        }
      )
    );
    expect(receipt.success).toBe(true);

    // Verify supply balance
    let balance = await provider.eval(
      RO(
        {
          contract: `${deployer}.lending-manager`,
          method: 'get-user-supply-balance',
          args: [principal(wallet1), principal(asset)],
        }
      )
    );
    expect(balance.result).toBeSome(uint(amount));

    // Withdraw
    receipt = await provider.eval(
      tx(
        {
          sender: wallet1,
          contract: `${deployer}.comprehensive-lending-system`,
          method: 'withdraw',
          args: [principal(asset), uint(amount)],
        }
      )
    );
    expect(receipt.success).toBe(true);
  });

  it('Governance Module - should create and execute a proposal through the facade', async () => {
    // Create Proposal
    let receipt = await provider.eval(
        tx(
            {
                sender: deployer,
                contract: `${deployer}.proposal-engine`,
                method: 'propose',
                args: [
                    '0x746573742070726f706f73616c', // "test proposal"
                    `[${deployer}.mock-token]`,
                    '[u100]',
                    '["transfer"]',
                    `[0x01${deployer.replace('ST', '0x')}${wallet1.replace('ST', '0x')}000000000000000000000000000000000000000a]`,
                    'u1',
                    'u100',
                ],
            },
        )
    );
    expect(receipt.success).toBe(true);

    // Vote
    receipt = await provider.eval(
      tx(
        {
          sender: deployer,
          contract: `${deployer}.proposal-engine`,
          method: 'vote',
          args: ['u1', 'true'],
        }
      )
    );
    expect(receipt.success).toBe(true);

    // Execute
    receipt = await provider.eval(
      tx(
        {
          sender: deployer,
          contract: `${deployer}.proposal-engine`,
          method: 'execute',
          args: ['u1'],
        }
      )
    );
    expect(receipt.success).toBe(true);

    // Verify proposal was executed
    const proposal = await provider.eval(
      RO(
        {
          contract: `${deployer}.proposal-registry`,
          method: 'get-proposal',
          args: ['u1'],
        }
      )
    );
    expect(proposal.result).toBeSomeTuple({
      executed: 'true',
    });
  });
});
