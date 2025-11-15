import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';

// NOTE: These tests assume simnet helpers are available in the test environment

describe('Concentrated Liquidity Pool Tests', () => {
  const deployer = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
  const tokenA = `${deployer}.token-a`;
  const tokenB = `${deployer}.token-b`;

  beforeEach(() => {
    // any setup needed before each test
  });

  it('initializes the pool', () => {
    const block = simnet.mineBlock([
      {
        contract: 'concentrated-liquidity-pool',
        fun: 'initialize',
        args: [Cl.uint(100), Cl.principal(tokenA), Cl.principal(tokenB)],
        sender: deployer,
      },
    ]);
    expect(block.receipts[0].result).toBeOk(Cl.bool(true));
  });

  it('sets the fee', () => {
    const block = simnet.mineBlock([
      {
        contract: 'concentrated-liquidity-pool',
        fun: 'set-fee',
        args: [Cl.uint(50)],
        sender: deployer,
      },
    ]);
    expect(block.receipts[0].result).toBeOk(Cl.bool(true));

    const fee = simnet.callReadOnlyFn(
      'concentrated-liquidity-pool',
      'get-fee-rate',
      [],
      deployer
    );
    expect(fee.result).toBeOk(Cl.uint(50));
  });

  it('adds liquidity and gets the position', () => {
    const positionId = Cl.bufferFromAscii('position-1');
    const lowerTick = Cl.int(-100);
    const upperTick = Cl.int(100);
    const amount = Cl.uint(1000);

    const block = simnet.mineBlock([
      {
        contract: 'concentrated-liquidity-pool',
        fun: 'add-liquidity',
        args: [positionId, lowerTick, upperTick, amount],
        sender: deployer,
      },
    ]);
    expect(block.receipts[0].result).toBeOk(
      Cl.tuple({
        shares: Cl.uint(1000),
      })
    );

    const position = simnet.callReadOnlyFn(
      'concentrated-liquidity-pool',
      'get-position',
      [positionId],
      deployer
    );
    expect(position.result).toBeOk(
      Cl.tuple({
        lower: Cl.int(-100),
        upper: Cl.int(100),
        shares: Cl.uint(1000),
      })
    );
  });
});
