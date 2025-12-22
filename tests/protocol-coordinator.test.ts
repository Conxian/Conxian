import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, Simnet } from '@stacks/clarinet-sdk';
import { Cl, cvToValue } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Protocol Coordinator', () => {
  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml');
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), 'Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  it('allows a user to purchase a genesis node', async () => {
    // Arrange
    simnet.callPublicFn('yield-token', 'set-minter', [Cl.contractPrincipal(deployer, 'protocol-coordinator')], deployer);
    simnet.callPublicFn('protocol-coordinator', 'set-token-contracts', [Cl.contractPrincipal(deployer, 'yield-token'), Cl.contractPrincipal(deployer, 'governance-token')], deployer);
    simnet.callPublicFn('protocol-coordinator', 'toggle-genesis-sale', [Cl.bool(true)], deployer);

    // Act
    const { result } = simnet.callPublicFn('protocol-coordinator', 'purchase-genesis-node', [], wallet1);

    // Assert
    expect(result).toBeOk(Cl.bool(true));
    const yieldBalance = simnet.callReadOnlyFn('yield-token', 'get-balance', [Cl.principal(wallet1)], deployer);
    expect(yieldBalance.result).toBeOk(Cl.uint(1000000000));
  });

  it('allows a user to deposit liquidity and get a multiplier', async () => {
    // Arrange
    const sixMonthLock = 259200;

    // Act
    const { result } = simnet.callPublicFn('protocol-coordinator', 'deposit-liquidity', [Cl.uint(1000000), Cl.uint(sixMonthLock)], wallet1);

    // Assert
    expect(result).toBeOk(Cl.bool(true));
    const deposit = simnet.callReadOnlyFn('protocol-coordinator', 'get-liquidity-deposit', [Cl.principal(wallet1)], deployer);
    expect(deposit.result).toBeSome(Cl.tuple({
      'stx-amount': Cl.uint(1000000),
      'start-height': Cl.uint(2),
      'lock-period': Cl.uint(sixMonthLock),
      'multiplier': Cl.uint(150),
      'last-claim-height': Cl.uint(2)
    }));
  });

  it('allows yield rewards to be claimed', async () => {
    // Arrange
    const sixMonthLock = 259200;
    simnet.callPublicFn('yield-token', 'set-minter', [Cl.contractPrincipal(deployer, 'protocol-coordinator')], deployer);
    simnet.callPublicFn('protocol-coordinator', 'set-token-contracts', [Cl.contractPrincipal(deployer, 'yield-token'), Cl.contractPrincipal(deployer, 'governance-token')], deployer);
    simnet.callPublicFn('protocol-coordinator', 'deposit-liquidity', [Cl.uint(1000000), Cl.uint(sixMonthLock)], wallet1);

    // Act
    const { result } = simnet.callPublicFn('protocol-coordinator', 'claim-rewards', [], wallet1);

    // Assert
    expect(result).toBeOk(Cl.bool(true));
    const yieldBalance = simnet.callReadOnlyFn('yield-token', 'get-balance', [Cl.principal(wallet1)], deployer);
    expect(yieldBalance.result).toBeOk(Cl.uint(15)); // 1 block passed * 10 yield/block * 1.5 multiplier
  });

  it('allows a user to convert yield to governance tokens', async () => {
    // Arrange
    simnet.callPublicFn('yield-token', 'set-minter', [Cl.contractPrincipal(deployer, 'protocol-coordinator')], deployer);
    simnet.callPublicFn('governance-token', 'set-minter', [Cl.contractPrincipal(deployer, 'protocol-coordinator')], deployer);
    simnet.callPublicFn('protocol-coordinator', 'set-token-contracts', [Cl.contractPrincipal(deployer, 'yield-token'), Cl.contractPrincipal(deployer, 'governance-token')], deployer);
    simnet.callPublicFn('protocol-coordinator', 'mint-yield-tokens', [Cl.uint(1000), Cl.principal(wallet1)], deployer);

    // Act
    const { result } = simnet.callPublicFn('protocol-coordinator', 'convert-yield-to-governance', [Cl.uint(1000), Cl.bool(false)], wallet1);

    // Assert
    expect(result).toBeOk(Cl.bool(true));
    const govBalance = simnet.callReadOnlyFn('governance-token', 'get-balance', [Cl.principal(wallet1)], deployer);
    expect(govBalance.result).toBeOk(Cl.uint(500));
  });
});
