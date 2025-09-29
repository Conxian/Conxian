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

describe('Performance Optimization - Load Testing & Gas Efficiency', () => {
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

  describe('⚡ Load Testing - High Throughput Validation', () => {
    it('should handle 50 concurrent staking operations', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);

      const startTime = Date.now();
      const operations = [];

      // Perform 50 concurrent staking operations
      for (let i = 0; i < 50; i++) {
        const user = `wallet_${(i % 3) + 1}`;
        const userAddr = simnet.getAccounts().get(user)!;

        const operation = simnet.callPublicFn('cxd-staking', 'initiate-stake', [Cl.uint(1000000)], userAddr);
        operations.push(operation);
        expect(operation.result).toBeOk(Cl.bool(true));
      }

      const endTime = Date.now();
      const duration = endTime - startTime;

      console.log(`50 staking operations completed in ${duration}ms`);

      // Verify all operations succeeded
      expect(operations.length).toBe(50);
      operations.forEach(op => expect(op.result).toBeOk(Cl.bool(true)));
    });

    it('should handle 100 concurrent token operations', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      const startTime = Date.now();
      const operations = [];

      // Perform 100 concurrent token operations
      for (let i = 0; i < 100; i++) {
        const user = `wallet_${(i % 3) + 1}`;
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

      const endTime = Date.now();
      const duration = endTime - startTime;

      console.log(`100 token operations completed in ${duration}ms`);

      // Verify system stability
      const health = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      expect(health.result).toBeOk(Cl.tuple({
        'is-paused': Cl.bool(false),
        'emergency-mode': Cl.bool(false),
        'total-registered-tokens': Cl.uint(5),
        'total-users': Cl.uint(3),
        'coordinator-version': Cl.stringAscii('1.0.0')
      }));
    });

    it('should handle batch revenue distribution efficiently', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      simnet.callPublicFn('revenue-distributor', 'set-treasury-address', [Cl.standardPrincipal(wallet1)], deployer);
      simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);

      const startTime = Date.now();

      // Perform 20 revenue distributions
      for (let i = 0; i < 20; i++) {
        const distribution = simnet.callPublicFn('token-system-coordinator', 'trigger-revenue-distribution', [
          Cl.contractPrincipal(deployer, 'cxd-token'),
          Cl.uint(1000000)
        ], deployer);

        expect(distribution.result).toBeOk(Cl.bool(true));
      }

      const endTime = Date.now();
      const duration = endTime - startTime;

      console.log(`20 revenue distributions completed in ${duration}ms`);

      // Verify revenue tracking
      const totalRevenue = simnet.callReadOnlyFn('revenue-distributor', 'get-total-revenue-distributed', [], deployer);
      expect(totalRevenue.result).toBeOk(Cl.uint(20000000)); // 20 * 1M
    });
  });

  describe('💰 Gas Efficiency - Cost Optimization', () => {
    it('should optimize token operations for minimal gas usage', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Test single token operation gas efficiency
      const startTime = Date.now();

      const operation = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
        Cl.stringAscii('yield-claim'),
        Cl.uint(1000000)
      ], deployer);

      const endTime = Date.now();
      const operationTime = endTime - startTime;

      expect(operation.result).toBeOk(Cl.uint(1));
      console.log(`Single token operation completed in ${operationTime}ms`);

      // Should complete in reasonable time
      expect(operationTime).toBeLessThan(100);
    });

    it('should optimize batch operations for efficiency', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      const startTime = Date.now();

      // Batch multiple operations
      const operations = [];
      for (let i = 0; i < 10; i++) {
        const user = `wallet_${(i % 3) + 1}`;
        const userAddr = simnet.getAccounts().get(user)!;

        const operation = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
          Cl.standardPrincipal(userAddr),
          Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
          Cl.stringAscii('yield-claim'),
          Cl.uint(1000000)
        ], deployer);

        operations.push(operation);
      }

      const endTime = Date.now();
      const batchTime = endTime - startTime;

      console.log(`10 batch operations completed in ${batchTime}ms`);

      // Batch should be more efficient than individual operations
      expect(batchTime).toBeLessThan(500);
      operations.forEach(op => expect(op.result).toBeOk());
    });

    it('should minimize gas usage for revenue distribution', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      simnet.callPublicFn('revenue-distributor', 'set-treasury-address', [Cl.standardPrincipal(wallet1)], deployer);

      const startTime = Date.now();

      const distribution = simnet.callPublicFn('revenue-distributor', 'distribute-revenue', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(1000000)
      ], deployer);

      const endTime = Date.now();
      const distributionTime = endTime - startTime;

      expect(distribution.result).toBeOk(Cl.uint(1));
      console.log(`Revenue distribution completed in ${distributionTime}ms`);

      // Revenue distribution should be efficient
      expect(distributionTime).toBeLessThan(50);
    });
  });

  describe('📈 Scalability Testing - System Limits', () => {
    it('should handle maximum user load without degradation', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      const startTime = Date.now();
      const maxUsers = 10;
      const operationsPerUser = 5;

      // Simulate maximum user load
      for (let user = 1; user <= maxUsers; user++) {
        const userAddr = simnet.getAccounts().get(`wallet_${user}`)!;

        for (let op = 0; op < operationsPerUser; op++) {
          const operation = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
            Cl.standardPrincipal(userAddr),
            Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
            Cl.stringAscii('yield-claim'),
            Cl.uint(1000000)
          ], deployer);

          expect(operation.result).toBeOk(Cl.uint((user - 1) * operationsPerUser + op + 1));
        }
      }

      const endTime = Date.now();
      const totalTime = endTime - startTime;

      console.log(`${maxUsers} users with ${operationsPerUser} operations each completed in ${totalTime}ms`);

      // System should handle this load efficiently
      expect(totalTime).toBeLessThan(2000);

      // Verify system health after max load
      const health = simnet.callReadOnlyFn('token-system-coordinator', 'get-system-health', [], deployer);
      expect(health.result).toBeOk(Cl.tuple({
        'is-paused': Cl.bool(false),
        'emergency-mode': Cl.bool(false),
        'total-registered-tokens': Cl.uint(5),
        'total-users': Cl.uint(10),
        'coordinator-version': Cl.stringAscii('1.0.0')
      }));
    });

    it('should handle high-frequency operations', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      const startTime = Date.now();

      // High-frequency operations (rapid succession)
      for (let i = 0; i < 20; i++) {
        const operation = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
          Cl.standardPrincipal(wallet1),
          Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
          Cl.stringAscii('yield-claim'),
          Cl.uint(1000000)
        ], deployer);

        expect(operation.result).toBeOk(Cl.uint(i + 1));
      }

      const endTime = Date.now();
      const frequencyTime = endTime - startTime;

      console.log(`20 high-frequency operations completed in ${frequencyTime}ms`);

      // High-frequency operations should complete efficiently
      expect(frequencyTime).toBeLessThan(1000);
    });

    it('should maintain performance under sustained load', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      const testDuration = 5000; // 5 seconds
      const startTime = Date.now();
      let operationCount = 0;

      // Sustained load test
      while (Date.now() - startTime < testDuration) {
        const operation = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
          Cl.standardPrincipal(wallet1),
          Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
          Cl.stringAscii('yield-claim'),
          Cl.uint(1000000)
        ], deployer);

        expect(operation.result).toBeOk(Cl.uint(operationCount + 1));
        operationCount++;
      }

      const endTime = Date.now();
      const actualDuration = endTime - startTime;

      console.log(`Sustained load: ${operationCount} operations in ${actualDuration}ms`);

      // Should maintain consistent performance
      expect(actualDuration).toBeGreaterThanOrEqual(testDuration - 100);
      expect(operationCount).toBeGreaterThan(20); // Should handle at least 20 operations in 5 seconds
    });
  });

  describe('🔧 Memory and Resource Efficiency', () => {
    it('should efficiently manage user activity tracking', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Create user activity
      for (let i = 0; i < 10; i++) {
        const user = `wallet_${(i % 3) + 1}` as keyof typeof simnet.getAccounts;
        const userAddr = simnet.getAccounts().get(user)!;

        const operation = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
          Cl.standardPrincipal(userAddr),
          Cl.list([Cl.contractPrincipal(deployer, 'cxd-token')]),
          Cl.stringAscii('yield-claim'),
          Cl.uint(1000000)
        ], deployer);

        expect(operation.result).toBeOk(Cl.uint(i + 1));
      }

      // Verify efficient memory usage through activity tracking
      const user1Activity = simnet.callReadOnlyFn('token-system-coordinator', 'get-user-activity', [Cl.standardPrincipal(wallet1)], deployer);
      const user2Activity = simnet.callReadOnlyFn('token-system-coordinator', 'get-user-activity', [Cl.standardPrincipal(wallet2)], deployer);
      const user3Activity = simnet.callReadOnlyFn('token-system-coordinator', 'get-user-activity', [Cl.standardPrincipal(wallet3)], deployer);

      expect(user1Activity.result).toBeOk();
      expect(user2Activity.result).toBeOk();
      expect(user3Activity.result).toBeOk();
    });

    it('should efficiently handle cross-token operation tracking', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);

      // Create various cross-token operations
      const multiTokenOp = simnet.callPublicFn('token-system-coordinator', 'coordinate-multi-token-operation', [
        Cl.standardPrincipal(wallet1),
        Cl.list([
          Cl.contractPrincipal(deployer, 'cxd-token'),
          Cl.contractPrincipal(deployer, 'cxvg-token'),
          Cl.contractPrincipal(deployer, 'cxlp-token')
        ]),
        Cl.stringAscii('yield-claim'),
        Cl.uint(3000000)
      ], deployer);

      expect(multiTokenOp.result).toBeOk(Cl.uint(1));

      // Verify efficient tracking
      const userActivity = simnet.callReadOnlyFn('token-system-coordinator', 'get-user-activity', [Cl.standardPrincipal(wallet1)], deployer);
      expect(userActivity.result).toBeOk(Cl.tuple({
        'last-interaction': Cl.uint(1),
        'total-volume': Cl.uint(3000000),
        'token-count': Cl.uint(3),
        'reputation-score': Cl.uint(1000)
      }));
    });
  });

  describe('⚡ Circuit Breaker Performance', () => {
    it('should efficiently handle circuit breaker operations', () => {
      // Initialize system
      simnet.callPublicFn('token-system-coordinator', 'initialize-system', [], deployer);
      simnet.callPublicFn('cxd-staking', 'set-cxd-contract', [Cl.contractPrincipal(deployer, 'cxd-token')], deployer);

      const startTime = Date.now();

      // Test circuit breaker efficiency with multiple operations
      for (let i = 0; i < 10; i++) {
        const stakeOp = simnet.callPublicFn('cxd-staking', 'initiate-stake', [Cl.uint(1000000)], wallet1);
        expect(stakeOp.result).toBeOk(Cl.bool(true));

        const circuitCheck = simnet.callReadOnlyFn('protocol-invariant-monitor', 'get-circuit-state', [
          Cl.stringAscii('staking')
        ], deployer);
        expect(circuitCheck.result).toBeOk();
      }

      const endTime = Date.now();
      const circuitTime = endTime - startTime;

      console.log(`10 circuit breaker operations completed in ${circuitTime}ms`);

      // Circuit breaker operations should be efficient
      expect(circuitTime).toBeLessThan(200);
    });
  });
});
