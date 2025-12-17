import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Bond Factory', () => {
  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml');
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), 'Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  it('allows a user to create a bond', () => {
    const bond = simnet.callPublicFn(
      'bond-factory',
      'create-bond',
      [
        Cl.uint(1000000), // principal-amount
        Cl.uint(500), // coupon-rate
        Cl.uint(17280), // maturity-blocks (1 day)
        Cl.uint(1000000), // collateral-amount
        Cl.standardPrincipal(deployer), // collateral-token
        Cl.bool(false), // is-callable
        Cl.uint(0), // call-premium
        Cl.stringAscii('Test Bond'), // name
        Cl.stringAscii('TB'), // symbol
        Cl.uint(6), // decimals
        Cl.uint(1000), // face-value
      ],
      wallet1
    );
    expect(bond.result).toBeOk(
      Cl.tuple({
        'bond-id': Cl.uint(1),
        'bond-contract': Cl.standardPrincipal(wallet1),
        'maturity-block': Cl.uint(17281),
      })
    );
  });

  it('enforces the minimum bond duration', () => {
    const bond = simnet.callPublicFn(
      'bond-factory',
      'create-bond',
      [
        Cl.uint(1000000), // principal-amount
        Cl.uint(500), // coupon-rate
        Cl.uint(719), // maturity-blocks (less than 1 hour)
        Cl.uint(1000000), // collateral-amount
        Cl.standardPrincipal(deployer), // collateral-token
        Cl.bool(false), // is-callable
        Cl.uint(0), // call-premium
        Cl.stringAscii('Test Bond'), // name
        Cl.stringAscii('TB'), // symbol
        Cl.uint(6), // decimals
        Cl.uint(1000), // face-value
      ],
      wallet1
    );
    expect(bond.result).toBeErr(Cl.uint(5001)); // ERR_INVALID_TERMS
  });

  it('enforces the maximum bond duration', () => {
    const bond = simnet.callPublicFn(
      'bond-factory',
      'create-bond',
      [
        Cl.uint(1000000), // principal-amount
        Cl.uint(500), // coupon-rate
        Cl.uint(189216001), // maturity-blocks (more than 30 years)
        Cl.uint(1000000), // collateral-amount
        Cl.standardPrincipal(deployer), // collateral-token
        Cl.bool(false), // is-callable
        Cl.uint(0), // call-premium
        Cl.stringAscii('Test Bond'), // name
        Cl.stringAscii('TB'), // symbol
        Cl.uint(6), // decimals
        Cl.uint(1000), // face-value
      ],
      wallet1
    );
    expect(bond.result).toBeErr(Cl.uint(5001)); // ERR_INVALID_TERMS
  });

  it('enforces the minimum bond amount', () => {
    const bond = simnet.callPublicFn(
      'bond-factory',
      'create-bond',
      [
        Cl.uint(999999), // principal-amount (less than 1,000,000)
        Cl.uint(500), // coupon-rate
        Cl.uint(17280), // maturity-blocks (1 day)
        Cl.uint(1000000), // collateral-amount
        Cl.standardPrincipal(deployer), // collateral-token
        Cl.bool(false), // is-callable
        Cl.uint(0), // call-premium
        Cl.stringAscii('Test Bond'), // name
        Cl.stringAscii('TB'), // symbol
        Cl.uint(6), // decimals
        Cl.uint(1000), // face-value
      ],
      wallet1
    );
    expect(bond.result).toBeErr(Cl.uint(5005)); // ERR_INVALID_AMOUNT
  });
});