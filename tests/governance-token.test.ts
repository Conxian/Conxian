import { describe, it, expect, beforeAll } from 'vitest';
import { Simnet } from '@hirosystems/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Governance Token (SIP-010-like)', () => {
  const simnet: Simnet = (global as any).simnet;
  let deployer: any;
  let wallet1: any;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer');
    wallet1 = accounts.get('wallet_1');
  });

  it('has metadata and total supply', () => {
    const name = simnet.callReadOnlyFn('governance-token', 'get-name', [], deployer.address);
    expect(name.result).toBeOk(Cl.stringAscii('GovernanceToken'));

    const symbol = simnet.callReadOnlyFn('governance-token', 'get-symbol', [], deployer.address);
    expect(symbol.result).toBeOk(Cl.stringAscii('GOV'));

    const decimals = simnet.callReadOnlyFn('governance-token', 'get-decimals', [], deployer.address);
    expect(decimals.result).toBeOk(Cl.uint(6));

    const totalSupply = simnet.callReadOnlyFn('governance-token', 'get-total-supply', [], deployer.address);
    // Value may change after mint/burn; ensure the call succeeds
    expect(totalSupply.result.type).toBe('ok');
  });

  it('owner can mint and burn', () => {
    const mintAmount = 1000;

    const mint = simnet.callPublicFn(
      'governance-token',
      'mint',
      [Cl.uint(mintAmount), Cl.principal(wallet1.address)],
      deployer.address
    );
    expect(mint.result).toBeOk(Cl.bool(true));

    const bal = simnet.callReadOnlyFn(
      'governance-token',
      'get-balance',
      [Cl.principal(wallet1.address)],
      deployer.address
    );
    expect(bal.result).toBeOk(Cl.uint(mintAmount));

    const burn = simnet.callPublicFn(
      'governance-token',
      'burn',
      [Cl.uint(400), Cl.principal(wallet1.address)],
      deployer.address
    );
    expect(burn.result).toBeOk(Cl.bool(true));

    const bal2 = simnet.callReadOnlyFn(
      'governance-token',
      'get-balance',
      [Cl.principal(wallet1.address)],
      deployer.address
    );
    expect(bal2.result).toBeOk(Cl.uint(600));
  });

  it('non-owner cannot mint', () => {
    const mint = simnet.callPublicFn(
      'governance-token',
      'mint',
      [Cl.uint(1), Cl.principal(wallet1.address)],
      wallet1.address
    );
    // ERR_UNAUTHORIZED is u100 per governance-token.clar
    expect(mint.result).toBeErr(Cl.uint(100));
  });
});
