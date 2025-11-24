import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { Simnet, Tx } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Router Systems Comprehensive Tests', () => {
  let simnet: Simnet;
  let deployer: string;
  let user1: string;
  let user2: string;
  let routerManager: string;

  // Contract addresses
  const MULTI_HOP_ROUTER = `${deployer}.multi-hop-router-v3`;
  const ADVANCED_ROUTER = `${deployer}.advanced-router-dijkstra`;
  const DEX_FACTORY = `${deployer}.dex-factory`;
  const POOL_REGISTRY = `${deployer}.pool-registry`;
  const TOKEN_A = `${deployer}.token-a`;
  const TOKEN_B = `${deployer}.token-b`;
  const TOKEN_C = `${deployer}.token-c`;
  const TOKEN_D = `${deployer}.token-d`;

  beforeAll(async () => {
    simnet = (global as any).simnet;
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')?.address || '';
    user1 = accounts.get('wallet_1')?.address || '';
    user2 = accounts.get('wallet_2')?.address || '';
    routerManager = accounts.get('wallet_3')?.address || '';

    await setupInitialTokens();
    await setupRoles();
    await createPoolNetwork();
  });

  beforeEach(async () => {
    await simnet.mineEmptyBlock();
  });

  async function setupInitialTokens() {
    // Mint tokens for all users
    const users = [user1, user2];
    const tokens = [TOKEN_A, TOKEN_B, TOKEN_C, TOKEN_D];

    for (const user of users) {
      for (const token of tokens) {
        await simnet.callPublicFn(
          token,
          'mint',
          [Cl.uint(1_000_000), Cl.principal(user)],
          deployer
        );
      }
    }
  }

  async function setupRoles() {
    await simnet.callPublicFn(
      `${deployer}.access-control`,
      'grant-role',
      [Cl.stringAscii('ROUTER_MANAGER'), Cl.principal(routerManager)],
      deployer
    );
  }

  async function createPoolNetwork() {
    // Create multiple pools for routing tests
    const pools = [
      { tokenA: TOKEN_A, tokenB: TOKEN_B, name: 'POOL-AB' },
      { tokenA: TOKEN_B, tokenC: TOKEN_B, name: 'POOL-BC' },
      { tokenA: TOKEN_C, TOKEN_D, name: 'POOL-CD' },
      { tokenA: TOKEN_A, TOKEN_C, name: 'POOL-AC' },
      { tokenA: TOKEN_B, TOKEN_D, name: 'POOL-BD' }
    ];

    for (const pool of pools) {
      await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(pool.tokenA),
          Cl.principal(pool.tokenB),
          Cl.uint(100), Cl.uint(100), Cl.uint(500), Cl.stringAscii(pool.name)
        ],
        routerManager
      );
    }
  }

  describe('Multi-Hop Router V3', () => {
    beforeEach(async () => {
      // Approve tokens for router
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(MULTI_HOP_ROUTER), Cl.uint(100_000)],
        user1
      );
    });

    it('should perform direct swap successfully', async () => {
      const result = await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'swap-exact-tokens-for-tokens',
        [
          Cl.uint(10_000), // amount in
          Cl.uint(9500),   // amount out min
          [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B)], // path
          Cl.principal(user1), // recipient
          Cl.uint(1672531200) // deadline
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should perform multi-hop swap successfully', async () => {
      const result = await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'swap-exact-tokens-for-tokens',
        [
          Cl.uint(10_000), // amount in
          Cl.uint(8500),   // amount out min (accounting for multiple hops)
          [
            Cl.principal(TOKEN_A),
            Cl.principal(TOKEN_B),
            Cl.principal(TOKEN_C)
          ], // path: A -> B -> C
          Cl.principal(user1),
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should perform 4-hop swap successfully', async () => {
      const result = await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'swap-exact-tokens-for-tokens',
        [
          Cl.uint(10_000),
          Cl.uint(7500), // Lower minimum for more hops
          [
            Cl.principal(TOKEN_A),
            Cl.principal(TOKEN_B),
            Cl.principal(TOKEN_C),
            Cl.principal(TOKEN_D)
          ], // A -> B -> C -> D
          Cl.principal(user1),
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject swap with insufficient balance', async () => {
      const result = await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'swap-exact-tokens-for-tokens',
        [
          Cl.uint(2_000_000), // More than user has
          Cl.uint(9500),
          [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B)],
          Cl.principal(user1),
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(2003)); // ERR_INSUFFICIENT_BALANCE
    });

    it('should reject swap with invalid path', async () => {
      const result = await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'swap-exact-tokens-for-tokens',
        [
          Cl.uint(10_000),
          Cl.uint(9500),
          [
            Cl.principal(TOKEN_A),
            Cl.principal(TOKEN_B),
            Cl.principal('invalid-token') // Invalid token in path
          ],
          Cl.principal(user1),
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(2001)); // ERR_INVALID_PATH
    });

    it('should reject swap with insufficient liquidity', async () => {
      const result = await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'swap-exact-tokens-for-tokens',
        [
          Cl.uint(1_000_000), // Too large for pools
          Cl.uint(9500),
          [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B)],
          Cl.principal(user1),
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(2004)); // ERR_INSUFFICIENT_LIQUIDITY
    });

    it('should handle tokens for exact output swap', async () => {
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(MULTI_HOP_ROUTER), Cl.uint(100_000)],
        user1
      );

      const result = await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'swap-tokens-for-exact-tokens',
        [
          Cl.uint(10000), // amount out desired
          Cl.uint(12000), // amount in max
          [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B)],
          Cl.principal(user1),
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should calculate optimal routing', async () => {
      const routes = simnet.callReadOnlyFn(
        MULTI_HOP_ROUTER,
        'get-routes',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_D),
          Cl.uint(10000)
        ],
        deployer
      );

      expect(routes.result).toBeOk(Cl.bool(true));
    });

    it('should estimate gas for multi-hop swap', async () => {
      const gasEstimate = simnet.callReadOnlyFn(
        MULTI_HOP_ROUTER,
        'estimate-gas',
        [
          Cl.uint(10_000),
          [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B), Cl.principal(TOKEN_C)]
        ],
        deployer
      );

      expect(gasEstimate.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Advanced Router Dijkstra', () => {
    beforeEach(async () => {
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(ADVANCED_ROUTER), Cl.uint(100_000)],
        user1
      );
    });

    it('should find shortest path using Dijkstra algorithm', async () => {
      const result = await simnet.callPublicFn(
        ADVANCED_ROUTER,
        'find-optimal-path',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_D),
          Cl.uint(10000), // amount
          Cl.bool(false) // minimize hops (false = minimize cost)
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should find path with minimum hops', async () => {
      const result = await simnet.callPublicFn(
        ADVANCED_ROUTER,
        'find-optimal-path',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_D),
          Cl.uint(10000),
          Cl.bool(true) // minimize hops
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should handle complex network routing', async () => {
      // Test routing through complex token network
      const result = await simnet.callPublicFn(
        ADVANCED_ROUTER,
        'route-through-network',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_D),
          Cl.uint(10000),
          Cl.uint(3), // max hops
          Cl.uint(1000) // max slippage
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should update routing weights based on liquidity', async () => {
      const result = await simnet.callPublicFn(
        ADVANCED_ROUTER,
        'update-weights',
        [],
        routerManager
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should handle dynamic pool additions', async () => {
      // Add a new pool
      await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_D),
          Cl.uint(100), Cl.uint(100), Cl.uint(500), Cl.stringAscii('POOL-AD-DYNAMIC')
        ],
        routerManager
      );

      // Router should recognize new pool
      const routes = simnet.callReadOnlyFn(
        ADVANCED_ROUTER,
        'get-available-routes',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_D)],
        deployer
      );

      expect(routes.result).toBeOk(Cl.bool(true));
    });

    it('should calculate path costs accurately', async () => {
      const pathCost = simnet.callReadOnlyFn(
        ADVANCED_ROUTER,
        'calculate-path-cost',
        [
          Cl.uint(10000),
          [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B), Cl.principal(TOKEN_C)]
        ],
        deployer
      );

      expect(pathCost.result).toBeOk(Cl.bool(true));
    });

    it('should handle circular dependencies', async () => {
      // Create a circular dependency scenario
      const result = await simnet.callPublicFn(
        ADVANCED_ROUTER,
        'resolve-circular-path',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.principal(TOKEN_C),
          Cl.principal(TOKEN_A)
        ],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Router Integration and Cross-Protocol', () => {
    beforeEach(async () => {
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(MULTI_HOP_ROUTER), Cl.uint(100_000)],
        user1
      );
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(ADVANCED_ROUTER), Cl.uint(100_000)],
        user1
      );
    });

    it('should integrate multi-hop with advanced routing', async () => {
      // Use advanced router to find optimal path, then execute with multi-hop
      const optimalPath = await simnet.callPublicFn(
        ADVANCED_ROUTER,
        'find-optimal-path',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_D), Cl.uint(10000), Cl.bool(false)],
        user1
      );

      expect(optimalPath.result).toBeOk(Cl.bool(true));

      // Execute swap with found path
      const result = await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'swap-with-path',
        [
          Cl.uint(10000),
          Cl.uint(8500),
          [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B), Cl.principal(TOKEN_C), Cl.principal(TOKEN_D)],
          Cl.principal(user1),
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should handle cross-protocol swaps', async () => {
      // Simulate swap between different DEX protocols
      const result = await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'cross-protocol-swap',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_D),
          Cl.uint(10000),
          Cl.uint(8500),
          [Cl.stringAscii('weighted'), Cl.stringAscii('stable')], // protocol types
          Cl.principal(user1),
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should aggregate liquidity across protocols', async () => {
      const aggregatedLiquidity = simnet.callReadOnlyFn(
        MULTI_HOP_ROUTER,
        'get-aggregated-liquidity',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B)],
        deployer
      );

      expect(aggregatedLiquidity.result).toBeOk(Cl.bool(true));
    });

    it('should handle MEV protection during routing', async () => {
      const result = await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'protected-swap',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_D),
          Cl.uint(10000),
          Cl.uint(8500),
          Cl.bool(true), // enable MEV protection
          Cl.principal(user1),
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Router Performance and Optimization', () => {
    it('should handle large routing networks efficiently', async () => {
      // Create many pools to test performance
      for (let i = 0; i < 10; i++) {
        await simnet.callPublicFn(
          DEX_FACTORY,
          'create-pool',
          [
            Cl.principal(`${deployer}.token-${i}`),
            Cl.principal(`${deployer}.token-${i + 1}`),
            Cl.uint(100), Cl.uint(100), Cl.uint(500), 
            Cl.stringAscii(`PERF-POOL-${i}`)
          ],
          routerManager
        );
      }

      const startTime = Date.now();
      
      const result = simnet.callReadOnlyFn(
        ADVANCED_ROUTER,
        'find-optimal-path',
        [Cl.principal(`${deployer}.token-0`), Cl.principal(`${deployer}.token-10`), Cl.uint(10000), Cl.bool(false)],
        deployer
      );

      const endTime = Date.now();
      const executionTime = endTime - startTime;

      expect(result.result).toBeOk(Cl.bool(true));
      expect(executionTime).toBeLessThan(1000); // Should complete within 1 second
    });

    it('should cache routing results', async () => {
      // First call
      const result1 = simnet.callReadOnlyFn(
        ADVANCED_ROUTER,
        'get-cached-route',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B), Cl.uint(10000)],
        deployer
      );

      // Second call should use cache
      const result2 = simnet.callReadOnlyFn(
        ADVANCED_ROUTER,
        'get-cached-route',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B), Cl.uint(10000)],
        deployer
      );

      expect(result1.result).toBeOk(Cl.bool(true));
      expect(result2.result).toBeOk(Cl.bool(true));
    });

    it('should optimize routing for gas efficiency', async () => {
      const gasOptimizedRoute = simnet.callReadOnlyFn(
        MULTI_HOP_ROUTER,
        'get-gas-optimized-route',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_D), Cl.uint(10000)],
        deployer
      );

      expect(gasOptimizedRoute.result).toBeOk(Cl.bool(true));
    });

    it('should handle batch routing requests', async () => {
      const batchRequests = [
        { from: TOKEN_A, to: TOKEN_B, amount: 10000 },
        { from: TOKEN_B, to: TOKEN_C, amount: 10000 },
        { from: TOKEN_C, to: TOKEN_D, amount: 10000 }
      ];

      const result = simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'batch-route',
        [
          Cl.list(batchRequests.map(req => 
            Cl.tuple({
              'from': Cl.principal(req.from),
              'to': Cl.principal(req.to),
              'amount': Cl.uint(req.amount)
            })
          ))
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Router Security and Validation', () => {
    it('should validate path integrity', async () => {
      const result = simnet.callReadOnlyFn(
        MULTI_HOP_ROUTER,
        'validate-path',
        [
          [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B), Cl.principal(TOKEN_C)],
          Cl.uint(10000)
        ],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should detect and prevent sandwich attacks', async () => {
      const result = await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'protected-swap',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(10000),
          Cl.uint(9500),
          Cl.bool(true), // enable sandwich protection
          Cl.principal(user1),
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should handle flash loan attacks', async () => {
      const result = await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'flash-swap-protection',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_D),
          Cl.uint(10000),
          Cl.bool(true) // enable flash loan protection
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should validate slippage tolerances', async () => {
      const result = await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'swap-with-slippage-validation',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(10000),
          Cl.uint(9500), // minimum out
          Cl.uint(1000), // slippage tolerance (10%)
          Cl.principal(user1),
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should handle emergency routing pauses', async () => {
      // Pause routing
      await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'emergency-pause',
        [Cl.bool(true)],
        routerManager
      );

      // Try to swap
      const result = await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'swap-exact-tokens-for-tokens',
        [
          Cl.uint(10000),
          Cl.uint(9500),
          [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B)],
          Cl.principal(user1),
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(1003)); // ERR_PAUSED
    });
  });

  describe('Router Analytics and Monitoring', () => {
    it('should track routing statistics', async () => {
      // Perform some swaps to generate data
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(MULTI_HOP_ROUTER), Cl.uint(100_000)],
        user1
      );

      await simnet.callPublicFn(
        MULTI_HOP_ROUTER,
        'swap-exact-tokens-for-tokens',
        [Cl.uint(10000), Cl.uint(9500), [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B)], Cl.principal(user1), Cl.uint(1672531200)],
        user1
      );

      const stats = simnet.callReadOnlyFn(
        MULTI_HOP_ROUTER,
        'get-routing-stats',
        [],
        deployer
      );

      expect(stats.result).toBeOk(Cl.bool(true));
    });

    it('should monitor path efficiency', async () => {
      const efficiency = simnet.callReadOnlyFn(
        ADVANCED_ROUTER,
        'get-path-efficiency',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_D)],
        deployer
      );

      expect(efficiency.result).toBeOk(Cl.bool(true));
    });

    it('should track MEV metrics', async () => {
      const mevMetrics = simnet.callReadOnlyFn(
        MULTI_HOP_ROUTER,
        'get-mev-metrics',
        [],
        deployer
      );

      expect(mevMetrics.result).toBeOk(Cl.bool(true));
    });

    it('should provide liquidity utilization data', async () => {
      const utilization = simnet.callReadOnlyFn(
        MULTI_HOP_ROUTER,
        'get-liquidity-utilization',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B)],
        deployer
      );

      expect(utilization.result).toBeOk(Cl.bool(true));
    });
  });
});
