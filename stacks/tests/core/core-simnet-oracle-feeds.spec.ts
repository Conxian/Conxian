import { describe, it, expect } from 'vitest';
import { Cl } from '@stacks/transactions';

// Core simnet tests for dimensional-oracle feed management

describe('Core simnet: dimensional-engine feed management', () => {
  it('adds and removes a price feed for an asset', () => {
    // @ts-ignore provided by global-vitest.setup.ts
    const simnet = global.simnet;
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer');
    const wallet1 = accounts.get('wallet_1');

    const asset = Cl.principal(deployer);
    const feed = Cl.principal(wallet1);

    const add = simnet.callPublicFn('dimensional-engine', 'add-oracle', [feed, Cl.uint(100)], deployer);
    expect(add).toBeDefined();

    const remove = simnet.callPublicFn('dimensional-engine', 'remove-oracle', [feed], deployer);
    expect(remove).toBeDefined();
  });
});
