import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

// Baseline admin and configuration tests for liquidation-engine.
describe('Liquidation Engine', () => {
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

  it('allows owner to initialize with referenced contracts and rejects non-owner', () => {
    const oracle = Cl.contractPrincipal(deployer, 'oracle-aggregator-v2');
    const risk = Cl.contractPrincipal(deployer, 'risk-manager');
    const dim = Cl.contractPrincipal(deployer, 'dimensional-engine');

    const initByOwner = simnet.callPublicFn('liquidation-engine', 'initialize', [
      Cl.standardPrincipal(deployer),
      oracle,
      risk,
      dim,
      Cl.standardPrincipal(wallet1),
    ], deployer);
    (expect(initByOwner.result) as any).toBeOk(Cl.bool(true));

    const initByNonOwner = simnet.callPublicFn('liquidation-engine', 'initialize', [
      Cl.standardPrincipal(wallet1),
      oracle,
      risk,
      dim,
      Cl.standardPrincipal(wallet1),
    ], wallet1);
    (expect(initByNonOwner.result) as any).toBeErr(Cl.uint(4000));
  });

  it('enforces owner-only updates for referenced contracts', () => {
    const oracle = Cl.contractPrincipal(deployer, 'oracle-aggregator-v2');
    const risk = Cl.contractPrincipal(deployer, 'risk-manager');
    const dim = Cl.contractPrincipal(deployer, 'dimensional-engine');

    simnet.callPublicFn('liquidation-engine', 'initialize', [
      Cl.standardPrincipal(deployer),
      oracle,
      risk,
      dim,
      Cl.standardPrincipal(wallet1),
    ], deployer);

    const setOracleByNonOwner = simnet.callPublicFn(
      'liquidation-engine',
      'set-oracle-contract',
      [oracle],
      wallet1,
    );
    (expect(setOracleByNonOwner.result) as any).toBeErr(Cl.uint(4000));

    const setOracleByOwner = simnet.callPublicFn(
      'liquidation-engine',
      'set-oracle-contract',
      [oracle],
      deployer,
    );
    (expect(setOracleByOwner.result) as any).toBeOk(Cl.bool(true));

    const setRiskByOwner = simnet.callPublicFn(
      'liquidation-engine',
      'set-risk-manager-contract',
      [risk],
      deployer,
    );
    (expect(setRiskByOwner.result) as any).toBeOk(Cl.bool(true));

    const setDimByOwner = simnet.callPublicFn(
      'liquidation-engine',
      'set-dimensional-engine-contract',
      [dim],
      deployer,
    );
    (expect(setDimByOwner.result) as any).toBeOk(Cl.bool(true));
  });

  it('validates liquidation reward range and enforces owner-only access', () => {
    const oracle = Cl.contractPrincipal(deployer, 'oracle-aggregator-v2');
    const risk = Cl.contractPrincipal(deployer, 'risk-manager');
    const dim = Cl.contractPrincipal(deployer, 'dimensional-engine');

    simnet.callPublicFn('liquidation-engine', 'initialize', [
      Cl.standardPrincipal(deployer),
      oracle,
      risk,
      dim,
      Cl.standardPrincipal(wallet1),
    ], deployer);

    const setRewardsByNonOwner = simnet.callPublicFn(
      'liquidation-engine',
      'set-liquidation-rewards',
      [Cl.uint(100), Cl.uint(500)],
      wallet1,
    );
    (expect(setRewardsByNonOwner.result) as any).toBeErr(Cl.uint(4000));

    const invalidRange = simnet.callPublicFn(
      'liquidation-engine',
      'set-liquidation-rewards',
      [Cl.uint(6000), Cl.uint(5000)],
      deployer,
    );
    (expect(invalidRange.result) as any).toBeErr(Cl.uint(4008));

    const validRange = simnet.callPublicFn(
      'liquidation-engine',
      'set-liquidation-rewards',
      [Cl.uint(100), Cl.uint(500)],
      deployer,
    );
    (expect(validRange.result) as any).toBeOk(Cl.bool(true));
  });

  it('enforces owner-only updates for insurance fund', () => {
    const oracle = Cl.contractPrincipal(deployer, 'oracle-aggregator-v2');
    const risk = Cl.contractPrincipal(deployer, 'risk-manager');
    const dim = Cl.contractPrincipal(deployer, 'dimensional-engine');

    simnet.callPublicFn('liquidation-engine', 'initialize', [
      Cl.standardPrincipal(deployer),
      oracle,
      risk,
      dim,
      Cl.standardPrincipal(wallet1),
    ], deployer);

    const setFundByNonOwner = simnet.callPublicFn(
      'liquidation-engine',
      'set-insurance-fund',
      [Cl.standardPrincipal(wallet1)],
      wallet1,
    );
    (expect(setFundByNonOwner.result) as any).toBeErr(Cl.uint(4000));

    const setFundByOwner = simnet.callPublicFn(
      'liquidation-engine',
      'set-insurance-fund',
      [Cl.standardPrincipal(wallet1)],
      deployer,
    );
    (expect(setFundByOwner.result) as any).toBeOk(Cl.bool(true));
  });
});
