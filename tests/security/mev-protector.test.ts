import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('MEV Protector', () => {
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

  it('enforces owner-only admin controls for commit/reveal periods and ownership', () => {
    const periodsBefore = simnet.callReadOnlyFn('mev-protector', 'get-periods', [], deployer);
    expect(periodsBefore.result).toBeOk();

    const setCommit = simnet.callPublicFn('mev-protector', 'set-commit-period', [
      Cl.uint(5),
    ], deployer);
    expect(setCommit.result).toBeOk(Cl.bool(true));

    const setReveal = simnet.callPublicFn('mev-protector', 'set-reveal-period', [
      Cl.uint(7),
    ], deployer);
    expect(setReveal.result).toBeOk(Cl.bool(true));

    const transfer = simnet.callPublicFn('mev-protector', 'set-contract-owner', [
      Cl.standardPrincipal(wallet1),
    ], deployer);
    expect(transfer.result).toBeOk(Cl.bool(true));

    const failSet = simnet.callPublicFn('mev-protector', 'set-commit-period', [
      Cl.uint(8),
    ], deployer);
    expect(failSet.result).toBeErr(Cl.uint(4000));

    const successSet = simnet.callPublicFn('mev-protector', 'set-commit-period', [
      Cl.uint(8),
    ], wallet1);
    expect(successSet.result).toBeOk(Cl.bool(true));
  });

  it('reports batch readiness and prevents premature execution', () => {
    const currentBatch = simnet.callReadOnlyFn('mev-protector', 'get-current-batch-id', [], deployer);
    expect(currentBatch.result).toBeOk();

    const batchId = (currentBatch.result as any).value as any;

    const ready = simnet.callReadOnlyFn('mev-protector', 'is-batch-ready', [
      batchId,
    ], deployer);
    expect(ready.result).toBeOk(Cl.bool(false));

    const nonOwnerExec = simnet.callPublicFn('mev-protector', 'execute-batch', [
      batchId,
    ], wallet1);
    expect(nonOwnerExec.result).toBeErr(Cl.uint(4000));

    const ownerExec = simnet.callPublicFn('mev-protector', 'execute-batch', [
      batchId,
    ], deployer);
    expect(ownerExec.result).toBeErr(Cl.uint(4005));
  });
});
