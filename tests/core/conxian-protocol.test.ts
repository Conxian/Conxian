import { describe, it, expect, beforeEach } from 'vitest';
import { Tx, Chain, Account, types, Simnet } from '@stacks/clarinet-sdk';

const CONTRACT_NAME = 'conxian-protocol';

describe('Conxian Protocol Core Tests', () => {
  let simnet: Simnet;
  let chain: Chain;
  let deployer: Account;
  let wallet1: Account;
  let wallet2: Account;

  beforeEach(() => {
    // @ts-ignore
    simnet = global.simnet;
    chain = simnet.getChain();
    deployer = simnet.getAccounts().get('deployer')!;
    wallet1 = simnet.getAccounts().get('wallet_1')!;
    wallet2 = simnet.getAccounts().get('wallet_2')!;
  });

  it('should have a valid deployer', () => {
    expect(deployer).toBeDefined();
  });

  it('ensures the protocol owner is the deployer upon initialization', () => {
    const owner = chain.callReadOnlyFn(
      CONTRACT_NAME,
      'get-protocol-owner',
      [],
      deployer.address
    );
    expect(owner.result).toBe(deployer.address);
  });

  it('allows the owner to transfer ownership', () => {
    const { result } = chain.submitTransaction(
      Tx.contractCall(
        CONTRACT_NAME,
        'transfer-ownership',
        [types.principal(wallet1.address)],
        deployer.address
      )
    );
    expect(result).toBeOk(types.bool(true));

    const newOwner = chain.callReadOnlyFn(
      CONTRACT_NAME,
      'get-protocol-owner',
      [],
      deployer.address
    );
    expect(newOwner.result).toBe(wallet1.address);
  });

  it('prevents non-owners from transferring ownership', () => {
    const { result } = chain.submitTransaction(
      Tx.contractCall(
        CONTRACT_NAME,
        'transfer-ownership',
        [types.principal(wallet2.address)],
        wallet1.address
      )
    );
    expect(result).toBeErr(types.uint(1001));
  });

  it('allows the owner to authorize a contract', () => {
    const { result } = chain.submitTransaction(
      Tx.contractCall(
        CONTRACT_NAME,
        'authorize-contract',
        [types.principal(wallet1.address), types.bool(true)],
        deployer.address
      )
    );
    expect(result).toBeOk(types.bool(true));

    const isAuthorized = chain.callReadOnlyFn(
      CONTRACT_NAME,
      'is-authorized',
      [types.principal(wallet1.address)],
      deployer.address
    );
    expect(isAuthorized.result).toBe(types.bool(true));
  });

  it('allows the owner to de-authorize a contract', () => {
    chain.submitTransaction(
      Tx.contractCall(
        CONTRACT_NAME,
        'authorize-contract',
        [types.principal(wallet1.address), types.bool(true)],
        deployer.address
      )
    );
    const { result } = chain.submitTransaction(
      Tx.contractCall(
        CONTRACT_NAME,
        'authorize-contract',
        [types.principal(wallet1.address), types.bool(false)],
        deployer.address
      )
    );
    expect(result).toBeOk(types.bool(true));

    const isAuthorized = chain.callReadOnlyFn(
      CONTRACT_NAME,
      'is-authorized',
      [types.principal(wallet1.address)],
      deployer.address
    );
    expect(isAuthorized.result).toBe(types.bool(false));
  });

  it('prevents a non-owner from authorizing a contract', () => {
    const { result } = chain.submitTransaction(
      Tx.contractCall(
        CONTRACT_NAME,
        'authorize-contract',
        [types.principal(wallet1.address), types.bool(true)],
        wallet1.address
      )
    );
    expect(result).toBeErr(types.uint(1001));
  });

  it('allows the owner to pause and unpause the protocol', () => {
    let { result } = chain.submitTransaction(
      Tx.contractCall(
        CONTRACT_NAME,
        'emergency-pause',
        [types.bool(true)],
        deployer.address
      )
    );
    expect(result).toBeOk(types.bool(true));

    let isPaused = chain.callReadOnlyFn(
      CONTRACT_NAME,
      'get-emergency-status',
      [],
      deployer.address
    );
    expect(isPaused.result).toBe(types.bool(true));

    result = chain.submitTransaction(
      Tx.contractCall(
        CONTRACT_NAME,
        'emergency-pause',
        [types.bool(false)],
        deployer.address
      )
    ).result;
    expect(result).toBeOk(types.bool(true));

    isPaused = chain.callReadOnlyFn(
      CONTRACT_NAME,
      'get-emergency-status',
      [],
      deployer.address
    );
    expect(isPaused.result).toBe(types.bool(false));
  });

  it('prevents a non-owner from pausing the protocol', () => {
    const { result } = chain.submitTransaction(
      Tx.contractCall(
        CONTRACT_NAME,
        'emergency-pause',
        [types.bool(true)],
        wallet1.address
      )
    );
    expect(result).toBeErr(types.uint(1001));
  });

  it('allows the owner to update a configuration value', () => {
    const key = types.ascii('max-slippage');
    const newValue = types.uint(2000);

    const { result } = chain.submitTransaction(
      Tx.contractCall(
        CONTRACT_NAME,
        'update-protocol-config',
        [key, newValue],
        deployer.address
      )
    );
    expect(result).toBeOk(types.bool(true));

    const configValue = chain.callReadOnlyFn(
      CONTRACT_NAME,
      'get-protocol-config',
      [key],
      deployer.address
    );
    expect(configValue.result).toBeSome(newValue);
  });

  it('prevents a non-owner from updating a configuration value', () => {
    const key = types.ascii('max-slippage');
    const newValue = types.uint(2000);

    const { result } = chain.submitTransaction(
      Tx.contractCall(
        CONTRACT_NAME,
        'update-protocol-config',
        [key, newValue],
        wallet1.address
      )
    );
    expect(result).toBeErr(types.uint(1001));
  });
});
