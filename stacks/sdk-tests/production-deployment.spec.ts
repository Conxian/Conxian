import {
  describe,
  it,
  expect,
  beforeAll,
  beforeEach,
} from 'vitest';
import type { Simnet } from '@hirosystems/clarinet-sdk';
import { Cl } from '@stacks/transactions';

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

describe('Production Deployment - Mainnet Readiness Validation', () => {
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

  describe('🏭 Production Configuration Validation', () => {
    it('should validate all contract dependencies are properly configured', () => {
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

      // Register fee sources
      const feeSource1 = simnet.callPublicFn('revenue-distributor', 'register-fee-source', [
        Cl.stringAscii('dex-fees'),
        Cl.contractPrincipal(deployer, 'dex-pool'),
        Cl.uint(100)
      ], deployer);
      expect(feeSource1.result).toBeOk(Cl.bool(true));

      const feeSource2 = simnet.callPublicFn('revenue-distributor', 'register-fee-source', [
        Cl.stringAscii('lending-fees'),
        Cl.contractPrincipal(deployer, 'comprehensive-lending-system'),
        Cl.uint(150)
      ], deployer);
      expect(feeSource2.result).toBeOk(Cl.bool(true));
    });

    it('should validate production parameter settings', () => {
      // Test production-ready parameter configurations
      const paramCheck1 = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      expect(paramCheck1.result).toBeOk(Cl.tuple({
        'is-paused': Cl.bool(false),
        'emergency-mode': Cl.bool(false),
        'total-registered-tokens': Cl.uint(5),
        'total-users': Cl.uint(0),
        'coordinator-version': Cl.stringAscii('1.0.0')
      }));

      const paramCheck2 = simnet.callReadOnlyFn('revenue-distributor', 'get-system-health', [], deployer);
      expect(paramCheck2.result).toBeOk(Cl.tuple({
        'is-paused': Cl.bool(false),
        'total-revenue-distributed': Cl.uint(0),
        'last-distribution': Cl.uint(0),
        'treasury-address': Cl.standardPrincipal(deployer),
        'insurance-address': Cl.standardPrincipal(deployer),
        'active-fee-sources': Cl.uint(0)
      }));
    });

    it('should validate emergency controls are properly configured', () => {
      // Test emergency operator setup
      const setEmergencyOp = simnet.callPublicFn('protocol-invariant-monitor', 'set-emergency-operator', [
        Cl.standardPrincipal(wallet3)
      ], deployer);
      expect(setEmergencyOp.result).toBeOk(Cl.bool(true));

      // Verify emergency operator is set
      const emergencyOpCheck = simnet.callReadOnlyFn('protocol-invariant-monitor', 'get-emergency-operator', [], deployer);
      expect(emergencyOpCheck.result).toBeOk(Cl.standardPrincipal(wallet3));

      // Test emergency shutdown capability
      const emergencyShutdown = simnet.callPublicFn('protocol-invariant-monitor', 'emergency-shutdown', [], wallet3);
      expect(emergencyShutdown.result).toBeOk(Cl.bool(true));

      // Verify emergency state
      const emergencyState = simnet.callReadOnlyFn('protocol-invariant-monitor', 'get-circuit-state', [
        Cl.stringAscii('emergency')
      ], deployer);
      expect(emergencyState.result).toBeOk(Cl.tuple({
        state: Cl.uint(2), // OPEN
        'last-checked': Cl.uint(1),
        'failure-rate': Cl.uint(100000),
        'failure-count': Cl.uint(1),
        'success-count': Cl.uint(0)
      }));
    });
  });

  describe('📊 Production Monitoring Setup', () => {
    it('should validate comprehensive monitoring is available', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Test monitoring endpoints
      const coordHealth = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      const revenueHealth = simnet.callReadOnlyFn('revenue-distributor', 'get-system-health', [], deployer);
      const stakingHealth = simnet.callReadOnlyFn('cxd-staking', 'get-protocol-info', [], deployer);

      expect(coordHealth.result).toBeOk();
      expect(revenueHealth.result).toBeOk();
      expect(stakingHealth.result).toBeOk();

      // Verify monitoring data integrity
      const coordData = coordHealth.result as any;
      expect(coordData.value['total-registered-tokens'].value).toBe(5n);
      expect(coordData.value['coordinator-version'].value).toBe('1.0.0');
    });

    it('should track user activity for production analytics', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Perform user activities
      const user1Op = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
        Cl.stringAscii('yield-claim'),
        Cl.uint(1000000)
      ], deployer);

      const user2Op = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet2),
        Cl.list([Cl.contractPrincipal(deployer, 'cxvg-token')]),
        Cl.stringAscii('staking'),
        Cl.uint(2000000)
      ], deployer);

      expect(user1Op.result).toBeOk(Cl.uint(1));
      expect(user2Op.result).toBeOk(Cl.uint(2));

      // Verify activity tracking
      const user1Activity = simnet.callReadOnlyFn('token-system-coordinator', 'get-user-activity', [Cl.standardPrincipal(wallet1)], deployer);
      const user2Activity = simnet.callReadOnlyFn('token-system-coordinator', 'get-user-activity', [Cl.standardPrincipal(wallet2)], deployer);

      expect(user1Activity.result).toBeOk();
      expect(user2Activity.result).toBeOk();
    });

    it('should provide production-ready health metrics', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);

      // Perform system operations
      simnet.callPublicFn('cxd-staking', 'initiate-stake', [Cl.uint(1000000)], wallet1);
      simnet.callPublicFn('cxd-staking', 'initiate-stake', [Cl.uint(2000000)], wallet2);

      // Verify comprehensive health metrics
      const systemHealth = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      const stakingInfo = simnet.callReadOnlyFn('cxd-staking', 'get-protocol-info', [], deployer);

      expect(systemHealth.result).toBeOk();
      expect(stakingInfo.result).toBeOk();
    });
  });

  describe('🚀 Mainnet Deployment Readiness', () => {
    it('should validate complete production workflow', () => {
      // 1. Initialize all systems
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);
      simnet.callPublicFn('revenue-distributor', 'set-treasury-address', [Cl.standardPrincipal(wallet1)], deployer);
      simnet.callPublicFn('revenue-distributor', 'set-insurance-address', [Cl.standardPrincipal(wallet2)], deployer);

      // 2. Register fee sources
      simnet.callPublicFn('revenue-distributor', 'register-fee-source', [
        Cl.stringAscii('dex-fees'),
        Cl.contractPrincipal(deployer, 'dex-pool'),
        Cl.uint(100)
      ], deployer);

      // 3. Set emergency operator
      simnet.callPublicFn('protocol-invariant-monitor', 'set-emergency-operator', [Cl.standardPrincipal(wallet3)], deployer);

      // 4. Perform production workflow
      const workflowOp = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token'), Cl.contractPrincipal(deployer, 'cxvg-token')]),
        Cl.stringAscii('yield-claim'),
        Cl.uint(3000000)
      ], deployer);

      expect(workflowOp.result).toBeOk(Cl.uint(1));

      // 5. Trigger revenue distribution
      const revenueDist = simnet.callPublicFn('token-system-coordinator', 'trigger-revenue-distribution', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(1000000)
      ], deployer);

      expect(revenueDist.result).toBeOk(Cl.bool(true));

      // 6. Verify system stability
      const finalHealth = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      expect(finalHealth.result).toBeOk(Cl.tuple({
        'is-paused': Cl.bool(false),
        'emergency-mode': Cl.bool(false),
        'total-registered-tokens': Cl.uint(5),
        'total-users': Cl.uint(1),
        'coordinator-version': Cl.stringAscii('1.0.0')
      }));
    });

    it('should handle production-scale operations', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Simulate production-scale operations
      const operations = [];
      for (let i = 0; i < 20; i++) {
        const user = `wallet_${(i % 3) + 1}` as keyof typeof simnet.getAccounts;
        const userAddr = simnet.getAccounts().get(user)!;

        const operation = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
          Cl.standardPrincipal(userAddr),
          Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
          Cl.stringAscii('yield-claim'),
          Cl.uint(1000000)
        ], deployer);

        operations.push(operation);
        expect(operation.result).toBeOk(Cl.uint(i + 1));
      }

      // Verify system handles production scale
      expect(operations.length).toBe(20);

      const systemHealth = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      expect(systemHealth.result).toBeOk(Cl.tuple({
        'is-paused': Cl.bool(false),
        'emergency-mode': Cl.bool(false),
        'total-registered-tokens': Cl.uint(5),
        'total-users': Cl.uint(3),
        'coordinator-version': Cl.stringAscii('1.0.0')
      }));
    });

    it('should validate emergency procedures for production', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      simnet.callPublicFn('protocol-invariant-monitor', 'set-emergency-operator', [Cl.standardPrincipal(wallet3)], deployer);

      // Test production emergency procedures
      const emergencyPause = simnet.callPublicFn('token-system-coordinator', 'emergency-pause-system', [], deployer);
      expect(emergencyPause.result).toBeOk(Cl.bool(true));

      // Verify emergency state
      const emergencyState = simnet.callReadOnlyFn('token-system-coordinator', 'is-paused', [], deployer);
      expect(emergencyState.result).toBeOk(Cl.bool(true));

      // Test emergency recovery
      const emergencyResume = simnet.callPublicFn('token-system-coordinator', 'emergency-resume-system', [], deployer);
      expect(emergencyResume.result).toBeOk(Cl.bool(true));

      // Verify recovery
      const recoveryState = simnet.callReadOnlyFn('token-system-coordinator', 'is-paused', [], deployer);
      expect(recoveryState.result).toBeOk(Cl.bool(false));
    });
  });

  describe('🔧 Production Maintenance Procedures', () => {
    it('should validate parameter update procedures', () => {
      // Test treasury address update
      const treasuryUpdate = simnet.callPublicFn('revenue-distributor', 'set-treasury-address', [
        Cl.standardPrincipal(wallet3)
      ], deployer);
      expect(treasuryUpdate.result).toBeOk(Cl.bool(true));

      // Verify update
      const treasuryCheck = simnet.callReadOnlyFn('revenue-distributor', 'get-treasury-address', [], deployer);
      expect(treasuryCheck.result).toBeOk(Cl.standardPrincipal(wallet3));

      // Test insurance address update
      const insuranceUpdate = simnet.callPublicFn('revenue-distributor', 'set-insurance-address', [
        Cl.standardPrincipal(wallet3)
      ], deployer);
      expect(insuranceUpdate.result).toBeOk(Cl.bool(true));

      // Verify update
      const insuranceCheck = simnet.callReadOnlyFn('revenue-distributor', 'get-insurance-address', [], deployer);
      expect(insuranceCheck.result).toBeOk(Cl.standardPrincipal(wallet3));
    });

    it('should validate fee source management', () => {
      // Register fee source
      const feeRegister = simnet.callPublicFn('revenue-distributor', 'register-fee-source', [
        Cl.stringAscii('production-fees'),
        Cl.contractPrincipal(deployer, 'production-contract'),
        Cl.uint(200)
      ], deployer);
      expect(feeRegister.result).toBeOk(Cl.bool(true));

      // Update fee source
      const feeUpdate = simnet.callPublicFn('revenue-distributor', 'update-fee-source', [
        Cl.stringAscii('production-fees'),
        Cl.bool(true),
        Cl.uint(250)
      ], deployer);
      expect(feeUpdate.result).toBeOk(Cl.bool(true));

      // Verify fee source
      const feeSource = simnet.callReadOnlyFn('revenue-distributor', 'get-fee-source', [
        Cl.stringAscii('production-fees')
      ], deployer);
      expect(feeSource.result).toBeOk();
    });

    it('should validate contract ownership transfers', () => {
      // Test ownership transfer preparation
      const ownershipTransfer = simnet.callPublicFn('token-system-coordinator', 'set-admin', [
        Cl.standardPrincipal(wallet3)
      ], deployer);
      expect(ownershipTransfer.result).toBeOk(Cl.bool(true));

      // Verify ownership change
      const ownerCheck = simnet.callReadOnlyFn('token-system-coordinator', 'get-contract-owner', [], deployer);
      expect(ownerCheck.result).toBeOk(Cl.standardPrincipal(wallet3));
    });
  });

  describe('📈 Production Metrics and Analytics', () => {
    it('should provide comprehensive production metrics', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);

      // Generate metrics data
      for (let i = 0; i < 5; i++) {
        const user = `wallet_${(i % 3) + 1}` as keyof typeof simnet.getAccounts;
        const userAddr = simnet.getAccounts().get(user)!;

        simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
          Cl.standardPrincipal(userAddr),
          Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
          Cl.stringAscii('yield-claim'),
          Cl.uint(1000000)
        ], deployer);

        simnet.callPublicFn('cxd-staking', 'initiate-stake', [Cl.uint(1000000)], userAddr);
      }

      // Verify comprehensive metrics
      const coordMetrics = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      const stakingMetrics = simnet.callReadOnlyFn('cxd-staking', 'get-protocol-info', [], deployer);
      const revenueMetrics = simnet.callReadOnlyFn('revenue-distributor', 'get-system-health', [], deployer);

      expect(coordMetrics.result).toBeOk();
      expect(stakingMetrics.result).toBeOk();
      expect(revenueMetrics.result).toBeOk();
    });

    it('should track production performance indicators', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      const startTime = Date.now();

      // Perform production-level operations
      for (let i = 0; i < 10; i++) {
        const user = `wallet_${(i % 3) + 1}` as keyof typeof simnet.getAccounts;
        const userAddr = simnet.getAccounts().get(user)!;

        simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
          Cl.standardPrincipal(userAddr),
          Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
          Cl.stringAscii('yield-claim'),
          Cl.uint(1000000)
        ], deployer);
      }

      const endTime = Date.now();
      const operationTime = endTime - startTime;

      console.log(`Production performance test completed in ${operationTime}ms`);

      // Verify performance is within acceptable range
      expect(operationTime).toBeLessThan(1000); // Should complete in under 1 second
    });
  });

  describe('🛡️ Production Security Validation', () => {
    it('should validate production security controls', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      simnet.callPublicFn('protocol-invariant-monitor', 'set-emergency-operator', [Cl.standardPrincipal(wallet3)], deployer);

      // Test unauthorized access attempts
      const unauthorized1 = simnet.callPublicFn('token-system-coordinator', 'emergency-pause-system', [], wallet1);
      expect(unauthorized1.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED

      const unauthorized2 = simnet.callPublicFn('revenue-distributor', 'register-fee-source', [
        Cl.stringAscii('test'),
        Cl.contractPrincipal(deployer, 'test'),
        Cl.uint(100)
      ], wallet1);
      expect(unauthorized2.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED

      // Test authorized emergency procedures
      const authorizedEmergency = simnet.callPublicFn('protocol-invariant-monitor', 'emergency-shutdown', [], wallet3);
      expect(authorizedEmergency.result).toBeOk(Cl.bool(true));

      // Verify security controls remain active
      const securityCheck = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      expect(securityCheck.result).toBeOk();
    });

    it('should validate production emergency response', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Test emergency response procedures
      const emergencyResponse = simnet.callPublicFn('token-system-coordinator', 'activate-emergency-mode', [], deployer);
      expect(emergencyResponse.result).toBeOk(Cl.bool(true));

      // Verify emergency state
      const emergencyState = simnet.callReadOnlyFn('token-system-coordinator', 'get-emergency-mode', [], deployer);
      expect(emergencyState.result).toBeOk(Cl.bool(true));

      // Test emergency recovery
      const emergencyRecovery = simnet.callPublicFn('token-system-coordinator', 'deactivate-emergency-mode', [], deployer);
      expect(emergencyRecovery.result).toBeOk(Cl.bool(true));

      // Verify recovery
      const recoveryState = simnet.callReadOnlyFn('token-system-coordinator', 'get-emergency-mode', [], deployer);
      expect(recoveryState.result).toBeOk(Cl.bool(false));
    });
  });
});
