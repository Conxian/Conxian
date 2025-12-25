import { describe, it, expect, beforeEach } from 'vitest';
import { Tx, types, Cl } from '@stacks/transactions';

const CONTRACT_NAME = 'conxian-protocol';

describe('Conxian Protocol Core Tests', () => {
  let deployer: any;
  let wallet1: any;
  let wallet2: any;

  beforeEach(() => {
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
      deployer.address
    );
    expect(owner.result).toBePrincipal(deployer.address);
  });

  it('allows the owner to transfer ownership', () => {
    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'transfer-ownership',
        [Cl.principal(wallet1.address)],
        deployer.address
      )
    expect(result).toBeOk(Cl.bool(true));

    const newOwner = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-protocol-owner',
      [],
      deployer.address
    );
    expect(newOwner.result).toBePrincipal(wallet1.address);
  });

  it('prevents non-owners from transferring ownership', () => {
    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'transfer-ownership',
        [Cl.principal(wallet2.address)],
        wallet1.address
      )
    expect(result).toBeErr(Cl.uint(1001));
  });

  it('allows the owner to authorize a contract', () => {
    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'authorize-contract',
        [Cl.principal(wallet1.address), Cl.bool(true)],
        deployer.address
      )
    expect(result).toBeOk(Cl.bool(true));

    const isAuthorized = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'is-authorized',
      [Cl.principal(wallet1.address)],
      deployer.address
    );
    expect(isAuthorized.result).toBeBool(true);
  });

  it('allows the owner to de-authorize a contract', () => {
    simnet.callPublicFn(
        CONTRACT_NAME,
        'authorize-contract',
        [Cl.principal(wallet1.address), Cl.bool(true)],
        deployer.address
      )
    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'authorize-contract',
        [Cl.principal(wallet1.address), Cl.bool(false)],
        deployer.address
      )
    expect(result).toBeOk(Cl.bool(true));

    const isAuthorized = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'is-authorized',
      [Cl.principal(wallet1.address)],
      deployer.address
    );
    expect(isAuthorized.result).toBeBool(false);
  });

  it('prevents a non-owner from authorizing a contract', () => {
    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'authorize-contract',
        [Cl.principal(wallet1.address), Cl.bool(true)],
        wallet1.address
      )
    expect(result).toBeErr(Cl.uint(1001));
  });

  it('allows the owner to pause and unpause the protocol', () => {
    let { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'emergency-pause',
        [Cl.bool(true)],
        deployer.address
      )
    expect(result).toBeOk(Cl.bool(true));

    let isPaused = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-emergency-status',
      [],
      deployer.address
    );
    expect(isPaused.result).toBeBool(true);

    result = simnet.callPublicFn(
        CONTRACT_NAME,
        'emergency-pause',
        [Cl.bool(false)],
        deployer.address
      ).result
    expect(result).toBeOk(Cl.bool(true));

    isPaused = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-emergency-status',
      [],
      deployer.address
    );
    expect(isPaused.result).toBeBool(false);
  });

  it('prevents a non-owner from pausing the protocol', () => {
    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'emergency-pause',
        [Cl.bool(true)],
        wallet1.address
      )
    expect(result).toBeErr(Cl.uint(1001));
  });

  it('allows the owner to update a configuration value', () => {
    const key = Cl.stringAscii('max-slippage');
    const newValue = Cl.uint(2000);

    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'update-protocol-config',
        [key, newValue],
        deployer.address
      )
    expect(result).toBeOk(Cl.bool(true));

    const configValue = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-protocol-config',
      [key],
      deployer.address
    );
    expect(configValue.result).toBeSome(newValue);
  });

  it('prevents a non-owner from updating a configuration value', () => {
    const key = Cl.stringAscii('max-slippage');
    const newValue = Cl.uint(2000);

    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'update-protocol-config',
        [key, newValue],
        wallet1.address
      )
    expect(result).toBeErr(Cl.uint(1001));
  });
});
