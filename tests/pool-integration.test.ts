import { Cl } from '@stacks/transactions';

// Comprehensive Pool Type Integration Tests
describe('Conxian Pool Type Integration Tests', () => {
  let deployer: string;
  let user1: string;
  let user2: string;
  let factoryContract: string;
  let concentratedPoolContract: string;
  let stablePoolContract: string;
  let weightedPoolContract: string;
  let constantProductPoolContract: string;

  beforeEach(() => {
    deployer = 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6';
    user1 = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
    user2 = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
    factoryContract = `${deployer}.dex-factory-v2`;
    concentratedPoolContract = `${deployer}.concentrated-liquidity-pool`;
    stablePoolContract = `${deployer}.stable-pool-enhanced`;
    weightedPoolContract = `${deployer}.weighted-pool`;
    constantProductPoolContract = `${deployer}.dex-pool`;
  });

  describe('Factory Pool Creation Tests', () => {
    it('should initialize factory with all pool types', async () => {
      const result = simnet.callPublicFn(
        factoryContract,
        'initialize-factory',
        [],
        deployer
      );

      expect(result.result).toBeOk();

      // Verify all pool types are registered
      const constantProductImpl = simnet.callReadOnlyFn(
        factoryContract,
        'get-pool-implementation',
        [Cl.stringAscii('constant-product')],
        deployer
      );

      expect(constantProductImpl.result).toBeSome();
      const implData = constantProductImpl.result.expectSome().expectTuple();
      expect(implData['enabled']).toBeBool(true);
    });

    it('should create constant product pool', async () => {
      // Initialize factory first
      await simnet.callPublicFn(factoryContract, 'initialize-factory', [], deployer);

      const result = simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('constant-product'),
          Cl.uint(300), // 0.3% fee
          Cl.none()
        ],
        deployer
      );

      expect(result.result).toBeOk();
      const poolData = result.result.expectOk().expectTuple();
      expect(poolData['pool-type']).toBeStringAscii('constant-product');
      expect(poolData['fee-tier']).toBeUint(300);
    });

    it('should create concentrated liquidity pool', async () => {
      await simnet.callPublicFn(factoryContract, 'initialize-factory', [], deployer);

      const result = simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('concentrated'),
          Cl.uint(50), // 0.05% fee
          Cl.none()
        ],
        deployer
      );

      expect(result.result).toBeOk();
      const poolData = result.result.expectOk().expectTuple();
      expect(poolData['pool-type']).toBeStringAscii('concentrated');
      expect(poolData['fee-tier']).toBeUint(50);
    });

    it('should create stable pool with amplification parameter', async () => {
      await simnet.callPublicFn(factoryContract, 'initialize-factory', [], deployer);

      const stableParams = Cl.some(Cl.tuple({
        'weight-0': Cl.uint(5000), // Not used for stable pools
        'weight-1': Cl.uint(5000), // Not used for stable pools
        'amp': Cl.uint(100) // Amplification parameter
      }));

      const result = simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.usdc`),
          Cl.principal(`${deployer}.usdt`),
          Cl.stringAscii('stable'),
          Cl.uint(50), // 0.05% fee for stables
          stableParams
        ],
        deployer
      );

      expect(result.result).toBeOk();
      const poolData = result.result.expectOk().expectTuple();
      expect(poolData['pool-type']).toBeStringAscii('stable');
    });

    it('should create weighted pool with custom weights', async () => {
      await simnet.callPublicFn(factoryContract, 'initialize-factory', [], deployer);

      const weightedParams = Cl.some(Cl.tuple({
        'weight-0': Cl.uint(8000), // 80%
        'weight-1': Cl.uint(2000), // 20%
        'amp': Cl.uint(0) // Not used for weighted pools
      }));

      const result = simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.btc`),
          Cl.principal(`${deployer}.eth`),
          Cl.stringAscii('weighted'),
          Cl.uint(300), // 0.3% fee
          weightedParams
        ],
        deployer
      );

      expect(result.result).toBeOk();
      const poolData = result.result.expectOk().expectTuple();
      expect(poolData['pool-type']).toBeStringAscii('weighted');
    });

    it('should reject invalid pool parameters', async () => {
      await simnet.callPublicFn(factoryContract, 'initialize-factory', [], deployer);

      // Test invalid weights (don't sum to 100%)
      const invalidWeights = Cl.some(Cl.tuple({
        'weight-0': Cl.uint(6000), // 60%
        'weight-1': Cl.uint(3000), // 30% - only 90% total
        'amp': Cl.uint(0)
      }));

      const result = simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('weighted'),
          Cl.uint(300),
          invalidWeights
        ],
        deployer
      );

      expect(result.result).toBeErr();
    });

    it('should prevent duplicate pool creation', async () => {
      await simnet.callPublicFn(factoryContract, 'initialize-factory', [], deployer);

      // Create first pool
      const firstResult = simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('constant-product'),
          Cl.uint(300),
          Cl.none()
        ],
        deployer
      );

      expect(firstResult.result).toBeOk();

      // Try to create duplicate pool
      const duplicateResult = simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('constant-product'),
          Cl.uint(300),
          Cl.none()
        ],
        deployer
      );

      expect(duplicateResult.result).toBeErr();
      expect(duplicateResult.result.expectErr()).toBeUint(6001); // ERR_POOL_ALREADY_EXISTS
    });
  });

  describe('Pool Discovery and Enumeration Tests', () => {
    beforeEach(async () => {
      await simnet.callPublicFn(factoryContract, 'initialize-factory', [], deployer);
    });

    it('should find existing pools by token pair', async () => {
      // Create multiple pool types for same token pair
      await simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('constant-product'),
          Cl.uint(300),
          Cl.none()
        ],
        deployer
      );

      await simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('concentrated'),
          Cl.uint(300),
          Cl.none()
        ],
        deployer
      );

      // Test pool discovery
      const constantProductPool = simnet.callReadOnlyFn(
        factoryContract,
        'get-pool',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('constant-product'),
          Cl.uint(300)
        ],
        deployer
      );

      expect(constantProductPool.result).toBeSome();

      const concentratedPool = simnet.callReadOnlyFn(
        factoryContract,
        'get-pool',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('concentrated'),
          Cl.uint(300)
        ],
        deployer
      );

      expect(concentratedPool.result).toBeSome();
    });

    it('should get all pools for token pair', async () => {
      // Create multiple pools for same pair
      await simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('constant-product'),
          Cl.uint(300),
          Cl.none()
        ],
        deployer
      );

      const poolsForPair = simnet.callReadOnlyFn(
        factoryContract,
        'get-pools-for-pair',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`)
        ],
        deployer
      );

      expect(poolsForPair.result).toBeList();
      const pools = poolsForPair.result.expectList();
      expect(pools.length).toBeGreaterThan(0);
    });

    it('should validate pool parameters correctly', async () => {
      // Test weighted pool parameter validation
      const validWeights = Cl.some(Cl.tuple({
        'weight-0': Cl.uint(7000), // 70%
        'weight-1': Cl.uint(3000), // 30%
        'amp': Cl.uint(0)
      }));

      const validationResult = simnet.callPublicFn(
        factoryContract,
        'validate-pool-parameters',
        [
          Cl.stringAscii('weighted'),
          Cl.uint(300),
          validWeights
        ],
        deployer
      );

      expect(validationResult.result).toBeOk();

      // Test invalid amplification for stable pool
      const invalidAmp = Cl.some(Cl.tuple({
        'weight-0': Cl.uint(5000),
        'weight-1': Cl.uint(5000),
        'amp': Cl.uint(10000) // Too high
      }));

      const invalidValidation = simnet.callPublicFn(
        factoryContract,
        'validate-pool-parameters',
        [
          Cl.stringAscii('stable'),
          Cl.uint(50),
          invalidAmp
        ],
        deployer
      );

      expect(invalidValidation.result).toBeErr();
    });
  });

  describe('Cross-Pool Compatibility Tests', () => {
    beforeEach(async () => {
      await simnet.callPublicFn(factoryContract, 'initialize-factory', [], deployer);
    });

    it('should maintain consistent interfaces across pool types', async () => {
      // Create pools of different types
      const constantProductResult = await simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('constant-product'),
          Cl.uint(300),
          Cl.none()
        ],
        deployer
      );

      const weightedResult = await simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-c`),
          Cl.principal(`${deployer}.token-d`),
          Cl.stringAscii('weighted'),
          Cl.uint(300),
          Cl.some(Cl.tuple({
            'weight-0': Cl.uint(6000),
            'weight-1': Cl.uint(4000),
            'amp': Cl.uint(0)
          }))
        ],
        deployer
      );

      expect(constantProductResult.result).toBeOk();
      expect(weightedResult.result).toBeOk();

      // Both should have consistent metadata structure
      const cpPoolData = constantProductResult.result.expectOk().expectTuple();
      const weightedPoolData = weightedResult.result.expectOk().expectTuple();

      // Check consistent fields
      expect(cpPoolData).toHaveProperty('pool-id');
      expect(cpPoolData).toHaveProperty('pool-address');
      expect(cpPoolData).toHaveProperty('pool-type');
      expect(cpPoolData).toHaveProperty('fee-tier');

      expect(weightedPoolData).toHaveProperty('pool-id');
      expect(weightedPoolData).toHaveProperty('pool-address');
      expect(weightedPoolData).toHaveProperty('pool-type');
      expect(weightedPoolData).toHaveProperty('fee-tier');
    });

    it('should support different fee tiers per pool type', async () => {
      // Test concentrated pool with low fee
      const concentratedResult = await simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.usdc`),
          Cl.principal(`${deployer}.usdt`),
          Cl.stringAscii('concentrated'),
          Cl.uint(50), // 0.05% fee
          Cl.none()
        ],
        deployer
      );

      expect(concentratedResult.result).toBeOk();

      // Test weighted pool with higher fee
      const weightedResult = await simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.btc`),
          Cl.principal(`${deployer}.eth`),
          Cl.stringAscii('weighted'),
          Cl.uint(1000), // 1% fee
          Cl.some(Cl.tuple({
            'weight-0': Cl.uint(5000),
            'weight-1': Cl.uint(5000),
            'amp': Cl.uint(0)
          }))
        ],
        deployer
      );

      expect(weightedResult.result).toBeOk();

      // Verify fee tiers are correctly set
      const concentratedData = concentratedResult.result.expectOk().expectTuple();
      const weightedData = weightedResult.result.expectOk().expectTuple();

      expect(concentratedData['fee-tier']).toBeUint(50);
      expect(weightedData['fee-tier']).toBeUint(1000);
    });

    it('should handle token ordering consistently', async () => {
      // Create pool with tokens in one order
      const result1 = await simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-z`), // Higher lexicographic order
          Cl.principal(`${deployer}.token-a`), // Lower lexicographic order
          Cl.stringAscii('constant-product'),
          Cl.uint(300),
          Cl.none()
        ],
        deployer
      );

      expect(result1.result).toBeOk();
      const poolData = result1.result.expectOk().expectTuple();

      // Tokens should be ordered consistently (token-a < token-z)
      expect(poolData['token-0']).toBePrincipal(`${deployer}.token-a`);
      expect(poolData['token-1']).toBePrincipal(`${deployer}.token-z`);

      // Try to create same pool with reversed token order - should fail
      const result2 = simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-z`),
          Cl.stringAscii('constant-product'),
          Cl.uint(300),
          Cl.none()
        ],
        deployer
      );

      expect(result2.result).toBeErr();
      expect(result2.result.expectErr()).toBeUint(6001); // ERR_POOL_ALREADY_EXISTS
    });
  });

  describe('Pool Migration and Upgrade Tests', () => {
    beforeEach(async () => {
      await simnet.callPublicFn(factoryContract, 'initialize-factory', [], deployer);
    });

    it('should support pool implementation migration', async () => {
      // Create a pool
      const createResult = await simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('constant-product'),
          Cl.uint(300),
          Cl.none()
        ],
        deployer
      );

      expect(createResult.result).toBeOk();
      const poolData = createResult.result.expectOk().expectTuple();
      const poolId = poolData['pool-id'];

      // Migrate pool to new implementation
      const migrateResult = simnet.callPublicFn(
        factoryContract,
        'migrate-pool',
        [
          Cl.uint(poolId),
          Cl.principal(`${deployer}.new-dex-pool`)
        ],
        deployer
      );

      expect(migrateResult.result).toBeOk();
    });

    it('should maintain pool metadata during migration', async () => {
      // Create pool and get metadata
      const createResult = await simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('weighted'),
          Cl.uint(300),
          Cl.some(Cl.tuple({
            'weight-0': Cl.uint(7000),
            'weight-1': Cl.uint(3000),
            'amp': Cl.uint(0)
          }))
        ],
        deployer
      );

      const poolData = createResult.result.expectOk().expectTuple();
      const poolId = poolData['pool-id'];

      // Get metadata before migration
      const metadataBefore = simnet.callReadOnlyFn(
        factoryContract,
        'get-pool-metadata',
        [Cl.uint(poolId)],
        deployer
      );

      expect(metadataBefore.result).toBeSome();

      // Migrate pool
      await simnet.callPublicFn(
        factoryContract,
        'migrate-pool',
        [
          Cl.uint(poolId),
          Cl.principal(`${deployer}.new-weighted-pool`)
        ],
        deployer
      );

      // Get metadata after migration
      const metadataAfter = simnet.callReadOnlyFn(
        factoryContract,
        'get-pool-metadata',
        [Cl.uint(poolId)],
        deployer
      );

      expect(metadataAfter.result).toBeSome();

      // Metadata should be preserved
      const beforeData = metadataBefore.result.expectSome().expectTuple();
      const afterData = metadataAfter.result.expectSome().expectTuple();

      expect(afterData['token-0']).toEqual(beforeData['token-0']);
      expect(afterData['token-1']).toEqual(beforeData['token-1']);
      expect(afterData['pool-type']).toEqual(beforeData['pool-type']);
      expect(afterData['fee-tier']).toEqual(beforeData['fee-tier']);
    });
  });

  describe('Pool Statistics and Analytics Tests', () => {
    beforeEach(async () => {
      await simnet.callPublicFn(factoryContract, 'initialize-factory', [], deployer);
    });

    it('should track pool statistics correctly', async () => {
      // Create a pool
      const createResult = await simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('constant-product'),
          Cl.uint(300),
          Cl.none()
        ],
        deployer
      );

      const poolData = createResult.result.expectOk().expectTuple();
      const poolId = poolData['pool-id'];

      // Update pool statistics
      const updateResult = simnet.callPublicFn(
        factoryContract,
        'update-pool-stats',
        [
          Cl.uint(poolId),
          Cl.uint(1000000), // volume 24h
          Cl.uint(3000),    // fees 24h
          Cl.uint(5)        // LP count
        ],
        deployer
      );

      expect(updateResult.result).toBeOk();

      // Get pool statistics
      const statsResult = simnet.callReadOnlyFn(
        factoryContract,
        'get-pool-stats',
        [Cl.uint(poolId)],
        deployer
      );

      expect(statsResult.result).toBeSome();
      const stats = statsResult.result.expectSome().expectTuple();
      expect(stats['total-volume-24h']).toBeUint(1000000);
      expect(stats['total-fees-24h']).toBeUint(3000);
      expect(stats['liquidity-providers']).toBeUint(5);
    });

    it('should provide pool utilization metrics', async () => {
      // Create multiple pools
      const pools = [];
      for (let i = 0; i < 3; i++) {
        const result = await simnet.callPublicFn(
          factoryContract,
          'create-pool-typed',
          [
            Cl.principal(`${deployer}.token-${i}`),
            Cl.principal(`${deployer}.token-${i + 1}`),
            Cl.stringAscii('constant-product'),
            Cl.uint(300),
            Cl.none()
          ],
          deployer
        );
        pools.push(result.result.expectOk().expectTuple()['pool-id']);
      }

      // Update stats for each pool
      for (let i = 0; i < pools.length; i++) {
        await simnet.callPublicFn(
          factoryContract,
          'update-pool-stats',
          [
            Cl.uint(pools[i]),
            Cl.uint((i + 1) * 100000), // Different volumes
            Cl.uint((i + 1) * 1000),   // Different fees
            Cl.uint(i + 2)             // Different LP counts
          ],
          deployer
        );
      }

      // Get utilization metrics for each pool
      for (let i = 0; i < pools.length; i++) {
        const metricsResult = simnet.callReadOnlyFn(
          factoryContract,
          'get-pool-utilization-metrics',
          [Cl.uint(pools[i])],
          deployer
        );

        expect(metricsResult.result).toBeTuple();
        const metrics = metricsResult.result.expectTuple();
        expect(metrics['volume-24h']).toBeUint((i + 1) * 100000);
        expect(metrics['fees-24h']).toBeUint((i + 1) * 1000);
        expect(metrics['lp-count']).toBeUint(i + 2);
      }
    });

    it('should get factory configuration', async () => {
      const configResult = simnet.callReadOnlyFn(
        factoryContract,
        'get-factory-config',
        [],
        deployer
      );

      expect(configResult.result).toBeTuple();
      const config = configResult.result.expectTuple();
      expect(config['enabled']).toBeBool(true);
      expect(config['protocol-fee-bps']).toBeUint(0);
      expect(config['supported-types']).toBeList();
    });

    it('should track total pools created', async () => {
      // Get initial count
      const initialCount = simnet.callReadOnlyFn(
        factoryContract,
        'get-total-pools',
        [],
        deployer
      );

      const initialTotal = initialCount.result.expectUint();

      // Create a few pools
      for (let i = 0; i < 3; i++) {
        await simnet.callPublicFn(
          factoryContract,
          'create-pool-typed',
          [
            Cl.principal(`${deployer}.token-${i}`),
            Cl.principal(`${deployer}.token-${i + 10}`),
            Cl.stringAscii('constant-product'),
            Cl.uint(300),
            Cl.none()
          ],
          deployer
        );
      }

      // Check updated count
      const finalCount = simnet.callReadOnlyFn(
        factoryContract,
        'get-total-pools',
        [],
        deployer
      );

      const finalTotal = finalCount.result.expectUint();
      expect(Number(finalTotal)).toBe(Number(initialTotal) + 3);
    });
  });

  describe('Administrative Functions Tests', () => {
    beforeEach(async () => {
      await simnet.callPublicFn(factoryContract, 'initialize-factory', [], deployer);
    });

    it('should allow admin to enable/disable pool types', async () => {
      // Disable concentrated pools
      const disableResult = simnet.callPublicFn(
        factoryContract,
        'set-pool-type-enabled',
        [
          Cl.stringAscii('concentrated'),
          Cl.bool(false)
        ],
        deployer
      );

      expect(disableResult.result).toBeOk();

      // Try to create disabled pool type
      const createResult = simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('concentrated'),
          Cl.uint(50),
          Cl.none()
        ],
        deployer
      );

      expect(createResult.result).toBeErr();

      // Re-enable and try again
      await simnet.callPublicFn(
        factoryContract,
        'set-pool-type-enabled',
        [
          Cl.stringAscii('concentrated'),
          Cl.bool(true)
        ],
        deployer
      );

      const createResult2 = simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('concentrated'),
          Cl.uint(50),
          Cl.none()
        ],
        deployer
      );

      expect(createResult2.result).toBeOk();
    });

    it('should allow admin to set protocol fee', async () => {
      const setFeeResult = simnet.callPublicFn(
        factoryContract,
        'set-protocol-fee',
        [Cl.uint(500)], // 5%
        deployer
      );

      expect(setFeeResult.result).toBeOk();

      // Verify fee was set
      const configResult = simnet.callReadOnlyFn(
        factoryContract,
        'get-factory-config',
        [],
        deployer
      );

      const config = configResult.result.expectTuple();
      expect(config['protocol-fee-bps']).toBeUint(500);
    });

    it('should reject unauthorized admin actions', async () => {
      // Try to disable pool type as non-admin
      const unauthorizedResult = simnet.callPublicFn(
        factoryContract,
        'set-pool-type-enabled',
        [
          Cl.stringAscii('concentrated'),
          Cl.bool(false)
        ],
        user1 // Not the admin
      );

      expect(unauthorizedResult.result).toBeErr();
      expect(unauthorizedResult.result.expectErr()).toBeUint(6000); // ERR_UNAUTHORIZED
    });

    it('should allow adding new pool implementations', async () => {
      const addImplResult = simnet.callPublicFn(
        factoryContract,
        'add-pool-implementation',
        [
          Cl.stringAscii('custom-pool'),
          Cl.principal(`${deployer}.custom-pool-impl`),
          Cl.list([Cl.uint(100), Cl.uint(500)]), // Fee tiers
          Cl.uint(1000), // Min liquidity
          Cl.uint(10000) // Max positions
        ],
        deployer
      );

      expect(addImplResult.result).toBeOk();

      // Verify implementation was added
      const implResult = simnet.callReadOnlyFn(
        factoryContract,
        'get-pool-implementation',
        [Cl.stringAscii('custom-pool')],
        deployer
      );

      expect(implResult.result).toBeSome();
      const implData = implResult.result.expectSome().expectTuple();
      expect(implData['enabled']).toBeBool(true);
      expect(implData['min-liquidity']).toBeUint(1000);
    });
  });

  describe('Error Handling and Edge Cases', () => {
    beforeEach(async () => {
      await simnet.callPublicFn(factoryContract, 'initialize-factory', [], deployer);
    });

    it('should handle invalid pool type gracefully', async () => {
      const result = simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('invalid-type'),
          Cl.uint(300),
          Cl.none()
        ],
        deployer
      );

      expect(result.result).toBeErr();
      expect(result.result.expectErr()).toBeUint(6002); // ERR_INVALID_POOL_TYPE
    });

    it('should handle invalid fee tier gracefully', async () => {
      const result = simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('constant-product'),
          Cl.uint(999), // Invalid fee tier
          Cl.none()
        ],
        deployer
      );

      expect(result.result).toBeErr();
      expect(result.result.expectErr()).toBeUint(6003); // ERR_INVALID_FEE_TIER
    });

    it('should handle same token pair gracefully', async () => {
      const result = simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-a`), // Same token
          Cl.stringAscii('constant-product'),
          Cl.uint(300),
          Cl.none()
        ],
        deployer
      );

      expect(result.result).toBeErr();
      expect(result.result.expectErr()).toBeUint(6004); // ERR_INVALID_TOKENS
    });

    it('should handle factory disabled state', async () => {
      // Disable factory
      await simnet.callPublicFn(
        factoryContract,
        'set-factory-enabled',
        [Cl.bool(false)],
        deployer
      );

      // Try to create pool
      const result = simnet.callPublicFn(
        factoryContract,
        'create-pool-typed',
        [
          Cl.principal(`${deployer}.token-a`),
          Cl.principal(`${deployer}.token-b`),
          Cl.stringAscii('constant-product'),
          Cl.uint(300),
          Cl.none()
        ],
        deployer
      );

      expect(result.result).toBeErr();
      expect(result.result.expectErr()).toBeUint(6000); // ERR_UNAUTHORIZED
    });

    it('should handle non-existent pool queries', async () => {
      const result = simnet.callReadOnlyFn(
        factoryContract,
        'get-pool',
        [
          Cl.principal(`${deployer}.nonexistent-a`),
          Cl.principal(`${deployer}.nonexistent-b`),
          Cl.stringAscii('constant-product'),
          Cl.uint(300)
        ],
        deployer
      );

      expect(result.result).toBeNone();
    });

    it('should handle invalid pool ID queries', async () => {
      const result = simnet.callReadOnlyFn(
        factoryContract,
        'get-pool-metadata',
        [Cl.uint(999999)], // Non-existent pool ID
        deployer
      );

      expect(result.result).toBeNone();
    });
  });
});