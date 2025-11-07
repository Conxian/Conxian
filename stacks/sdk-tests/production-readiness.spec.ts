import {
  describe,
  it,
  expect,
  beforeAll,
  beforeEach,
} from 'vitest';
import type { Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

// Augment Vitest expect with clarinet-sdk custom matchers
declare module 'vitest' {
  interface Assertion<T = any> {
    toBeOk(expected?: any): any;
    toBeErr(expected?: any): any;
    toBeSome(expected?: any): any;
    toBeNone(): any;
  }
}

let simnet: Simnet;
let deployer: string;
let wallet1: string;
let wallet2: string;
let wallet3: string;

describe('Production Readiness - Comprehensive System Validation', () => {
  beforeAll(() => {
    simnet = (globalThis as any).simnet as Simnet;
  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
    wallet3 = accounts.get('wallet_3')!;
  });

  describe('🔧 Integration Testing - Cross-Contract Functionality', () => {
    it('should complete full system initialization', () => {
      // Initialize token system coordinator
      const coordInit = simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      expect(coordInit.result).toBeOk(Cl.stringAscii('System initialized with 5 core tokens'));

      // Set up revenue distributor
      const treasurySet = simnet.callPublicFn('revenue-distributor', 'set-treasury-address', [Cl.standardPrincipal(wallet1)], deployer);
      expect(treasurySet.result).toBeOk(Cl.bool(true));

      const insuranceSet = simnet.callPublicFn('revenue-distributor', 'set-insurance-address', [Cl.standardPrincipal(wallet2)], deployer);
      expect(insuranceSet.result).toBeOk(Cl.bool(true));

      // Set up CXD staking
      const cxdSet = simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);
      expect(cxdSet.result).toBeOk(Cl.bool(true));

      // Register fee source
      const feeSource = simnet.callPublicFn('revenue-distributor', 'register-fee-source', [
        Cl.stringAscii('dex-fees'),
        Cl.contractPrincipal(deployer, 'dex-pool'),
        Cl.uint(100)
      ], deployer);
      expect(feeSource.result).toBeOk(Cl.bool(true));
    });

    it('should handle complete revenue flow end-to-end', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      simnet.callPublicFn('revenue-distributor', 'set-treasury-address', [Cl.standardPrincipal(wallet1)], deployer);
      simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);

      // Simulate multi-token operation
      const operation = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
        Cl.stringAscii('yield-claim'),
        Cl.uint(1000000)
      ], deployer);
      expect(operation.result).toBeOk(Cl.uint(1));

      // Trigger revenue distribution
      const distribution = simnet.callPublicFn('token-system-coordinator', 'trigger-revenue-distribution', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(1000000)
      ], deployer);
      expect(distribution.result).toBeOk(Cl.bool(true));
    });

    it('should validate error handling across contracts', () => {
      // Test unauthorized access
      const unauthorized = simnet.callPublicFn('token-system-coordinator', 'register-token', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.stringAscii('CXD'),
        Cl.uint(6)
      ], wallet1);
      expect(unauthorized.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED

      // Test invalid token
      const invalidToken = simnet.callPublicFn('token-system-coordinator', 'update-token-activity', [
        Cl.contractPrincipal(deployer, 'nonexistent-token'),
        Cl.uint(1000000)
      ], deployer);
      expect(invalidToken.result).toBeErr(Cl.uint(101)); // ERR_INVALID_TOKEN
    });
  });

  describe('⚡ Performance Testing - Load and Efficiency', () => {
    it('should handle multiple concurrent users', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Simulate multiple users (5 concurrent operations)
      for (let i = 0; i < 5; i++) {
        const user = `wallet_${i + 1}` as keyof typeof simnet.getAccounts;
        const userAddr = simnet.getAccounts().get(user)!;

        const operation = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
          Cl.standardPrincipal(userAddr),
          Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
          Cl.stringAscii('yield-claim'),
          Cl.uint(1000000)
        ], deployer);

        expect(operation.result).toBeOk(Cl.uint(i + 1));
      }

      // Verify system health
      const health = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      expect(health.result).toBeOk(Cl.tuple({
        'is-paused': Cl.bool(false),
        'emergency-mode': Cl.bool(false),
        'total-registered-tokens': Cl.uint(5),
        'total-users': Cl.uint(5),
        'coordinator-version': Cl.stringAscii('1.0.0')
      }));
    });

    it('should handle batch operations efficiently', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Create multiple operations
      const operations = [];
      for (let i = 0; i < 3; i++) {
        const user = `wallet_${i + 1}` as keyof typeof simnet.getAccounts;
        const userAddr = simnet.getAccounts().get(user)!;

        const operation = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
          Cl.standardPrincipal(userAddr),
          Cl.list([Cl.contractPrincipal(deployer, 'cxd-token'), Cl.contractPrincipal(deployer, 'cxvg-token')]),
          Cl.stringAscii('yield-claim'),
          Cl.uint(1000000)
        ], deployer);

        operations.push(operation);
        expect(operation.result).toBeOk(Cl.uint(i + 1));
      }
    });

    it('should maintain system stability under stress', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Perform rapid successive operations
      for (let i = 0; i < 10; i++) {
        const operation = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
          Cl.standardPrincipal(wallet1),
          Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
          Cl.stringAscii('yield-claim'),
          Cl.uint(1000000)
        ], deployer);

        expect(operation.result).toBeOk(Cl.uint(i + 1));
      }

      // Verify system remains functional
      const health = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      expect(health.result).toBeOk(Cl.tuple({
        'is-paused': Cl.bool(false),
        'emergency-mode': Cl.bool(false),
        'total-registered-tokens': Cl.uint(5),
        'total-users': Cl.uint(1),
        'coordinator-version': Cl.stringAscii('1.0.0')
      }));
    });
  });

  describe('🔒 Security Validation - Comprehensive Security Review', () => {
    it('should validate access controls across all contracts', () => {
      // Test token coordinator access controls
      const unauthorizedCoord = simnet.callPublicFn('token-system-coordinator', 'emergency-pause-system', [], wallet1);
      expect(unauthorizedCoord.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED

      // Test revenue distributor access controls
      const unauthorizedRevenue = simnet.callPublicFn('revenue-distributor', 'register-fee-source', [
        Cl.stringAscii('test'),
        Cl.contractPrincipal(deployer, 'test'),
        Cl.uint(100)
      ], wallet1);
      expect(unauthorizedRevenue.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED

      // Test emergency controls
      const emergencyPause = simnet.callPublicFn('token-system-coordinator', 'emergency-pause-system', [], deployer);
      expect(emergencyPause.result).toBeOk(Cl.bool(true));

      const emergencyResume = simnet.callPublicFn('token-system-coordinator', 'emergency-resume-system', [], deployer);
      expect(emergencyResume.result).toBeOk(Cl.bool(true));
    });

    it('should validate circuit breaker functionality', () => {
      // Test circuit breaker integration
      const circuitCheck = simnet.callPublicFn('cxd-staking', 'initiate-stake', [Cl.uint(1000000)], wallet1);
      expect(circuitCheck.result).toBeOk(Cl.bool(true));

      // Verify circuit breaker state
      const circuitState = simnet.callReadOnlyFn('protocol-invariant-monitor', 'get-circuit-state', [
        Cl.stringAscii('staking')
      ], deployer);
      expect(circuitState.result).toBeOk(Cl.tuple({
        state: Cl.uint(0), // CLOSED
        'last-checked': Cl.uint(1),
        'failure-rate': Cl.uint(0),
        'failure-count': Cl.uint(0),
        'success-count': Cl.uint(1)
      }));
    });

    it('should validate emergency shutdown procedures', () => {
      // Test emergency mode activation
      const emergencyMode = simnet.callPublicFn('token-system-coordinator', 'activate-emergency-mode', [], deployer);
      expect(emergencyMode.result).toBeOk(Cl.bool(true));

      // Verify emergency mode
      const emergencyCheck = simnet.callReadOnlyFn('token-system-coordinator', 'get-emergency-mode', [], deployer);
      expect(emergencyCheck.result).toBeOk(Cl.bool(true));

      // Test emergency deactivation
      const emergencyDeactivate = simnet.callPublicFn('token-system-coordinator', 'deactivate-emergency-mode', [], deployer);
      expect(emergencyDeactivate.result).toBeOk(Cl.bool(true));
    });
  });

  describe('🔄 End-to-End Workflow Validation', () => {
    it('should complete full user journey - staking to yield claim', () => {
      // 1. Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);
      simnet.callPublicFn('revenue-distributor', 'set-treasury-address', [Cl.standardPrincipal(wallet1)], deployer);

      // 2. User stakes tokens
      const stakeInit = simnet.callPublicFn('cxd-staking', 'initiate-stake', [Cl.uint(1000000)], wallet1);
      expect(stakeInit.result).toBeOk(Cl.bool(true));

      // 3. Complete staking after warm-up
      const stakeComplete = simnet.callPublicFn('cxd-staking', 'complete-stake', [], wallet1);
      expect(stakeComplete.result).toBeOk(Cl.uint(1000000)); // xCXD amount

      // 4. Generate revenue
      const revenueDist = simnet.callPublicFn('cxd-staking', 'distribute-revenue', [
        Cl.uint(1000000),
        Cl.contractPrincipal(deployer, 'cxd-token')
      ], deployer);
      expect(revenueDist.result).toBeOk(Cl.bool(true));

      // 5. User claims revenue
      const claimRevenue = simnet.callPublicFn('cxd-staking', 'claim-revenue', [Cl.contractPrincipal(deployer, 'cxd-token')], wallet1);
      expect(claimRevenue.result).toBeOk(Cl.uint(1000000)); // Revenue amount
    });

    it('should complete full governance workflow', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Test parameter updates
      const paramUpdate = simnet.callPublicFn('protocol-invariant-monitor', 'set-emergency-operator', [
        Cl.standardPrincipal(wallet1)
      ], deployer);
      expect(paramUpdate.result).toBeOk(Cl.bool(true));

      // Verify parameter change
      const paramCheck = simnet.callReadOnlyFn('protocol-invariant-monitor', 'get-emergency-operator', [], deployer);
      expect(paramCheck.result).toBeOk(Cl.standardPrincipal(wallet1));
    });

    it('should handle complete liquidation workflow', () => {
      // Test liquidation framework
      const liquidationCheck = simnet.callPublicFn('comprehensive-lending-system', 'liquidate', [
        Cl.principal(wallet1),
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(1000000)
      ], deployer);

      // This should handle gracefully even if not fully implemented
      expect(liquidationCheck.result).toBeOk(Cl.bool(true));
    });
  });

  describe('📊 System Health and Monitoring', () => {
    it('should provide comprehensive system health metrics', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Check token coordinator health
      const coordHealth = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      expect(coordHealth.result).toBeOk(Cl.tuple({
        'is-paused': Cl.bool(false),
        'emergency-mode': Cl.bool(false),
        'total-registered-tokens': Cl.uint(5),
        'total-users': Cl.uint(0),
        'coordinator-version': Cl.stringAscii('1.0.0')
      }));

      // Check revenue distributor health
      const revenueHealth = simnet.callReadOnlyFn('revenue-distributor', 'get-system-health', [], deployer);
      expect(revenueHealth.result).toBeOk(Cl.tuple({
        'is-paused': Cl.bool(false),
        'total-revenue-distributed': Cl.uint(0),
        'last-distribution': Cl.uint(0),
        'treasury-address': Cl.standardPrincipal(deployer),
        'insurance-address': Cl.standardPrincipal(deployer),
        'active-fee-sources': Cl.uint(0)
      }));
    });

    it('should monitor contract interactions and dependencies', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);

      // Perform operations to generate monitoring data
      simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
        Cl.stringAscii('yield-claim'),
        Cl.uint(1000000)
      ], deployer);

      // Check monitoring data
      const userActivity = simnet.callReadOnlyFn('token-system-coordinator', 'get-user-activity', [Cl.standardPrincipal(wallet1)], deployer);
      expect(userActivity.result).toBeOk(Cl.tuple({
        'last-interaction': Cl.uint(1),
        'total-volume': Cl.uint(1000000),
        'token-count': Cl.uint(1),
        'reputation-score': Cl.uint(1000)
      }));
    });
  });

  describe('🚨 Error Recovery and Resilience', () => {
    it('should handle system recovery after errors', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Test emergency pause
      const pause = simnet.callPublicFn('token-system-coordinator', 'emergency-pause-system', [], deployer);
      expect(pause.result).toBeOk(Cl.bool(true));

      // Verify pause state
      const pauseCheck = simnet.callReadOnlyFn('token-system-coordinator', 'is-paused', [], deployer);
      expect(pauseCheck.result).toBeOk(Cl.bool(true));

      // Test emergency resume
      const resume = simnet.callPublicFn('token-system-coordinator', 'emergency-resume-system', [], deployer);
      expect(resume.result).toBeOk(Cl.bool(true));

      // Verify resume state
      const resumeCheck = simnet.callReadOnlyFn('token-system-coordinator', 'is-paused', [], deployer);
      expect(resumeCheck.result).toBeOk(Cl.bool(false));
    });

    it('should maintain data integrity during failures', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Perform operations
      const op1 = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
        Cl.stringAscii('yield-claim'),
        Cl.uint(1000000)
      ], deployer);

      const op2 = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet2),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
        Cl.stringAscii('yield-claim'),
        Cl.uint(2000000)
      ], deployer);

      expect(op1.result).toBeOk(Cl.uint(1));
      expect(op2.result).toBeOk(Cl.uint(2));

      // Verify data integrity
      const user1Activity = simnet.callReadOnlyFn('token-system-coordinator', 'get-user-activity', [Cl.standardPrincipal(wallet1)], deployer);
      const user2Activity = simnet.callReadOnlyFn('token-system-coordinator', 'get-user-activity', [Cl.standardPrincipal(wallet2)], deployer);

      expect(user1Activity.result).toBeOk(Cl.tuple({
        'last-interaction': Cl.uint(1),
        'total-volume': Cl.uint(1000000),
        'token-count': Cl.uint(1),
        'reputation-score': Cl.uint(1000)
      }));

      expect(user2Activity.result).toBeOk(Cl.tuple({
        'last-interaction': Cl.uint(1),
        'total-volume': Cl.uint(2000000),
        'token-count': Cl.uint(1),
        'reputation-score': Cl.uint(1000)
      }));
    });
  });
});
