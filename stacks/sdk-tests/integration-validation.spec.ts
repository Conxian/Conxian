import {
  describe,
  it,
  expect,
  beforeAll,
  beforeEach,
} from 'vitest';
import type { Simnet } from "@stacks/clarinet-sdk";
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
let wallet2: string;

describe('Integration Testing - Complete System Validation', () => {
  beforeAll(() => {
    simnet = (globalThis as any).simnet as Simnet;
  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
  });

  describe('Token System Integration', () => {
    it('should initialize token system coordinator', () => {
      const receipt = simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      expect(receipt.result).toBeOk(Cl.stringAscii('System initialized with 5 core tokens'));
    });

    it('should register tokens successfully', () => {
      // Initialize system first
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Check if CXD token is registered
      const cxdRegistered = simnet.callReadOnlyFn('token-system-coordinator', 'get-registered-token', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);
      expect(cxdRegistered.result).toBeSome(Cl.bool(true));
    });

    it('should coordinate multi-token operations', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Test multi-token operation coordination
      const receipt = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token'), Cl.contractPrincipal(deployer, 'cxvg-token')]),
        Cl.stringAscii('yield-claim'),
        Cl.uint(1000000)
      ], deployer);

      expect(receipt.result).toBeOk(Cl.uint(1)); // Should return operation ID
    });
  });

  describe('Revenue Distribution Integration', () => {
    it('should distribute revenue correctly', () => {
      // Initialize token system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Set treasury and insurance addresses
      simnet.callPublicFn('revenue-distributor', 'set-treasury-address', [Cl.standardPrincipal(wallet1)], deployer);
      simnet.callPublicFn('revenue-distributor', 'set-insurance-address', [Cl.standardPrincipal(wallet2)], deployer);

      // Test revenue distribution
      const receipt = simnet.callPublicFn('revenue-distributor', 'distribute-revenue', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(1000000)
      ], deployer);

      expect(receipt.result).toBeOk(Cl.uint(1)); // Should return distribution ID
    });

    it('should register and update fee sources', () => {
      const receipt1 = simnet.callPublicFn('revenue-distributor', 'register-fee-source', [
        Cl.stringAscii('dex-fees'),
        Cl.contractPrincipal(deployer, 'dex-pool'),
        Cl.uint(100)
      ], deployer);

      expect(receipt1.result).toBeOk(Cl.bool(true));

      const receipt2 = simnet.callPublicFn('revenue-distributor', 'update-fee-source', [
        Cl.stringAscii('dex-fees'),
        Cl.bool(true),
        Cl.uint(150)
      ], deployer);

      expect(receipt2.result).toBeOk(Cl.bool(true));
    });
  });

  describe('CXD Staking Integration', () => {
    it('should distribute revenue to stakers', () => {
      // First set up the CXD token contract reference in staking
      simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);

      // Distribute revenue
      const receipt = simnet.callPublicFn('cxd-staking', 'distribute-revenue', [
        Cl.uint(1000000),
        Cl.contractPrincipal(deployer, 'cxd-token')
      ], deployer);

      expect(receipt.result).toBeOk(Cl.bool(true));
    });

    it('should handle staking workflow correctly', () => {
      // Set CXD contract reference
      simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);

      // Test initiate stake
      const stakeReceipt = simnet.callPublicFn('cxd-staking', 'initiate-stake', [Cl.uint(1000000)], wallet1);
      expect(stakeReceipt.result).toBeOk(Cl.bool(true));

      // Check pending stake
      const pendingStake = simnet.callReadOnlyFn('cxd-staking', 'get-pending-stake', [Cl.standardPrincipal(wallet1)], wallet1);
      expect(pendingStake.result).toBeSome(Cl.tuple({
        amount: Cl.uint(1000000),
        'created-at': Cl.uint(1) // block height
      }));
    });
  });

  describe('Cross-Contract Communication', () => {
    it('should handle emergency coordination', () => {
      // Test emergency pause
      const pauseReceipt = simnet.callPublicFn('token-system-coordinator', 'emergency-pause-system', [], deployer);
      expect(pauseReceipt.result).toBeOk(Cl.bool(true));

      // Check if paused
      const isPaused = simnet.callReadOnlyFn('token-system-coordinator', 'is-paused', [], deployer);
      expect(isPaused.result).toBeOk(Cl.bool(true));

      // Test emergency resume
      const resumeReceipt = simnet.callPublicFn('token-system-coordinator', 'emergency-resume-system', [], deployer);
      expect(resumeReceipt.result).toBeOk(Cl.bool(true));
    });

    it('should provide system health status', () => {
      const health = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      expect(health.result).toBeOk(Cl.tuple({
        'is-paused': Cl.bool(false),
        'emergency-mode': Cl.bool(false),
        'total-registered-tokens': Cl.uint(5),
        'total-users': Cl.uint(0),
        'coordinator-version': Cl.stringAscii('1.0.0')
      }));
    });
  });

  describe('End-to-End Workflow', () => {
    it('should handle complete revenue flow', () => {
      // 1. Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // 2. Set up revenue distributor
      simnet.callPublicFn('revenue-distributor', 'set-treasury-address', [Cl.standardPrincipal(wallet1)], deployer);
      simnet.callPublicFn('revenue-distributor', 'set-insurance-address', [Cl.standardPrincipal(wallet2)], deployer);

      // 3. Set up CXD staking
      simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);

      // 4. Coordinate multi-token operation
      const coordReceipt = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
        Cl.stringAscii('yield-claim'),
        Cl.uint(1000000)
      ], deployer);

      expect(coordReceipt.result).toBeOk(Cl.uint(1));

      // 5. Trigger revenue distribution
      const distReceipt = simnet.callPublicFn('token-system-coordinator', 'trigger-revenue-distribution', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(1000000)
      ], deployer);

      expect(distReceipt.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Error Handling', () => {
    it('should handle unauthorized access correctly', () => {
      const receipt = simnet.callPublicFn('token-system-coordinator', 'register-token', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.stringAscii('CXD'),
        Cl.uint(6)
      ], wallet1); // wallet1 trying to register token

      expect(receipt.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED
    });

    it('should handle invalid tokens correctly', () => {
      const receipt = simnet.callPublicFn('token-system-coordinator', 'update-token-activity', [
        Cl.contractPrincipal(deployer, 'nonexistent-token'),
        Cl.uint(1000000)
      ], deployer);

      expect(receipt.result).toBeErr(Cl.uint(101)); // ERR_INVALID_TOKEN
    });
  });

  describe('Performance and Scalability', () => {
    it('should handle multiple users efficiently', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Simulate multiple users
      for (let i = 0; i < 5; i++) {
        const user = `wallet_${i + 1}` as keyof typeof simnet.getAccounts;
        const userAddr = simnet.getAccounts().get(user)!;

        const receipt = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
          Cl.standardPrincipal(userAddr),
          Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
          Cl.stringAscii('yield-claim'),
          Cl.uint(1000000)
        ], deployer);

        expect(receipt.result).toBeOk(Cl.uint(i + 1));
      }

      // Check system health
      const health = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      expect(health.result).toBeOk(Cl.tuple({
        'is-paused': Cl.bool(false),
        'emergency-mode': Cl.bool(false),
        'total-registered-tokens': Cl.uint(5),
        'total-users': Cl.uint(5),
        'coordinator-version': Cl.stringAscii('1.0.0')
      }));
    });
  });
});
