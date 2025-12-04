import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Oracle Aggregator V2', () => {
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

  it('allows owner to register trusted oracle and update price', () => {
    const asset = Cl.contractPrincipal(deployer, 'cxd-token');

    const register = simnet.callPublicFn('oracle-aggregator-v2', 'register-oracle', [
      Cl.standardPrincipal(wallet1),
      Cl.bool(true),
    ], deployer);
    expect(register.result).toBeOk(Cl.bool(true));

    const update = simnet.callPublicFn('oracle-aggregator-v2', 'update-price', [
      asset,
      Cl.uint(100_000),
    ], wallet1);
    expect(update.result).toBeOk(Cl.bool(true));

    const price = simnet.callReadOnlyFn('oracle-aggregator-v2', 'get-price', [
      asset,
    ], deployer);
    expect(price.result).toBeOk(Cl.uint(100_000));

    const cumulative = simnet.callReadOnlyFn('oracle-aggregator-v2', 'get-cumulative-price', [
      asset,
    ], deployer);
    expect(cumulative.result).toBeOk();
  });

  it('rejects unregistered oracle updates', () => {
    const asset = Cl.contractPrincipal(deployer, 'cxd-token');

    const update = simnet.callPublicFn('oracle-aggregator-v2', 'update-price', [
      asset,
      Cl.uint(50_000),
    ], wallet1);

    // ERR_UNAUTHORIZED = (err u100)
    expect(update.result).toBeErr(Cl.uint(100));
  });

  it('enforces max deviation and returns price manipulation error', () => {
    const asset = Cl.contractPrincipal(deployer, 'cxd-token');

    simnet.callPublicFn('oracle-aggregator-v2', 'register-oracle', [
      Cl.standardPrincipal(wallet1),
      Cl.bool(true),
    ], deployer);

    simnet.callPublicFn('oracle-aggregator-v2', 'update-price', [
      asset,
      Cl.uint(100_000),
    ], wallet1);

    const tooBig = simnet.callPublicFn('oracle-aggregator-v2', 'update-price', [
      asset,
      Cl.uint(150_001),
    ], wallet1);

    // ERR_PRICE_MANIPULATION = (err u104)
    expect(tooBig.result).toBeErr(Cl.uint(104));
  });

  it('respects circuit breaker when open', () => {
    const asset = Cl.contractPrincipal(deployer, 'cxd-token');

    // Enable circuit breaker checks in the aggregator
    const setCb = simnet.callPublicFn('oracle-aggregator-v2', 'set-circuit-breaker', [
      Cl.standardPrincipal(deployer),
    ], deployer);
    expect(setCb.result).toBeOk(Cl.bool(true));

    simnet.callPublicFn('oracle-aggregator-v2', 'register-oracle', [
      Cl.standardPrincipal(wallet1),
      Cl.bool(true),
    ], deployer);

    simnet.callPublicFn('oracle-aggregator-v2', 'update-price', [
      asset,
      Cl.uint(100_000),
    ], wallet1);

    const open = simnet.callPublicFn('circuit-breaker', 'open-circuit', [], deployer);
    expect(open.result).toBeOk(Cl.bool(true));

    const blocked = simnet.callPublicFn('oracle-aggregator-v2', 'update-price', [
      asset,
      Cl.uint(110_000),
    ], wallet1);

    // ERR_CIRCUIT_OPEN = (err u105)
    expect(blocked.result).toBeErr(Cl.uint(105));
  });
});
