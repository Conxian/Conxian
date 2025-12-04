import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('TWAP Oracle', () => {
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
    wallet1 = accounts.get('wallet_1')!;
  });

  it('rejects update-twap from non-governance address', () => {
    const asset = Cl.contractPrincipal(deployer, 'cxd-token');

    const res = simnet.callPublicFn('twap-oracle', 'update-twap', [
      asset,
      Cl.uint(60),
      Cl.uint(100_000),
    ], wallet1);

    // ERR-NOT-AUTHORIZED = (err u6000)
    expect(res.result).toBeErr(Cl.uint(6000));
  });

  it('returns error when requesting TWAP with no data', () => {
    const asset = Cl.contractPrincipal(deployer, 'cxd-token');

    const twap = simnet.callReadOnlyFn('twap-oracle', 'get-twap', [
      asset,
      Cl.uint(60),
    ], deployer);

    // ERR-NO-DATA = (err u6002)
    expect(twap.result).toBeErr(Cl.uint(6002));
  });

  it('allows governance to update TWAP and returns last price for first sample', () => {
    const asset = Cl.contractPrincipal(deployer, 'cxd-token');

    // By default, governance-address is the deployer. The first update-twap
    // call should succeed and TWAP should equal the last price.
    const res = simnet.callPublicFn('twap-oracle', 'update-twap', [
      asset,
      Cl.uint(60),
      Cl.uint(123_456),
    ], deployer);
    expect(res.result).toBeOk(Cl.bool(true));

    const twap = simnet.callReadOnlyFn('twap-oracle', 'get-twap', [
      asset,
      Cl.uint(60),
    ], deployer);

    expect(twap.result).toBeOk(Cl.uint(123_456));
  });
});
