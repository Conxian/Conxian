import { Cl, ClarityType, ClarityValue, ResponseOk, ResponseError, principalCV } from '@stacks/transactions';
import { describe, expect, it, beforeEach, run } from '@stacks/clarigen/sdk';
import { simnet } from '../.stacks/Clarigen';
import { expectOk, expectErr, simnet } from '@stacks/clarigen';

describe('Oracle Contract Tests', () => {
  const { oracle } = simnet.getDeployedContractIds();
  const admin = simnet.deployer;
  const user1 = simnet.accounts.get('wallet_1')!;
  
  // Test token for price feeds
  const testToken = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
  
  beforeEach(() => {
    // Reset the simnet before each test
    simnet.mineEmptyBlock(0);
  });

  describe('Admin Functions', () => {
    it('should set admin on deploy', () => {
      const adminResponse = simnet.callReadOnlyFn(
        'oracle',
        'get-admin',
        [],
        admin
      );
      expect(adminResponse).toBeOk(Cl.principal(admin));
    });

    it('should allow admin to set price', () => {
      const price = 1000000; // $1.00 with 6 decimals
      const setPrice = simnet.callPublicFn(
        'oracle',
        'set-price',
        [Cl.principal(testToken), Cl.uint(price)],
        admin
      );
      expect(setPrice).toBeOk(Cl.bool(true));

      // Verify price was set
      const getPrice = simnet.callReadOnlyFn(
        'oracle',
        'get-price',
        [Cl.principal(testToken)],
        admin
      );
      expect(getPrice).toBeOk(Cl.uint(price));
    });

    it('should prevent non-admin from setting price', () => {
      const setPrice = simnet.callPublicFn(
        'oracle',
        'set-price',
        [Cl.principal(testToken), Cl.uint(1000000)],
        user1
      );
      expect(setPrice).toBeErr(Cl.uint(1001)); // ERR_UNAUTHORIZED
    });
  });

  describe('Price Freshness', () => {
    it('should detect fresh prices', () => {
      const price = 1000000;
      simnet.callPublicFn(
        'oracle',
        'set-price',
        [Cl.principal(testToken), Cl.uint(price)],
        admin
      );

      const isFresh = simnet.callReadOnlyFn(
        'oracle',
        'is-price-fresh',
        [Cl.principal(testToken)],
        admin
      );
      expect(isFresh).toBeOk(Cl.bool(true));
    });

    it('should detect stale prices', () => {
      const price = 1000000;
      simnet.callPublicFn(
        'oracle',
        'set-price',
        [Cl.principal(testToken), Cl.uint(price)],
        admin
      );

      // Mine blocks to make price stale (assuming 1 block per 2 seconds)
      const staleThreshold = 24 * 60 * 30; // 24 hours in blocks (30 blocks per minute)
      simnet.mineEmptyBlock(staleThreshold + 1);

      const isFresh = simnet.callReadOnlyFn(
        'oracle',
        'is-price-fresh',
        [Cl.principal(testToken)],
        admin
      );
      expect(isFresh).toBeOk(Cl.bool(false));
    });
  });

  describe('Oracle Integration', () => {
    it('should allow setting oracle contract', () => {
      const newOracle = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5.oracle-v2';
      const setOracle = simnet.callPublicFn(
        'oracle',
        'set-oracle-contract',
        [Cl.principal(newOracle)],
        admin
      );
      expect(setOracle).toBeOk(Cl.bool(true));

      const getOracle = simnet.callReadOnlyFn(
        'oracle',
        'get-oracle-contract',
        [],
        admin
      );
      expect(getOracle).toBeOk(Cl.some(Cl.principal(newOracle)));
    });
  });

  describe('Price Freezing', () => {
    it('should allow admin to freeze and unfreeze prices', () => {
      const price = 1000000;
      simnet.callPublicFn(
        'oracle',
        'set-price',
        [Cl.principal(testToken), Cl.uint(price)],
        admin
      );

      // Freeze price
      const freeze = simnet.callPublicFn(
        'oracle',
        'freeze-price',
        [Cl.principal(testToken)],
        admin
      );
      expect(freeze).toBeOk(Cl.bool(true));

      // Try to update frozen price (should fail)
      const updateFrozen = simnet.callPublicFn(
        'oracle',
        'set-price',
        [Cl.principal(testToken), Cl.uint(2000000)],
        admin
      );
      expect(updateFrozen).toBeErr(Cl.uint(1005)); // ERR_PRICE_FROZEN

      // Unfreeze price
      const unfreeze = simnet.callPublicFn(
        'oracle',
        'unfreeze-price',
        [Cl.principal(testToken)],
        admin
      );
      expect(unfreeze).toBeOk(Cl.bool(true));

      // Update should now succeed
      const updateUnfrozen = simnet.callPublicFn(
        'oracle',
        'set-price',
        [Cl.principal(testToken), Cl.uint(2000000)],
        admin
      );
      expect(updateUnfrozen).toBeOk(Cl.bool(true));
    });
  });
});

// Run the tests
run();
