import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl, ClarityType } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('sBTC Vault', () => {
  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml');
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), 'Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  it('allows owner to pause and unpause the vault', () => {
    const pause = simnet.callPublicFn('sbtc-vault', 'set-vault-paused', [
      Cl.bool(true),
    ], deployer);
    expect(pause.result).toEqual(Cl.ok(Cl.bool(true)));

    const unpause = simnet.callPublicFn('sbtc-vault', 'set-vault-paused', [
      Cl.bool(false),
    ], deployer);
    expect(unpause.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('exposes vault stats with a paused flag that tracks admin setting', () => {
    // Ensure paused = true
    simnet.callPublicFn('sbtc-vault', 'set-vault-paused', [Cl.bool(true)], deployer);

    const stats = simnet.callReadOnlyFn('sbtc-vault', 'get-vault-stats', [], deployer);

    expect(stats.result).toEqual(Cl.ok(
      Cl.tuple({
        'total-sbtc': Cl.uint(0),
        'total-shares': Cl.uint(0),
        'total-yield': Cl.uint(0),
        'share-price': Cl.uint(100_000_000),
        paused: Cl.bool(true),
      }),
    ));
  });

  it('allows a user to deposit sBTC', () => {
    const deposit = simnet.callPublicFn(
      'sbtc-vault',
      'sbtc-deposit',
      [Cl.uint(1000)],
      wallet1
    );
    expect(deposit.result).toEqual(Cl.ok(Cl.uint(1000)));
  });

  it('allows a user to withdraw sBTC', () => {
    simnet.callPublicFn(
      'sbtc-vault',
      'sbtc-deposit',
      [Cl.uint(1000)],
      wallet1
    );

    const withdraw = simnet.callPublicFn(
      'sbtc-vault',
      'sbtc-withdraw',
      [Cl.uint(500)],
      wallet1
    );
    expect(withdraw.result).toEqual(Cl.ok(Cl.uint(500)));
  });

  it('prevents a user from withdrawing more sBTC than they have deposited', () => {
    simnet.callPublicFn(
      'sbtc-vault',
      'sbtc-deposit',
      [Cl.uint(1000)],
      wallet1
    );

    const withdraw = simnet.callPublicFn(
      'sbtc-vault',
      'sbtc-withdraw',
      [Cl.uint(2000)],
      wallet1
    );
    expect(withdraw.result).toEqual(Cl.err(Cl.uint(1))); // Assuming error code 1 for insufficient funds
  });

  it('charges a fee on deposit', () => {
    const deposit = simnet.callPublicFn(
      'sbtc-vault',
      'sbtc-deposit',
      [Cl.uint(1000)],
      wallet1
    );

    // Assuming a 1% fee, the user should have 990 sBTC in the vault
    const stats = simnet.callReadOnlyFn('sbtc-vault', 'get-vault-stats', [], wallet1);
    expect(stats.result).toEqual(Cl.ok(
      Cl.tuple({
        'total-sbtc': Cl.uint(990),
        'total-shares': Cl.uint(990),
        'total-yield': Cl.uint(0),
        'share-price': Cl.uint(100_000_000),
        paused: Cl.bool(false),
      }),
    ));
  });

  it('charges a fee on withdrawal', () => {
    simnet.callPublicFn(
      'sbtc-vault',
      'sbtc-deposit',
      [Cl.uint(1000)],
      wallet1
    );

    const withdraw = simnet.callPublicFn(
      'sbtc-vault',
      'sbtc-withdraw',
      [Cl.uint(500)],
      wallet1
    );

    // Assuming a 1% fee on withdrawal, the user should receive 495 sBTC
    const sbtcToken = simnet.getAssetsMap().get('sbtc-token.sBTC');
    const balance = sbtcToken?.get(wallet1);
    expect(balance).toEqual(100000000000000 - 1000 + 495);
  });
});