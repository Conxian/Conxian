import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';

// NOTE: These tests assume simnet helpers are available in the test environment
// and that Clarinet.toml enables oracle-aggregator-v2.

describe('Lending Capacity Metrics and Breaker-Aware Scenarios', () => {
  const deployer = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
  const user1 = 'ST2REHHS5J3CERCRBEPMGH7921Q6PYKAADT7JP2VB';

  const tokenA = `${deployer}.mock-token-a`;
  const tokenB = `${deployer}.mock-token-b`;
  const aggregator = `${deployer}.oracle-aggregator-v2`;

  beforeEach(() => {
    // risk params: 5% buffer, min HF 1.0 * PRECISION, alert at 95%
    simnet.callPublicFn(
      'comprehensive-lending-system',
      'set-risk-params',
      [Cl.uint(500), Cl.uint(1000000000000000000n), Cl.uint(9500)],
      deployer
    );

    // register tokens as supported assets
    simnet.callPublicFn(
      'comprehensive-lending-system',
      'add-supported-asset',
      [Cl.principal(tokenA), Cl.uint(8000), Cl.uint(8500), Cl.uint(500)],
      deployer
    );
    simnet.callPublicFn(
      'comprehensive-lending-system',
      'add-supported-asset',
      [Cl.principal(tokenB), Cl.uint(6500), Cl.uint(7000), Cl.uint(1000)],
      deployer
    );

    // set aggregator as lending oracle
    simnet.callPublicFn(
      'comprehensive-lending-system',
      'set-oracle',
      [Cl.principal(aggregator)],
      deployer
    );

    // initialize aggregator sources
    simnet.callPublicFn(
      'oracle-aggregator-v2',
      'set-source',
      [Cl.principal(tokenA), Cl.uint(1000000), Cl.uint(10)],
      deployer
    );
    simnet.callPublicFn(
      'oracle-aggregator-v2',
      'set-source',
      [Cl.principal(tokenB), Cl.uint(2500000), Cl.uint(10)],
      deployer
    );
  });

  it('records user capacity metrics after borrow/repay', () => {
    // user supplies tokenB and borrows tokenA
    simnet.callPublicFn(
      'comprehensive-lending-system',
      'supply',
      [Cl.principal(tokenB), Cl.uint(100000000)],
      user1
    );
    simnet.callPublicFn(
      'comprehensive-lending-system',
      'borrow',
      [Cl.principal(tokenA), Cl.uint(10000000)],
      user1
    );

    const metricsAfterBorrow = simnet.callReadOnlyFn(
      'comprehensive-lending-system',
      'compute-user-capacity',
      [Cl.principal(user1)],
      user1
    );
    expect(metricsAfterBorrow.result.type).toBe(2); // ResponseOk

    simnet.callPublicFn(
      'comprehensive-lending-system',
      'repay',
      [Cl.principal(tokenA), Cl.uint(5000000)],
      user1
    );
    const metricsAfterRepay = simnet.callReadOnlyFn(
      'comprehensive-lending-system',
      'compute-user-capacity',
      [Cl.principal(user1)],
      user1
    );
    expect(metricsAfterRepay.result.type).toBe(2); // ResponseOk
  });

  it('degrades to TWAP when stale according to aggregator', () => {
    // set stale threshold small
    simnet.callPublicFn(
      'oracle-aggregator-v2',
      'set-stale-threshold',
      [Cl.uint(5)],
      deployer
    );
    // age the price
    simnet.mineEmptyBlock(6);
    // get price via aggregator get-price (should degrade to TWAP)
    const price = simnet.callReadOnlyFn(
      'oracle-aggregator-v2',
      'get-price',
      [Cl.principal(tokenA)],
      deployer
    );
    expect(price.result.type).toBe(2); // ResponseOk
  });
});