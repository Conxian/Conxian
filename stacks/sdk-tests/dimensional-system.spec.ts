import {
  describe,
  it,
  expect,
  beforeAll,
  beforeEach,
} from 'vitest';
import type { Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

// Augment Vitest expect with clarinet-sdk custom matchers used in these tests
declare module 'vitest' {
  interface Assertion<T = any> {
    toBeOk(expected?: any): any;
    toBeErr(expected?: any): any;
    toBeSome(expected?: any): any;
  }
}

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Dimensional DeFi System', () => {
  beforeAll(() => {
    // Use the global simnet initialized in setup (managed by clarinet-sdk vitest helpers)
    simnet = (globalThis as any).simnet as Simnet;
  });

  beforeEach(() => {
    // Ensure accounts are read after the session has been initialized
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  describe('dim-registry', () => {
    it('should allow deployer to register a new dimension', () => {
      const receipt = simnet.callPublicFn('dim-registry', 'register-dimension', [Cl.uint(1), Cl.uint(100)], deployer);
      expect(receipt.result).toBeOk(Cl.uint(1));
    });

    it('should not allow non-deployer to register a new dimension', () => {
        const receipt = simnet.callPublicFn('dim-registry', 'register-dimension', [Cl.uint(2), Cl.uint(100)], wallet1);
        expect(receipt.result).toBeErr(Cl.uint(101)); // err-unauthorized
    });

    it('should not allow registering the same dimension twice', () => {
        simnet.callPublicFn('dim-registry', 'register-dimension', [Cl.uint(3), Cl.uint(100)], deployer);
        const receipt = simnet.callPublicFn('dim-registry', 'register-dimension', [Cl.uint(3), Cl.uint(100)], deployer);
        expect(receipt.result).toBeErr(Cl.uint(103)); // err-dimension-already-registered
    });

    it('should allow deployer to update weight', () => {
        simnet.callPublicFn('dim-registry', 'register-dimension', [Cl.uint(4), Cl.uint(100)], deployer);
        const receipt = simnet.callPublicFn('dim-registry', 'update-weight', [Cl.uint(4), Cl.uint(200)], deployer);
        expect(receipt.result).toBeOk(Cl.uint(200));
    });

    it('should not allow non-deployer to update weight', () => {
        simnet.callPublicFn('dim-registry', 'register-dimension', [Cl.uint(5), Cl.uint(100)], deployer);
        const receipt = simnet.callPublicFn('dim-registry', 'update-weight', [Cl.uint(5), Cl.uint(200)], wallet1);
        expect(receipt.result).toBeErr(Cl.uint(101)); // err-unauthorized
    });

    it('should return the correct dimension by id', () => {
        simnet.callPublicFn('dim-registry', 'register-dimension', [Cl.uint(6), Cl.uint(150)], deployer);
        const dim = simnet.callReadOnlyFn('dim-registry', 'get-dimension-weight', [Cl.uint(6)], deployer);
        expect(dim.result).toBeSome(Cl.tuple({ weight: Cl.uint(150) }));
    });

    it('should return the correct weight', () => {
        simnet.callPublicFn('dim-registry', 'register-dimension', [Cl.uint(7), Cl.uint(120)], deployer);
        const weight = simnet.callReadOnlyFn('dim-registry', 'get-dimension-weight', [Cl.uint(7)], deployer);
        expect(weight.result).toBeSome(Cl.tuple({ weight: Cl.uint(120) }));
    });
  });

  describe('tokenized-bond', () => {
    it('should allow deployer to issue a new bond', () => {
        const receipt = simnet.callPublicFn('tokenized-bond', 'issue-bond', [
            Cl.stringAscii('Bond A'),
            Cl.stringAscii('BND'),
            Cl.uint(6),
            Cl.uint(1_000_000),
            Cl.uint(100),
            Cl.uint(500),
            Cl.uint(5),
            Cl.uint(100),
            Cl.contractPrincipal(deployer, 'mock-token'),
        ], deployer);
        expect(receipt.result).toBeOk(Cl.bool(true));
    });

    it('should allow users to get bond details', () => {
        const total = simnet.callReadOnlyFn('tokenized-bond', 'get-total-supply', [], deployer);
        expect(total.result).toBeOk(Cl.uint(1_000_000));
    });

    it('should expose payment token contract principal', () => {
      const pt = simnet.callReadOnlyFn('tokenized-bond', 'get-payment-token-contract', [], deployer);
      expect(pt.result).toBeOk(Cl.some(Cl.contractPrincipal(deployer, 'mock-token')));
    });

    it('should allow wallet1 to claim coupons after periods elapse', () => {
      // Transfer some bond tokens to wallet1 so they have a balance
      const xfer = simnet.callPublicFn(
        'tokenized-bond',
        'transfer',
        [
          Cl.uint(1_000),
          Cl.standardPrincipal(deployer),
          Cl.standardPrincipal(wallet1),
          Cl.none(),
        ],
        deployer
      );
      expect(xfer.result).toBeOk(Cl.bool(true));

      // Advance multiple coupon periods (coupon frequency is 5 blocks)
      for (let i = 0; i < 10; i++) simnet.mineBlock([]);

      const receipt = simnet.callPublicFn(
        'tokenized-bond',
        'claim-coupons',
        [Cl.contractPrincipal(deployer, 'mock-token')],
        wallet1
      );

      // Given the current parameters, the integer math yields 0 coupon
      expect(receipt.result).toBeOk(Cl.uint(0));
    });

    it('should allow wallet1 to redeem at maturity and burn tokens', () => {
      // Mine enough blocks to reach maturity (maturity-in-blocks was 100)
      for (let i = 0; i < 110; i++) simnet.mineBlock([]);

      const receipt = simnet.callPublicFn(
        'tokenized-bond',
        'redeem-at-maturity',
        [Cl.contractPrincipal(deployer, 'mock-token')],
        wallet1
      );

      // Principal = balance(1_000) * face-value(100) = 100_000; coupon remains 0 in this setup
      expect(receipt.result).toBeOk(
        Cl.tuple({ principal: Cl.uint(100_000), coupon: Cl.uint(0) })
      );

      // Balance should be burned to 0 for wallet1
      const balAfter = simnet.callReadOnlyFn(
        'tokenized-bond',
        'get-balance',
        [Cl.standardPrincipal(wallet1)],
        wallet1
      );
      expect(balAfter.result).toBeOk(Cl.uint(0));

      // Total supply decreased by 1_000
      const totalAfter = simnet.callReadOnlyFn('tokenized-bond', 'get-total-supply', [], deployer);
      expect(totalAfter.result).toBeOk(Cl.uint(999_000));
    });
  });
});
