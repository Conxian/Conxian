import { describe, it, expect } from 'vitest';
import { Cl } from '@stacks/transactions';

// Minimal simnet smoke test for core manifest contracts
// Verifies SDK initialization and a simple read-only call

describe('Core simnet smoke', () => {
  it('initializes SDK and reads from position-nft', () => {
    // @ts-ignore global is set by global-vitest.setup.ts + clarinet-sdk helpers
    const simnet = global.simnet;
    expect(simnet).toBeDefined();

    const accounts = simnet.getAccounts();
    expect(accounts).toBeDefined();

    const deployer = accounts.get('deployer');
    const res = simnet.callReadOnlyFn('position-nft', 'get-last-token-id', [], deployer);
    expect(res).toBeDefined();
  });
});
