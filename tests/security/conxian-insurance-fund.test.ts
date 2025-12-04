import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

const stakingToken = () => Cl.contractPrincipal(deployer, 'cxd-token');

describe('Conxian Insurance Fund', () => {
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

  it('allows governance to configure staking token and users to stake', () => {
    const setToken = simnet.callPublicFn('conxian-insurance-fund', 'set-staking-token', [
      stakingToken(),
    ], deployer);
    expect(setToken.result).toBeOk(Cl.bool(true));

    // Mint staking tokens to wallet1 so staking transfer succeeds
    const mint = simnet.callPublicFn(
      "cxd-token",
      "mint",
      [Cl.principal(wallet1), Cl.uint(1_000_000)],
      deployer
    );
    expect(mint.result).toBeOk(Cl.bool(true));

    const stake = simnet.callPublicFn('conxian-insurance-fund', 'stake', [
      Cl.uint(500_000),
      stakingToken(),
    ], wallet1);
    expect(stake.result).toBeOk(Cl.bool(true));

    const total = simnet.callReadOnlyFn('conxian-insurance-fund', 'get-total-assets', [], deployer);
    expect(total.result).toBeOk(Cl.uint(500_000));
  });

  it('requires cooldown before unstaking and enforces governance-only ops', () => {
    const setToken = simnet.callPublicFn('conxian-insurance-fund', 'set-staking-token', [
      stakingToken(),
    ], deployer);
    expect(setToken.result).toBeOk(Cl.bool(true));

    const mint = simnet.callPublicFn(
      "cxd-token",
      "mint",
      [Cl.principal(wallet1), Cl.uint(1_000_000)],
      deployer
    );
    expect(mint.result).toBeOk(Cl.bool(true));

    const stake = simnet.callPublicFn('conxian-insurance-fund', 'stake', [
      Cl.uint(500_000),
      stakingToken(),
    ], wallet1);
    expect(stake.result).toBeOk(Cl.bool(true));

    // Unstake without cooldown should fail with ERR_NO_COOLDOWN (u5004)
    const unstakeNoCooldown = simnet.callPublicFn('conxian-insurance-fund', 'unstake', [
      Cl.uint(100_000),
      stakingToken(),
    ], wallet1);
    expect(unstakeNoCooldown.result).toBeErr(Cl.uint(5004));

    const cd = simnet.callPublicFn('conxian-insurance-fund', 'initiate-cooldown', [], wallet1);
    expect(cd.result).toBeOk();

    // governance-withdraw cannot withdraw the staking token
    const gw = simnet.callPublicFn('conxian-insurance-fund', 'governance-withdraw', [
      Cl.uint(0),
      stakingToken(),
      Cl.standardPrincipal(wallet1),
    ], deployer);
    expect(gw.result).toBeErr(Cl.uint(5000));
  });
});
