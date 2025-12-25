import { describe, it, expect, beforeEach } from 'vitest';
import { Tx, types, Cl } from '@stacks/transactions';
import { initSimnet } from "@stacks/clarinet-sdk";
import { resolve } from "path";

const CONTRACT_NAME = 'conxian-protocol';

describe('Conxian Protocol Core Tests', () => {
  let simnet: any;
  let deployer: any;
  let wallet1: any;
  let wallet2: any;

  beforeEach(async () => {
    const manifestPath = resolve(__dirname, '../../stacks/Clarinet.test.toml');
    simnet = await initSimnet(manifestPath);
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
  });

  it('should have a valid deployer', () => {
    expect(deployer).toBeDefined();
  });

  it('ensures the protocol owner is the deployer upon initialization', () => {
    const owner = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-protocol-owner',
      [],
      deployer
    );
    expect(owner.result).toEqual(Cl.principal(deployer));
  });

  it('allows the owner to transfer ownership', () => {
    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'transfer-ownership',
        [Cl.principal(wallet1)],
        deployer
      )
    expect(result).toEqual(Cl.ok(Cl.bool(true)));

    const newOwner = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-protocol-owner',
      [],
      deployer
    );
    expect(newOwner.result).toEqual(Cl.principal(wallet1));
  });

  it('prevents non-owners from transferring ownership', () => {
    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'transfer-ownership',
        [Cl.principal(wallet2)],
        wallet1
      )
    expect(result).toEqual(Cl.error(Cl.uint(1001)));
  });

  it('allows the owner to authorize a contract', () => {
    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'authorize-contract',
        [Cl.principal(wallet1), Cl.bool(true)],
        deployer
      )
    expect(result).toEqual(Cl.ok(Cl.bool(true)));

    const isAuthorized = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'is-authorized',
      [Cl.principal(wallet1)],
      deployer
    );
    expect(isAuthorized.result).toEqual(Cl.bool(true));
  });

  it('allows the owner to de-authorize a contract', () => {
    simnet.callPublicFn(
        CONTRACT_NAME,
        'authorize-contract',
        [Cl.principal(wallet1), Cl.bool(true)],
        deployer
      )
    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'authorize-contract',
        [Cl.principal(wallet1), Cl.bool(false)],
        deployer
      )
    expect(result).toEqual(Cl.ok(Cl.bool(true)));

    const isAuthorized = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'is-authorized',
      [Cl.principal(wallet1)],
      deployer
    );
    expect(isAuthorized.result).toEqual(Cl.bool(false));
  });

  it('prevents a non-owner from authorizing a contract', () => {
    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'authorize-contract',
        [Cl.principal(wallet1), Cl.bool(true)],
        wallet1
      )
    expect(result).toEqual(Cl.error(Cl.uint(1001)));
  });

  it('allows the owner to pause and unpause the protocol', () => {
    let { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'emergency-pause',
        [Cl.bool(true)],
        deployer
      )
    expect(result).toEqual(Cl.ok(Cl.bool(true)));

    let isPaused = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-emergency-status',
      [],
      deployer
    );
    expect(isPaused.result).toEqual(Cl.bool(true));

    result = simnet.callPublicFn(
        CONTRACT_NAME,
        'emergency-pause',
        [Cl.bool(false)],
        deployer
      ).result
    expect(result).toEqual(Cl.ok(Cl.bool(true)));

    isPaused = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-emergency-status',
      [],
      deployer
    );
    expect(isPaused.result).toEqual(Cl.bool(false));
  });

  it('prevents a non-owner from pausing the protocol', () => {
    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'emergency-pause',
        [Cl.bool(true)],
        wallet1
      )
    expect(result).toEqual(Cl.error(Cl.uint(1001)));
  });

  it('allows the owner to update a configuration value', () => {
    const key = Cl.stringAscii('max-slippage');
    const newValue = Cl.uint(2000);

    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'update-protocol-config',
        [key, newValue],
        deployer
      )
    expect(result).toEqual(Cl.ok(Cl.bool(true)));

    const configValue = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-protocol-config',
      [key],
      deployer
    );
    expect(configValue.result).toEqual(Cl.some(newValue));
  });

  it('prevents a non-owner from updating a configuration value', () => {
    const key = Cl.stringAscii('max-slippage');
    const newValue = Cl.uint(2000);

    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'update-protocol-config',
        [key, newValue],
        wallet1
      )
    expect(result).toEqual(Cl.error(Cl.uint(1001)));
  });
});
