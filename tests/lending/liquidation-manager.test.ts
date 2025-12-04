import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

// Tests for admin controls and whitelisting on the liquidation-manager.
describe('Liquidation Manager', () => {
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

  it('allows initial admin to set a new admin', () => {
    const res = simnet.callPublicFn('liquidation-manager', 'set-admin', [
      Cl.principal(wallet1),
    ], deployer);

    expect(res.result).toBeOk(Cl.bool(true));
  });

  it('rejects admin changes from non-admin', () => {
    // First, set wallet1 as admin
    simnet.callPublicFn('liquidation-manager', 'set-admin', [
      Cl.principal(wallet1),
    ], deployer);

    // Now deployer is no longer admin; this call should fail
    const res = simnet.callPublicFn('liquidation-manager', 'set-admin', [
      Cl.principal(deployer),
    ], deployer);

    // (err u1002) ERR_UNAUTHORIZED
    expect(res.result).toBeErr(Cl.uint(1002));
  });

  it('allows admin to set lending system and toggle pause', () => {
    const lendingSystem = Cl.contractPrincipal(deployer, 'comprehensive-lending-system');

    const setLs = simnet.callPublicFn('liquidation-manager', 'set-lending-system', [
      lendingSystem,
    ], deployer);
    expect(setLs.result).toBeOk(Cl.bool(true));

    const pause = simnet.callPublicFn('liquidation-manager', 'set-paused', [
      Cl.bool(true),
    ], deployer);
    expect(pause.result).toBeOk(Cl.bool(true));
  });

  it('validates liquidation incentive and close factor bounds', () => {
    const okIncentive = simnet.callPublicFn('liquidation-manager', 'set-liquidation-incentive', [
      Cl.uint(200),
    ], deployer);
    expect(okIncentive.result).toBeOk(Cl.bool(true));

    const badIncentive = simnet.callPublicFn('liquidation-manager', 'set-liquidation-incentive', [
      Cl.uint(2000),
    ], deployer);
    // (err u1003) invalid parameters
    expect(badIncentive.result).toBeErr(Cl.uint(1003));

    const okClose = simnet.callPublicFn('liquidation-manager', 'set-close-factor', [
      Cl.uint(5000),
    ], deployer);
    expect(okClose.result).toBeOk(Cl.bool(true));
  });

  it('whitelists assets for liquidation', () => {
    const cxd = Cl.contractPrincipal(deployer, 'cxd-token');

    const res = simnet.callPublicFn('liquidation-manager', 'whitelist-asset', [
      cxd,
      Cl.bool(true),
    ], deployer);

    expect(res.result).toBeOk(Cl.bool(true));
  });
});
