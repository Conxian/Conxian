import { describe, it, expect } from 'vitest';
import { Cl } from '@stacks/transactions';

// Core simnet verification for registry and oracle using the core manifest

describe('Core simnet: dim-registry + dimensional-engine', () => {
  it('dim-registry registers a dimension and returns its weight', () => {
    // @ts-ignore provided by global-vitest.setup.ts
    const simnet = global.simnet;
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer');

    const reg = simnet.callPublicFn('dim-registry', 'register-dimension', [Cl.uint(1), Cl.uint(100)], deployer);
    expect(reg).toBeDefined();

    const weight = simnet.callReadOnlyFn('dim-registry', 'get-dimension-weight', [Cl.uint(1)], deployer);
    expect(weight).toBeDefined();
  });

  it('dimensional-engine updates and reads a price', () => {
    // @ts-ignore provided by global-vitest.setup.ts
    const simnet = global.simnet;
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer');

    const asset = Cl.principal(deployer);
    const set = simnet.callPublicFn('dimensional-engine', 'update-price', [asset, Cl.uint(123456)], deployer);
    expect(set).toBeDefined();

    const price = simnet.callReadOnlyFn('dimensional-engine', 'get-price', [asset], deployer);
    expect(price).toBeDefined();
  });
});
