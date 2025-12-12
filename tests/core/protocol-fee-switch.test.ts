import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

const MODULE_DEX = 'DEX';

describe('Protocol Fee Switch', () => {
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
    wallet1 = accounts.get('wallet_1') || 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
  });

  it('enforces ownership and authorization for fee configuration', () => {
    const nonOwnerSet = simnet.callPublicFn('protocol-fee-switch', 'set-module-fee', [
      Cl.stringAscii(MODULE_DEX),
      Cl.uint(30),
    ], wallet1);
    expect(nonOwnerSet.result).toBeErr(Cl.uint(1000));

    const goodSet = simnet.callPublicFn('protocol-fee-switch', 'set-module-fee', [
      Cl.stringAscii(MODULE_DEX),
      Cl.uint(30),
    ], deployer);
    expect(goodSet.result).toBeOk(Cl.bool(true));

    const tooHigh = simnet.callPublicFn('protocol-fee-switch', 'set-module-fee', [
      Cl.stringAscii(MODULE_DEX),
      Cl.uint(10_001),
    ], deployer);
    expect(tooHigh.result).toBeErr(Cl.uint(1001));
  });

  it('validates fee splits sum to 100% and updates splits', () => {
    const goodSplits = simnet.callPublicFn('protocol-fee-switch', 'set-fee-splits', [
      Cl.uint(2_000),
      Cl.uint(6_000),
      Cl.uint(2_000),
      Cl.uint(0),
    ], deployer);
    expect(goodSplits.result).toBeOk(Cl.bool(true));

    const badSplits = simnet.callPublicFn('protocol-fee-switch', 'set-fee-splits', [
      Cl.uint(2_000),
      Cl.uint(6_000),
      Cl.uint(1_000),
      Cl.uint(0),
    ], deployer);
    expect(badSplits.result).toBeErr(Cl.uint(1002));
  });

  it('exposes fee rates and effective fee rates', () => {
    const setFee = simnet.callPublicFn('protocol-fee-switch', 'set-module-fee', [
      Cl.stringAscii('LENDING'),
      Cl.uint(50),
    ], deployer);
    expect(setFee.result).toBeOk(Cl.bool(true));

    const fee = simnet.callReadOnlyFn('protocol-fee-switch', 'get-fee-rate', [
      Cl.stringAscii('LENDING'),
    ], deployer);
    expect(fee.result).toBeOk(Cl.uint(50));

    const eff = simnet.callReadOnlyFn('protocol-fee-switch', 'get-effective-fee-rate', [
      Cl.standardPrincipal(wallet1),
      Cl.stringAscii('LENDING'),
    ], deployer);
    expect(eff.result).toBeOk();
  });

  it('gracefully handles route-fees with zero amount', () => {
    const res = simnet.callPublicFn('protocol-fee-switch', 'route-fees', [
      Cl.contractPrincipal(deployer, 'cxd-token'),
      Cl.uint(0),
      Cl.bool(true),
      Cl.stringAscii(MODULE_DEX),
    ], deployer);

    expect(res.result).toBeOk(Cl.uint(0));
  });
});
