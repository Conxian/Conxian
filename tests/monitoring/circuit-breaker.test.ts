import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Circuit Breaker', () => {
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

  it('allows admin to open and close the circuit', () => {
    const initial = simnet.callReadOnlyFn('circuit-breaker', 'is-circuit-open', [], deployer);
    expect(initial.result).toBeOk(Cl.bool(false));

    const open = simnet.callPublicFn('circuit-breaker', 'open-circuit', [], deployer);
    expect(open.result).toBeOk(Cl.bool(true));

    const afterOpen = simnet.callReadOnlyFn('circuit-breaker', 'is-circuit-open', [], deployer);
    expect(afterOpen.result).toBeOk(Cl.bool(true));

    const closed = simnet.callPublicFn('circuit-breaker', 'close-circuit', [], deployer);
    expect(closed.result).toBeOk(Cl.bool(true));

    const afterClose = simnet.callReadOnlyFn('circuit-breaker', 'is-circuit-open', [], deployer);
    expect(afterClose.result).toBeOk(Cl.bool(false));
  });

  it('enforces admin authorization for state changes', () => {
    const setAdmin = simnet.callPublicFn('circuit-breaker', 'set-admin', [
      Cl.standardPrincipal(wallet1),
    ], deployer);
    expect(setAdmin.result).toBeOk(Cl.bool(true));

    // Deployer is no longer admin
    const failOpen = simnet.callPublicFn('circuit-breaker', 'open-circuit', [], deployer);
    expect(failOpen.result).toBeErr(Cl.uint(5000));

    // New admin can open the circuit
    const open = simnet.callPublicFn('circuit-breaker', 'open-circuit', [], wallet1);
    expect(open.result).toBeOk(Cl.bool(true));
  });

  it('reports circuit state via check-circuit-state and assert-operational', () => {
    const okState = simnet.callPublicFn('circuit-breaker', 'check-circuit-state', [
      Cl.stringAscii('TEST-SERVICE'),
    ], deployer);
    expect(okState.result).toBeOk(Cl.bool(true));

    const assertOk = simnet.callPublicFn('circuit-breaker', 'assert-operational', [], deployer);
    expect(assertOk.result).toBeOk(Cl.bool(true));

    // Open the circuit
    simnet.callPublicFn('circuit-breaker', 'open-circuit', [], deployer);

    const badState = simnet.callPublicFn('circuit-breaker', 'check-circuit-state', [
      Cl.stringAscii('TEST-SERVICE'),
    ], deployer);
    expect(badState.result).toBeErr(Cl.uint(5007));

    const assertBad = simnet.callPublicFn('circuit-breaker', 'assert-operational', [], deployer);
    expect(assertBad.result).toBeErr(Cl.uint(5007));
  });
});
