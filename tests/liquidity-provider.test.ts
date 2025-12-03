import { describe, it, expect } from 'vitest';
import { Cl } from '@stacks/transactions';

describe('liquidity-provider', () => {
  let deployer: any;
  let wallet1: any;
  let simnet: any;

  beforeAll(() => {
    simnet = (global as any).simnet;
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer');
    wallet1 = accounts.get('wallet_1') || { address: 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5' };
  });

  it('create-pool succeeds', () => {
    const { result } = simnet.callPublicFn('liquidity-provider', 'create-pool', [
      Cl.contractPrincipal(deployer.address, 'token-x'),
      Cl.contractPrincipal(deployer.address, 'token-y'),
      Cl.contractPrincipal(deployer.address, 'lp-token'),
      Cl.uint(100)
    ], deployer.address);
    expect(result).toBeOk(Cl.uint(0));
  });

  it('create-pool fails if not authorized', () => {
    const { result } = simnet.callPublicFn('liquidity-provider', 'create-pool', [
      Cl.contractPrincipal(wallet1.address, 'token-x'),
      Cl.contractPrincipal(wallet1.address, 'token-y'),
      Cl.contractPrincipal(wallet1.address, 'lp-token'),
      Cl.uint(100)
    ], wallet1.address);
    expect(result).toBeErr(Cl.uint(1000));
  });

  it('add-liquidity succeeds', () => {
    // Create pool first
    simnet.callPublicFn('liquidity-provider', 'create-pool', [
      Cl.contractPrincipal(deployer.address, 'token-x'),
      Cl.contractPrincipal(deployer.address, 'token-y'),
      Cl.contractPrincipal(deployer.address, 'lp-token'),
      Cl.uint(100)
    ], deployer.address);

    const { result } = simnet.callPublicFn('liquidity-provider', 'add-liquidity', [
      Cl.uint(0),
      Cl.uint(1000),
      Cl.uint(1000)
    ], deployer.address);
    expect(result).toBeOk(Cl.bool(true));
  });
});
