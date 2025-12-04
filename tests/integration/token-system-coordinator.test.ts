import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;
let wallet2: string;

describe('Token System Coordinator Integration', () => {
  beforeAll(async () => {
    // Initialize Clarinet simnet directly for this test suite
    simnet = await initSimnet('Clarinet.toml', false, {
      trackCosts: false,
      trackCoverage: false,
    });
  });

  beforeEach(async () => {
    // Reset session before each test to ensure isolation
    await simnet.initSession(process.cwd(), 'Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
  });

  it('initializes system and marks core tokens as registered', () => {
    const init = simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
    expect(init.result).toBeOk(Cl.stringAscii('System initialized with 5 core tokens'));

    const cxdRegistered = simnet.callReadOnlyFn(
      'token-system-coordinator',
      'get-registered-token',
      [Cl.contractPrincipal(deployer, 'cxd-token')],
      deployer,
    );
    expect(cxdRegistered.result).toBeSome(Cl.bool(true));

    const cxvgRegistered = simnet.callReadOnlyFn(
      'token-system-coordinator',
      'get-registered-token',
      [Cl.contractPrincipal(deployer, 'cxvg-token')],
      deployer,
    );
    expect(cxvgRegistered.result).toBeSome(Cl.bool(true));

    const cxlpRegistered = simnet.callReadOnlyFn(
      'token-system-coordinator',
      'get-registered-token',
      [Cl.contractPrincipal(deployer, 'cxlp-token')],
      deployer,
    );
    expect(cxlpRegistered.result).toBeSome(Cl.bool(true));

    const cxtrRegistered = simnet.callReadOnlyFn(
      'token-system-coordinator',
      'get-registered-token',
      [Cl.contractPrincipal(deployer, 'cxtr-token')],
      deployer,
    );
    expect(cxtrRegistered.result).toBeSome(Cl.bool(true));
  });

  it('coordinates multi-token operation and tracks user activity', () => {
    simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

    const op = simnet.callPublicFn(
      'token-system-coordinator',
      'coordinate-multi-token-operation',
      [
        Cl.standardPrincipal(wallet1),
        Cl.list([
          Cl.contractPrincipal(deployer, 'cxd-token'),
          Cl.contractPrincipal(deployer, 'cxvg-token'),
        ]),
        Cl.stringAscii('yield-claim'),
        Cl.uint(1_000_000),
      ],
      deployer,
    );

    expect(op.result).toBeOk();

    const activity = simnet.callReadOnlyFn(
      'token-system-coordinator',
      'get-user-activity',
      [Cl.standardPrincipal(wallet1)],
      deployer,
    );
    expect(activity.result).toBeSome();
  });

  it('enforces authorization on register-token', () => {
    const res = simnet.callPublicFn(
      'token-system-coordinator',
      'register-token',
      [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.stringAscii('CXD'),
        Cl.uint(6),
      ],
      wallet1,
    );

    expect(res.result).toBeErr(Cl.uint(1001));
  });

  it('supports emergency pause and resume', () => {
    simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

    const pause = simnet.callPublicFn(
      'token-system-coordinator',
      'emergency-pause-system',
      [],
      deployer,
    );
    expect(pause.result).toBeOk(Cl.bool(true));

    const paused = simnet.callReadOnlyFn('token-system-coordinator', 'is-paused', [], deployer);
    expect(paused.result).toEqual(Cl.bool(true));

    const resume = simnet.callPublicFn(
      'token-system-coordinator',
      'emergency-resume-system',
      [],
      deployer,
    );
    expect(resume.result).toBeOk(Cl.bool(true));

    const pausedAfter = simnet.callReadOnlyFn('token-system-coordinator', 'is-paused', [], deployer);
    expect(pausedAfter.result).toEqual(Cl.bool(false));
  });
});
