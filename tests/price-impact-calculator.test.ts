import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';

describe('price-impact-calculator', () => {
  let deployer: any;
  let wallet1: any;
  let simnet: any;

  beforeAll(() => {
    simnet = (global as any).simnet;
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer');
    wallet1 = accounts.get('wallet_1') || { address: 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5' };
  });

  it('update-reserves succeeds', () => {
    const { result } = simnet.callPublicFn('price-impact-calculator', 'update-reserves', [
      Cl.uint(0),
      Cl.uint(100000),
      Cl.uint(100000)
    ], deployer.address);
    expect(result).toBeOk(Cl.bool(true));
  });

  it('update-reserves fails if not authorized', () => {
    const { result } = simnet.callPublicFn('price-impact-calculator', 'update-reserves', [
      Cl.uint(0),
      Cl.uint(100000),
      Cl.uint(100000)
    ], wallet1.address);
    expect(result).toBeErr(Cl.uint(1000));
  });

  it('calculate-impact-buy-x succeeds', () => {
    // Update reserves first
    simnet.callPublicFn('price-impact-calculator', 'update-reserves', [
      Cl.uint(0),
      Cl.uint(100000),
      Cl.uint(100000)
    ], deployer.address);

    const { result } = simnet.callReadOnlyFn('price-impact-calculator', 'calculate-impact-buy-x', [
      Cl.uint(1000)
    ], deployer.address);
    expect(result).toBeOk(Cl.uint(1));
  });
});
