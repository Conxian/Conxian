import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

// Tests for the standalone pool-registry contract.
describe('Pool Registry', () => {
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

  it('registers a new pool and increments pool count', () => {
    const cxd = Cl.contractPrincipal(deployer, 'cxd-token');
    const cxlp = Cl.contractPrincipal(deployer, 'cxlp-token');
    const clpPool = Cl.contractPrincipal(deployer, 'concentrated-liquidity-pool');

    const res = simnet.callPublicFn('pool-registry', 'register-pool', [
      cxd,
      cxlp,
      Cl.uint(30), // 0.30% fee tier
      clpPool,
    ], deployer);

    expect(res.result).toBeOk(Cl.uint(0));

    const info = simnet.callReadOnlyFn('pool-registry', 'get-pool-data', [
      Cl.uint(0),
    ], deployer);
    expect(info.result).toBeSome();

    const count = simnet.callReadOnlyFn('pool-registry', 'get-pool-count', [], deployer);
    expect(count.result).toBeOk(Cl.uint(1));
  });

  it('rejects pools with identical tokens', () => {
    const cxd = Cl.contractPrincipal(deployer, 'cxd-token');
    const clpPool = Cl.contractPrincipal(deployer, 'concentrated-liquidity-pool');

    const res = simnet.callPublicFn('pool-registry', 'register-pool', [
      cxd,
      cxd,
      Cl.uint(30),
      clpPool,
    ], deployer);

    // (err u100) when token-x == token-y
    expect(res.result).toBeErr(Cl.uint(100));
  });

  it('rejects pools with zero fee tier', () => {
    const cxd = Cl.contractPrincipal(deployer, 'cxd-token');
    const cxlp = Cl.contractPrincipal(deployer, 'cxlp-token');
    const clpPool = Cl.contractPrincipal(deployer, 'concentrated-liquidity-pool');

    const res = simnet.callPublicFn('pool-registry', 'register-pool', [
      cxd,
      cxlp,
      Cl.uint(0),
      clpPool,
    ], deployer);

    // (err u101) when fee-tier is zero
    expect(res.result).toBeErr(Cl.uint(101));
  });
});
