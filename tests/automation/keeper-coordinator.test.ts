import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

// Basic tests for keeper-coordinator to ensure keeper registration and
// batch execution entrypoints work with the current stub implementation.
describe('Keeper Coordinator', () => {
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

  it('allows owner to register a keeper', () => {
    const res = simnet.callPublicFn('keeper-coordinator', 'register-keeper', [
      Cl.standardPrincipal(wallet1),
    ], deployer);

    expect(res.result).toBeOk(Cl.bool(true));
  });

  it('allows a registered keeper to execute a batch (stubbed)', () => {
    // First register wallet1 as a keeper
    simnet.callPublicFn('keeper-coordinator', 'register-keeper', [
      Cl.standardPrincipal(wallet1),
    ], deployer);

    const exec = simnet.callPublicFn('keeper-coordinator', 'execute-batch-tasks', [], wallet1);

    // We only assert that the call succeeds and returns an Ok tuple
    expect(exec.result).toBeOk();
  });
});
