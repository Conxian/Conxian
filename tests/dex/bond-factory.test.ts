import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';

// NOTE: These tests assume simnet helpers are available in the test environment

describe('Bond Factory Tests', () => {
  const deployer = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
  const user = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
  const collateralToken = 'ST000000000000000000002AMW42H';

  beforeEach(() => {
    // any setup needed before each test
  });

  it('creates a bond with valid parameters', () => {
    const block = simnet.mineBlock([
      {
        contract: 'bond-factory',
        fun: 'create-bond',
        args: [
          Cl.principal(user), // issuer
          Cl.uint(1000), // principal-amount
          Cl.uint(5), // coupon-rate
          Cl.uint(100), // issue-block
          Cl.uint(200), // maturity-blocks
          Cl.uint(1500), // collateral-amount
          Cl.principal(collateralToken), // collateral-token
          Cl.bool(true), // is-callable
          Cl.uint(10), // call-premium
          Cl.stringAscii('Test Bond'), // name
          Cl.stringAscii('TBOND'), // symbol
          Cl.uint(6), // decimals
          Cl.uint(1000), // face-value
        ],
        sender: deployer,
      },
    ]);
    expect(block.receipts[0].result).toBeOk(Cl.principal(`${deployer}.bond-0`));
  });
});
