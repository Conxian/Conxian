import { describe, it, expect } from 'vitest';
import { Cl } from '@stacks/transactions';

// Core simnet tests for dimensional-oracle feed management

describe('Core simnet: dimensional-oracle feed management', () => {
  it('adds and removes a price feed for an asset', () => {
    // @ts-ignore provided by global-vitest.setup.ts
    const simnet = global.simnet;
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer');
    const wallet1 = accounts.get('wallet_1');

    const asset = Cl.principal(deployer);
    const feed = Cl.principal(wallet1);

    const add = simnet.callPublicFn('dimensional-oracle', 'add-price-feed', [asset, feed], deployer);
    expect(add).toBeDefined();

    const remove = simnet.callPublicFn('dimensional-oracle', 'remove-price-feed', [asset, feed], deployer);
    expect(remove).toBeDefined();
  });
});
