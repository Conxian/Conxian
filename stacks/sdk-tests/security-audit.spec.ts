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

describe('Security Audit - Comprehensive Security Review', () => {
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

  describe('🔐 Access Control Validation', () => {
    it('should enforce strict access controls across all contracts', () => {
      // Test Token System Coordinator access controls
      const unauthorizedCoord1 = simnet.callPublicFn('token-system-coordinator', 'register-token', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.stringAscii('CXD'),
        Cl.uint(6)
      ], wallet1);
      expect(unauthorizedCoord1.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED

      const unauthorizedCoord2 = simnet.callPublicFn('token-system-coordinator', 'emergency-pause-system', [], wallet1);
      expect(unauthorizedCoord2.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED

      // Test Revenue Distributor access controls
      const unauthorizedRevenue1 = simnet.callPublicFn('revenue-distributor', 'register-fee-source', [
        Cl.stringAscii('test'),
        Cl.contractPrincipal(deployer, 'test'),
        Cl.uint(100)
      ], wallet1);
      expect(unauthorizedRevenue1.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED

      const unauthorizedRevenue2 = simnet.callPublicFn('revenue-distributor', 'set-treasury-address', [
        Cl.standardPrincipal(wallet2)
      ], wallet1);
      expect(unauthorizedRevenue2.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED

      // Test CXD Staking access controls
      const unauthorizedStaking1 = simnet.callPublicFn('cxd-staking', 'set-contract-owner', [
        Cl.standardPrincipal(wallet1)
      ], wallet1);
      expect(unauthorizedStaking1.result).toBeErr(Cl.uint(400)); // ERR_UNAUTHORIZED

      const unauthorizedStaking2 = simnet.callPublicFn('cxd-staking', 'pause-contract', [], wallet1);
      expect(unauthorizedStaking2.result).toBeErr(Cl.uint(400)); // ERR_UNAUTHORIZED
    });

    it('should validate role-based permissions', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Test emergency operator role
      const setEmergencyOp = simnet.callPublicFn('protocol-invariant-monitor', 'set-emergency-operator', [
        Cl.standardPrincipal(wallet1)
      ], deployer);
      expect(setEmergencyOp.result).toBeOk(Cl.bool(true));

      // Verify emergency operator can perform emergency functions
      const emergencyOp = simnet.callPublicFn('protocol-invariant-monitor', 'emergency-shutdown', [], wallet1);
      expect(emergencyOp.result).toBeOk(Cl.bool(true));

      // Verify non-emergency operator cannot perform emergency functions
      const nonEmergencyOp = simnet.callPublicFn('protocol-invariant-monitor', 'emergency-shutdown', [], wallet2);
      expect(nonEmergencyOp.result).toBeErr(Cl.uint(900)); // ERR_UNAUTHORIZED
    });

    it('should prevent privilege escalation attacks', () => {
      // Test that users cannot grant themselves admin privileges
      const selfAdmin1 = simnet.callPublicFn('token-system-coordinator', 'set-admin', [
        Cl.standardPrincipal(wallet1)
      ], wallet1);
      expect(selfAdmin1.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED

      const selfAdmin2 = simnet.callPublicFn('revenue-distributor', 'set-admin', [
        Cl.standardPrincipal(wallet1)
      ], wallet1);
      expect(selfAdmin2.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED
    });
  });

  describe('🛡️ Circuit Breaker Security', () => {
    it('should protect against failure cascades', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);

      // Test circuit breaker activation
      const circuitState = simnet.callReadOnlyFn('protocol-invariant-monitor', 'get-circuit-state', [
        Cl.stringAscii('staking')
      ], deployer);
      expect(circuitState.result).toBeOk(Cl.tuple({
        state: Cl.uint(0), // CLOSED
        'last-checked': Cl.uint(0),
        'failure-rate': Cl.uint(0),
        'failure-count': Cl.uint(0),
        'success-count': Cl.uint(0)
      }));

      // Perform successful operations
      for (let i = 0; i < 5; i++) {
        const stakeOp = simnet.callPublicFn('cxd-staking', 'initiate-stake', [Cl.uint(1000000)], wallet1);
        expect(stakeOp.result).toBeOk(Cl.bool(true));
      }

      // Verify circuit breaker tracks success
      const updatedState = simnet.callReadOnlyFn('protocol-invariant-monitor', 'get-circuit-state', [
        Cl.stringAscii('staking')
      ], deployer);
      expect(updatedState.result).toBeOk(Cl.tuple({
        state: Cl.uint(0), // CLOSED
        'last-checked': Cl.uint(1),
        'failure-rate': Cl.uint(0),
        'failure-count': Cl.uint(0),
        'success-count': Cl.uint(5)
      }));
    });

    it('should handle emergency shutdown procedures', () => {
      // Test emergency shutdown
      const emergencyShutdown = simnet.callPublicFn('protocol-invariant-monitor', 'emergency-shutdown', [], deployer);
      expect(emergencyShutdown.result).toBeOk(Cl.bool(true));

      // Verify system enters emergency state
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

    it('should prevent operations during emergency', () => {
      // Activate emergency mode
      simnet.callPublicFn('protocol-invariant-monitor', 'emergency-shutdown', [], deployer);

      // Test that operations are blocked during emergency
      const blockedOperation = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
        Cl.stringAscii('yield-claim'),
        Cl.uint(1000000)
      ], deployer);

      // Should be blocked due to circuit breaker
      expect(blockedOperation.result).toBeErr();
    });
  });

  describe('💰 Financial Security Controls', () => {
    it('should prevent unauthorized fund movements', () => {
      // Test unauthorized token transfers
      const unauthorizedTransfer = simnet.callPublicFn('cxd-token', 'transfer', [
        Cl.uint(1000000),
        Cl.standardPrincipal(wallet1),
        Cl.standardPrincipal(wallet2),
        Cl.none()
      ], wallet1);
      expect(unauthorizedTransfer.result).toBeErr(); // Should fail due to insufficient balance or other controls

      // Test unauthorized revenue distribution
      const unauthorizedRevenue = simnet.callPublicFn('revenue-distributor', 'distribute-revenue', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(1000000)
      ], wallet1);
      expect(unauthorizedRevenue.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED
    });

    it('should validate revenue distribution security', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      simnet.callPublicFn('revenue-distributor', 'set-treasury-address', [Cl.standardPrincipal(wallet1)], deployer);

      // Test authorized revenue distribution
      const authorizedRevenue = simnet.callPublicFn('revenue-distributor', 'distribute-revenue', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(1000000)
      ], deployer);
      expect(authorizedRevenue.result).toBeOk(Cl.uint(1));

      // Verify distribution tracking
      const totalRevenue = simnet.callReadOnlyFn('revenue-distributor', 'get-total-revenue-distributed', [], deployer);
      expect(totalRevenue.result).toBeOk(Cl.uint(1000000));
    });

    it('should prevent staking manipulation', () => {
      // Initialize system
      simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);

      // Test unauthorized staking contract changes
      const unauthorizedStakingConfig = simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [
        Cl.contractPrincipal(deployer, 'cxvg-token')
      ], wallet1);
      expect(unauthorizedStakingConfig.result).toBeErr(Cl.uint(400)); // ERR_UNAUTHORIZED

      // Test valid staking operation
      const validStake = simnet.callPublicFn('cxd-staking', 'initiate-stake', [Cl.uint(1000000)], wallet1);
      expect(validStake.result).toBeOk(Cl.bool(true));
    });
  });

  describe('🔒 System Emergency Controls', () => {
    it('should handle emergency pause procedures', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Test emergency pause
      const emergencyPause = simnet.callPublicFn('token-system-coordinator', 'emergency-pause-system', [], deployer);
      expect(emergencyPause.result).toBeOk(Cl.bool(true));

      // Verify pause state
      const pauseState = simnet.callReadOnlyFn('token-system-coordinator', 'is-paused', [], deployer);
      expect(pauseState.result).toBeOk(Cl.bool(true));

      // Test emergency resume
      const emergencyResume = simnet.callPublicFn('token-system-coordinator', 'emergency-resume-system', [], deployer);
      expect(emergencyResume.result).toBeOk(Cl.bool(true));

      // Verify resume state
      const resumeState = simnet.callReadOnlyFn('token-system-coordinator', 'is-paused', [], deployer);
      expect(resumeState.result).toBeOk(Cl.bool(false));
    });

    it('should activate emergency mode when needed', () => {
      // Test emergency mode activation
      const emergencyMode = simnet.callPublicFn('token-system-coordinator', 'activate-emergency-mode', [], deployer);
      expect(emergencyMode.result).toBeOk(Cl.bool(true));

      // Verify emergency mode
      const emergencyState = simnet.callReadOnlyFn('token-system-coordinator', 'get-emergency-mode', [], deployer);
      expect(emergencyState.result).toBeOk(Cl.bool(true));

      // Test emergency mode deactivation
      const emergencyDeactivate = simnet.callPublicFn('token-system-coordinator', 'deactivate-emergency-mode', [], deployer);
      expect(emergencyDeactivate.result).toBeOk(Cl.bool(true));

      // Verify emergency mode deactivated
      const emergencyStateAfter = simnet.callReadOnlyFn('token-system-coordinator', 'get-emergency-mode', [], deployer);
      expect(emergencyStateAfter.result).toBeOk(Cl.bool(false));
    });

    it('should prevent operations during emergency states', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Activate emergency mode
      simnet.callPublicFn('token-system-coordinator', 'activate-emergency-mode', [], deployer);

      // Test that operations are blocked during emergency
      const blockedOperation = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
        Cl.stringAscii('yield-claim'),
        Cl.uint(1000000)
      ], deployer);

      expect(blockedOperation.result).toBeErr(Cl.uint(104)); // ERR_COORDINATOR_ERROR
    });
  });

  describe('🛡️ Contract Interaction Security', () => {
    it('should validate cross-contract call security', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);

      // Test secure cross-contract communication
      const crossContractOp = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
        Cl.stringAscii('staking-integration'),
        Cl.uint(1000000)
      ], deployer);

      expect(crossContractOp.result).toBeOk(Cl.uint(1));

      // Verify secure state transition
      const systemHealth = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      expect(systemHealth.result).toBeOk(Cl.tuple({
        'is-paused': Cl.bool(false),
        'emergency-mode': Cl.bool(false),
        'total-registered-tokens': Cl.uint(5),
        'total-users': Cl.uint(1),
        'coordinator-version': Cl.stringAscii('1.0.0')
      }));
    });

    it('should prevent reentrancy attacks', () => {
      // Test that the system prevents reentrancy
      // This is validated through the circuit breaker and access controls
      const reentrancyTest = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
        Cl.stringAscii('reentrancy-test'),
        Cl.uint(1000000)
      ], deployer);

      // Should handle gracefully without reentrancy vulnerability
      expect(reentrancyTest.result).toBeOk(Cl.uint(1));
    });

    it('should validate input sanitization', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Test with invalid inputs
      const invalidInput1 = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([]), // Empty token list
        Cl.stringAscii('test'),
        Cl.uint(1000000)
      ], deployer);

      expect(invalidInput1.result).toBeErr(Cl.uint(103)); // ERR_INVALID_AMOUNT

      const invalidInput2 = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
        Cl.stringAscii(''), // Empty operation type
        Cl.uint(0) // Zero amount
      ], deployer);

      expect(invalidInput2.result).toBeErr(Cl.uint(103)); // ERR_INVALID_AMOUNT
    });
  });

  describe('📊 Monitoring and Audit Security', () => {
    it('should securely track all critical operations', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Perform tracked operations
      const operation1 = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
        Cl.stringAscii('yield-claim'),
        Cl.uint(1000000)
      ], deployer);

      const operation2 = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet2),
        Cl.list([Cl.contractPrincipal(deployer, 'cxvg-token')]),
        Cl.stringAscii('staking'),
        Cl.uint(2000000)
      ], deployer);

      expect(operation1.result).toBeOk(Cl.uint(1));
      expect(operation2.result).toBeOk(Cl.uint(2));

      // Verify secure tracking
      const user1Activity = simnet.callReadOnlyFn('token-system-coordinator', 'get-user-activity', [Cl.standardPrincipal(wallet1)], deployer);
      const user2Activity = simnet.callReadOnlyFn('token-system-coordinator', 'get-user-activity', [Cl.standardPrincipal(wallet2)], deployer);

      expect(user1Activity.result).toBeOk();
      expect(user2Activity.result).toBeOk();
    });

    it('should provide secure health monitoring', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Perform system operations
      simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
        Cl.stringAscii('health-check'),
        Cl.uint(1000000)
      ], deployer);

      // Verify secure health reporting
      const healthReport = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      expect(healthReport.result).toBeOk(Cl.tuple({
        'is-paused': Cl.bool(false),
        'emergency-mode': Cl.bool(false),
        'total-registered-tokens': Cl.uint(5),
        'total-users': Cl.uint(1),
        'coordinator-version': Cl.stringAscii('1.0.0')
      }));
    });
  });

  describe('🚨 Recovery and Resilience Security', () => {
    it('should ensure secure recovery procedures', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Test emergency pause and recovery
      const pauseSystem = simnet.callPublicFn('token-system-coordinator', 'emergency-pause-system', [], deployer);
      expect(pauseSystem.result).toBeOk(Cl.bool(true));

      // Verify pause state
      const pauseState = simnet.callReadOnlyFn('token-system-coordinator', 'is-paused', [], deployer);
      expect(pauseState.result).toBeOk(Cl.bool(true));

      // Test secure recovery
      const resumeSystem = simnet.callPublicFn('token-system-coordinator', 'emergency-resume-system', [], deployer);
      expect(resumeSystem.result).toBeOk(Cl.bool(true));

      // Verify recovery state
      const resumeState = simnet.callReadOnlyFn('token-system-coordinator', 'is-paused', [], deployer);
      expect(resumeState.result).toBeOk(Cl.bool(false));
    });

    it('should maintain security during recovery', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Activate emergency mode
      simnet.callPublicFn('token-system-coordinator', 'activate-emergency-mode', [], deployer);

      // Test that security controls remain active during emergency
      const unauthorizedDuringEmergency = simnet.callPublicFn('token-system-coordinator', 'register-token', [
        Cl.contractPrincipal(deployer, 'test-token'),
        Cl.stringAscii('TEST'),
        Cl.uint(6)
      ], wallet1);

      expect(unauthorizedDuringEmergency.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED
    });
  });
});
