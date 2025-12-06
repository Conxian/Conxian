import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;

// Smoke tests for the sBTC vault facade. These focus on admin controls and
// read-only stats rather than cross-contract integrations.
describe('sBTC Vault', () => {
  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml', false, {
      trackCosts: false,
      trackCoverage: false,
    });
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), 'Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('allows owner to pause and unpause the vault', () => {
    const pause = simnet.callPublicFn('sbtc-vault', 'set-vault-paused', [
      Cl.bool(true),
    ], deployer);
    expect(pause.result).toBeOk(Cl.bool(true));

    const unpause = simnet.callPublicFn('sbtc-vault', 'set-vault-paused', [
      Cl.bool(false),
    ], deployer);
    expect(unpause.result).toBeOk(Cl.bool(true));
  });

  it('exposes vault stats with a paused flag that tracks admin setting', () => {
    // Ensure paused = true
    simnet.callPublicFn('sbtc-vault', 'set-vault-paused', [Cl.bool(true)], deployer);

    const stats = simnet.callReadOnlyFn('sbtc-vault', 'get-vault-stats', [], deployer);

    expect(stats.result).toBeOk(
      Cl.tuple({
        'total-sbtc': Cl.uint(0),
        'total-shares': Cl.uint(0),
        'total-yield': Cl.uint(0),
        'share-price': Cl.uint(100_000_000),
        paused: Cl.bool(true),
      }),
    );
  });
});
