import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Analytics Aggregator', () => {
  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml');
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), 'Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  it('allows owner to set the metrics updater', () => {
    const setUpdater = simnet.callPublicFn(
      'analytics-aggregator',
      'set-metrics-updater',
      [Cl.standardPrincipal(wallet1)],
      deployer
    );
    expect(setUpdater.result).toBeOk(Cl.bool(true));

    const status = simnet.callReadOnlyFn(
      'analytics-aggregator',
      'get-analytics-status',
      [],
      deployer
    );
    expect(status.result).toEqual(
      Cl.tuple({
        enabled: Cl.bool(true),
        owner: Cl.standardPrincipal(deployer),
        updater: Cl.standardPrincipal(wallet1),
      })
    );
  });

  it('allows the metrics updater to update asset TVL', () => {
    simnet.callPublicFn(
      'analytics-aggregator',
      'set-metrics-updater',
      [Cl.standardPrincipal(wallet1)],
      deployer
    );

    const updateTvl = simnet.callPublicFn(
      'analytics-aggregator',
      'update-asset-tvl',
      [Cl.standardPrincipal(deployer), Cl.uint(1000), Cl.uint(1000)],
      wallet1
    );
    expect(updateTvl.result).toBeOk(Cl.bool(true));

    const tvl = simnet.callReadOnlyFn(
      'analytics-aggregator',
      'get-asset-tvl',
      [Cl.standardPrincipal(deployer)],
      deployer
    );
    expect(tvl.result).toBeSome(
      Cl.tuple({
        amount: Cl.uint(1000),
        'usd-value': Cl.uint(1000),
        'last-updated': Cl.uint(2),
      })
    );
  });

  it('prevents a non-updater from updating asset TVL', () => {
    const updateTvl = simnet.callPublicFn(
      'analytics-aggregator',
      'update-asset-tvl',
      [Cl.standardPrincipal(deployer), Cl.uint(1000), Cl.uint(1000)],
      wallet1
    );
    expect(updateTvl.result).toBeErr(Cl.uint(5001)); // ERR_UNAUTHORIZED
  });

  it('allows owner to disable analytics', () => {
    const disable = simnet.callPublicFn(
      'analytics-aggregator',
      'set-analytics-enabled',
      [Cl.bool(false)],
      deployer
    );
    expect(disable.result).toBeOk(Cl.bool(true));

    const status = simnet.callReadOnlyFn(
      'analytics-aggregator',
      'get-analytics-status',
      [],
      deployer
    );
    expect(status.result).toEqual(
      Cl.tuple({
        enabled: Cl.bool(false),
        owner: Cl.standardPrincipal(deployer),
        updater: Cl.standardPrincipal(deployer),
      })
    );
  });
});