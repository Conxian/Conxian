// @ts-nocheck
import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Conxian Operations Engine', () => {
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

  it('exposes basic ops dashboard and config', () => {
    const config = simnet.callReadOnlyFn(
      'conxian-operations-engine',
      'get-config',
      [],
      deployer,
    );
    expect((config.result as any)).toBeOk();

    const ops = simnet.callReadOnlyFn(
      'conxian-operations-engine',
      'get-ops-dashboard',
      [],
      deployer,
    );
    expect((ops.result as any)).toBeOk();
  });

  it('wires lending, MEV, insurance, and bridge systems and exposes user dashboards', () => {
    const lendingPrincipal = Cl.contractPrincipal(
      deployer,
      'comprehensive-lending-system',
    );
    const mevPrincipal = Cl.contractPrincipal(deployer, 'mev-protection-nft');
    const insurancePrincipal = Cl.contractPrincipal(
      deployer,
      'insurance-protection-nft',
    );
    const bridgePrincipal = Cl.contractPrincipal(deployer, 'bridge-nft');

    const setLending = simnet.callPublicFn(
      'conxian-operations-engine',
      'set-lending-system',
      [lendingPrincipal],
      deployer,
    );
    expect((setLending.result as any)).toBeOk(Cl.bool(true));

    const setMev = simnet.callPublicFn(
      'conxian-operations-engine',
      'set-mev-system',
      [mevPrincipal],
      deployer,
    );
    expect((setMev.result as any)).toBeOk(Cl.bool(true));

    const setInsurance = simnet.callPublicFn(
      'conxian-operations-engine',
      'set-insurance-system',
      [insurancePrincipal],
      deployer,
    );
    expect((setInsurance.result as any)).toBeOk(Cl.bool(true));

    const setBridge = simnet.callPublicFn(
      'conxian-operations-engine',
      'set-bridge-system',
      [bridgePrincipal],
      deployer,
    );
    expect((setBridge.result as any)).toBeOk(Cl.bool(true));

    const hf = simnet.callPublicFn(
      'conxian-operations-engine',
      'get-user-lending-health',
      [Cl.standardPrincipal(wallet1)],
      deployer,
    );
    expect((hf.result as any)).toBeOk(Cl.uint(20000));

    const mevDashboard = simnet.callPublicFn(
      'conxian-operations-engine',
      'get-user-mev-dashboard',
      [Cl.standardPrincipal(wallet1)],
      deployer,
    );
    expect((mevDashboard.result as any)).toBeOk();

    const insuranceDashboard = simnet.callPublicFn(
      'conxian-operations-engine',
      'get-user-insurance-dashboard',
      [Cl.standardPrincipal(wallet1)],
      deployer,
    );
    expect((insuranceDashboard.result as any)).toBeOk();

    const bridgeDashboard = simnet.callPublicFn(
      'conxian-operations-engine',
      'get-user-bridge-dashboard',
      [Cl.standardPrincipal(wallet1)],
      deployer,
    );
    expect((bridgeDashboard.result as any)).toBeOk();
  });

  it('exposes emission governance dashboard when emission controller is configured', () => {
    const emissionController = Cl.contractPrincipal(
      deployer,
      'token-emission-controller',
    );

    const setEmission = simnet.callPublicFn(
      'conxian-operations-engine',
      'set-emission-controller',
      [emissionController],
      deployer,
    );
    expect((setEmission.result as any)).toBeOk(Cl.bool(true));

    const dash = simnet.callPublicFn(
      'conxian-operations-engine',
      'get-emission-governance-dashboard',
      [Cl.contractPrincipal(deployer, 'cxd-token')],
      deployer,
    );
    expect((dash.result as any)).toBeOk();
  });
});
