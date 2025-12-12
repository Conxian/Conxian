import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

// Simple DEX factory tests: focus on registry behavior and error codes.
describe('DEX Factory V2', () => {
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

  it('allows owner to register a pool type', () => {
    const res = simnet.callPublicFn('dex-factory-v2', 'register-pool-type', [
      Cl.stringAscii('CLP'),
      Cl.stringAscii('Concentrated liquidity pool'),
    ], deployer);

    expect(res.result).toBeOk(Cl.bool(true));
  });

  it('rejects non-owner registering a pool type', () => {
    const res = simnet.callPublicFn('dex-factory-v2', 'register-pool-type', [
      Cl.stringAscii('BAD'),
      Cl.stringAscii('Should fail'),
    ], wallet1);

    // ERR_UNAUTHORIZED = (err u1000)
    expect(res.result).toBeErr(Cl.uint(1000));
  });

  it('creates a pool for a token pair and stores it in both directions', () => {
    // Register CLP pool type first
    simnet.callPublicFn('dex-factory-v2', 'register-pool-type', [
      Cl.stringAscii('CLP'),
      Cl.stringAscii('Concentrated liquidity pool'),
    ], deployer);

    const cxd = Cl.contractPrincipal(deployer, 'cxd-token');
    const cxlp = Cl.contractPrincipal(deployer, 'cxlp-token');
    const clpPool = Cl.contractPrincipal(deployer, 'concentrated-liquidity-pool');

    const create = simnet.callPublicFn('dex-factory-v2', 'create-pool', [
      Cl.stringAscii('CLP'),
      cxd,
      cxlp,
      clpPool,
      Cl.uint(1_000_000), // initial sqrt price (stub)
      Cl.int(0),          // initial tick
    ], deployer);

    // Should return Ok with the pool principal
    expect(create.result).toBeOk(clpPool);

    const poolAB = simnet.callReadOnlyFn('dex-factory-v2', 'get-pool', [
      cxd,
      cxlp,
    ], deployer);
    expect(poolAB.result).toBeOk();

    const poolBA = simnet.callReadOnlyFn('dex-factory-v2', 'get-pool', [
      cxlp,
      cxd,
    ], deployer);
    expect(poolBA.result).toBeOk();

    const count = simnet.callReadOnlyFn('dex-factory-v2', 'get-pool-count', [], deployer);
    expect(count.result).toBeOk(Cl.uint(1));
  });

  it('prevents creating duplicate pools for the same token pair', () => {
    // Register type
    simnet.callPublicFn('dex-factory-v2', 'register-pool-type', [
      Cl.stringAscii('CLP'),
      Cl.stringAscii('Concentrated liquidity pool'),
    ], deployer);

    const cxd = Cl.contractPrincipal(deployer, 'cxd-token');
    const cxlp = Cl.contractPrincipal(deployer, 'cxlp-token');
    const clpPool = Cl.contractPrincipal(deployer, 'concentrated-liquidity-pool');

    simnet.callPublicFn('dex-factory-v2', 'create-pool', [
      Cl.stringAscii('CLP'),
      cxd,
      cxlp,
      clpPool,
      Cl.uint(1_000_000),
      Cl.int(0),
    ], deployer);

    const dup = simnet.callPublicFn('dex-factory-v2', 'create-pool', [
      Cl.stringAscii('CLP'),
      cxd,
      cxlp,
      clpPool,
      Cl.uint(1_000_000),
      Cl.int(0),
    ], deployer);

    // ERR_POOL_ALREADY_EXISTS = (err u1440)
    expect(dup.result).toBeErr(Cl.uint(1440));
  });

  it('rejects creating a pool with unknown pool type', () => {
    const cxd = Cl.contractPrincipal(deployer, 'cxd-token');
    const cxlp = Cl.contractPrincipal(deployer, 'cxlp-token');
    const clpPool = Cl.contractPrincipal(deployer, 'concentrated-liquidity-pool');

    const res = simnet.callPublicFn('dex-factory-v2', 'create-pool', [
      Cl.stringAscii('UNKNOWN'),
      cxd,
      cxlp,
      clpPool,
      Cl.uint(1_000_000),
      Cl.int(0),
    ], deployer);

    // ERR_TYPE_NOT_FOUND = (err u1439)
    expect(res.result).toBeErr(Cl.uint(1439));
  });
});
