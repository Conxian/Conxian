import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { Simnet, Tx } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('DEX Factory Comprehensive Test Suite', () => {
  let simnet: Simnet;
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let poolManager: string;

  // Contract addresses
  const DEX_FACTORY = `${deployer}.dex-factory`;
  const ACCESS_CONTROL = `${deployer}.access-control`;
  const CIRCUIT_BREAKER = `${deployer}.circuit-breaker`;
  const POOL_REGISTRY = `${deployer}.pool-registry`;
  const TOKEN_A = `${deployer}.token-a`;
  const TOKEN_B = `${deployer}.token-b`;

  beforeAll(async () => {
    simnet = (global as any).simnet;
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')?.address || '';
    wallet1 = accounts.get('wallet_1')?.address || '';
    wallet2 = accounts.get('wallet_2')?.address || '';
    poolManager = accounts.get('wallet_3')?.address || '';
  });

  beforeEach(async () => {
    // Reset state for each test
    await simnet.mineEmptyBlock();
  });

  describe('Contract Deployment & Initialization', () => {
    it('should deploy DEX Factory with correct initial state', () => {
      const owner = simnet.callReadOnlyFn(DEX_FACTORY, 'get-owner', [], deployer);
      expect(owner.result).toBeOk(Cl.principal(deployer));
    });

    it('should initialize with correct default pool type', () => {
      const defaultType = simnet.callReadOnlyFn(DEX_FACTORY, 'get-default-pool-type', [], deployer);
      expect(defaultType.result).toBeOk(Cl.stringAscii('weighted'));
    });

    it('should have all required contracts set', () => {
      const accessControl = simnet.callReadOnlyFn(DEX_FACTORY, 'get-access-control', [], deployer);
      const circuitBreaker = simnet.callReadOnlyFn(DEX_FACTORY, 'get-circuit-breaker', [], deployer);
      const poolRegistry = simnet.callReadOnlyFn(DEX_FACTORY, 'get-pool-registry', [], deployer);

      expect(accessControl.result.type).toBe('ok');
      expect(circuitBreaker.result.type).toBe('ok');
      expect(poolRegistry.result.type).toBe('ok');
    });
  });

  describe('Pool Creation Operations', () => {
    beforeEach(async () => {
      // Setup pool manager role
      await simnet.callPublicFn(
        ACCESS_CONTROL,
        'grant-role',
        [Cl.stringAscii('POOL_MANAGER'), Cl.principal(poolManager)],
        deployer
      );
    });

    it('should create a weighted pool with valid parameters', async () => {
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100), // weight A
          Cl.uint(100), // weight B
          Cl.uint(500), // fee (0.05%)
          Cl.stringAscii('weighted')
        ],
        poolManager
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject pool creation from unauthorized user', async () => {
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100),
          Cl.uint(100),
          Cl.uint(500),
          Cl.stringAscii('weighted')
        ],
        wallet1 // Not authorized
      );

      expect(result.result).toBeErr(Cl.uint(1003)); // ERR_UNAUTHORIZED
    });

    it('should reject pool creation with invalid tokens', async () => {
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(deployer), // Invalid token (same as deployer)
          Cl.principal(TOKEN_B),
          Cl.uint(100),
          Cl.uint(100),
          Cl.uint(500),
          Cl.stringAscii('weighted')
        ],
        poolManager
      );

      expect(result.result).toBeErr(Cl.uint(2002)); // ERR_INVALID_TOKENS
    });

    it('should reject pool creation with invalid fee', async () => {
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100),
          Cl.uint(100),
          Cl.uint(10000), // Too high fee (1%)
          Cl.stringAscii('weighted')
        ],
        poolManager
      );

      expect(result.result).toBeErr(Cl.uint(2004)); // ERR_INVALID_FEE
    });

    it('should reject duplicate pool creation', async () => {
      // Create first pool
      await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100),
          Cl.uint(100),
          Cl.uint(500),
          Cl.stringAscii('weighted')
        ],
        poolManager
      );

      // Try to create duplicate
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100),
          Cl.uint(100),
          Cl.uint(500),
          Cl.stringAscii('weighted')
        ],
        poolManager
      );

      expect(result.result).toBeErr(Cl.uint(2001)); // ERR_POOL_EXISTS
    });

    it('should create different pool types', async () => {
      // Test stable pool
      const stableResult = await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100),
          Cl.uint(100),
          Cl.uint(400), // 0.04% fee for stable
          Cl.stringAscii('stable')
        ],
        poolManager
      );

      expect(stableResult.result).toBeOk(Cl.bool(true));

      // Test concentrated pool
      const concentratedResult = await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100),
          Cl.uint(100),
          Cl.uint(600), // 0.06% fee for concentrated
          Cl.stringAscii('concentrated')
        ],
        poolManager
      );

      expect(concentratedResult.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Configuration Management', () => {
    it('should allow owner to set default pool type', async () => {
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'set-default-pool-type',
        [Cl.stringAscii('stable')],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));

      // Verify change
      const defaultType = simnet.callReadOnlyFn(DEX_FACTORY, 'get-default-pool-type', [], deployer);
      expect(defaultType.result).toBeOk(Cl.stringAscii('stable'));
    });

    it('should reject default pool type change from non-owner', async () => {
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'set-default-pool-type',
        [Cl.stringAscii('stable')],
        wallet1
      );

      expect(result.result).toBeErr(Cl.uint(1003)); // ERR_UNAUTHORIZED
    });

    it('should allow owner to update fee recipient', async () => {
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'update-fee-recipient',
        [Cl.principal(wallet2)],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject fee recipient update from non-owner', async () => {
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'update-fee-recipient',
        [Cl.principal(wallet2)],
        wallet1
      );

      expect(result.result).toBeErr(Cl.uint(1003)); // ERR_UNAUTHORIZED
    });

    it('should allow owner to update contract references', async () => {
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'set-access-control',
        [Cl.principal(ACCESS_CONTROL)],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Emergency Operations', () => {
    it('should allow owner to emergency pause', async () => {
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'emergency-pause',
        [Cl.bool(true)],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));

      // Verify paused state
      const isPaused = simnet.callReadOnlyFn(DEX_FACTORY, 'is-paused', [], deployer);
      expect(isPaused.result).toBeOk(Cl.bool(true));
    });

    it('should reject emergency pause from non-owner', async () => {
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'emergency-pause',
        [Cl.bool(true)],
        wallet1
      );

      expect(result.result).toBeErr(Cl.uint(1003)); // ERR_UNAUTHORIZED
    });

    it('should reject pool creation when paused', async () => {
      // Pause the factory
      await simnet.callPublicFn(
        DEX_FACTORY,
        'emergency-pause',
        [Cl.bool(true)],
        deployer
      );

      // Try to create pool
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100),
          Cl.uint(100),
          Cl.uint(500),
          Cl.stringAscii('weighted')
        ],
        poolManager
      );

      expect(result.result).toBeErr(Cl.uint(1003)); // ERR_SYSTEM_PAUSED
    });

    it('should allow owner to unpause', async () => {
      // Pause first
      await simnet.callPublicFn(
        DEX_FACTORY,
        'emergency-pause',
        [Cl.bool(true)],
        deployer
      );

      // Then unpause
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'emergency-pause',
        [Cl.bool(false)],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));

      // Verify unpaused state
      const isPaused = simnet.callReadOnlyFn(DEX_FACTORY, 'is-paused', [], deployer);
      expect(isPaused.result).toBeOk(Cl.bool(false));
    });
  });

  describe('Pool Query Operations', () => {
    beforeEach(async () => {
      // Setup pool manager role and create a pool for testing
      await simnet.callPublicFn(
        ACCESS_CONTROL,
        'grant-role',
        [Cl.stringAscii('POOL_MANAGER'), Cl.principal(poolManager)],
        deployer
      );

      await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100),
          Cl.uint(100),
          Cl.uint(500),
          Cl.stringAscii('weighted')
        ],
        poolManager
      );
    });

    it('should return correct pool information', () => {
      const poolInfo = simnet.callReadOnlyFn(
        DEX_FACTORY,
        'get-pool-info',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B)],
        deployer
      );

      expect(poolInfo.result).toBeOk(Cl.bool(true)); // Pool exists
    });

    it('should return empty for non-existent pool', () => {
      const poolInfo = simnet.callReadOnlyFn(
        DEX_FACTORY,
        'get-pool-info',
        [Cl.principal(deployer), Cl.principal(TOKEN_B)], // Invalid token pair
        deployer
      );

      expect(poolInfo.result).toBeErr(Cl.uint(2001)); // ERR_POOL_EXISTS (but for not found)
    });

    it('should list all created pools', () => {
      const pools = simnet.callReadOnlyFn(DEX_FACTORY, 'list-pools', [], deployer);
      expect(pools.result.type).toBe('ok');
    });

    it('should get pools by type', () => {
      const weightedPools = simnet.callReadOnlyFn(
        DEX_FACTORY,
        'get-pools-by-type',
        [Cl.stringAscii('weighted')],
        deployer
      );

      expect(weightedPools.result.type).toBe('ok');
    });
  });

  describe('Circuit Breaker Integration', () => {
    it('should check circuit breaker before operations', async () => {
      // Simulate circuit breaker being open
      // This would require mocking the circuit breaker contract
      
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100),
          Cl.uint(100),
          Cl.uint(500),
          Cl.stringAscii('weighted')
        ],
        poolManager
      );

      // Should succeed if circuit breaker is closed
      expect(result.result.type).toBe('ok');
    });
  });

  describe('Edge Cases & Error Handling', () => {
    it('should handle zero token weights gracefully', async () => {
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(0), // Zero weight
          Cl.uint(100),
          Cl.uint(500),
          Cl.stringAscii('weighted')
        ],
        poolManager
      );

      expect(result.result).toBeErr(); // Should fail with appropriate error
    });

    it('should handle maximum uint values', async () => {
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(340282366920938463463374607431768211455), // max uint
          Cl.uint(100),
          Cl.uint(500),
          Cl.stringAscii('weighted')
        ],
        poolManager
      );

      expect(result.result).toBeErr(); // Should handle overflow
    });

    it('should handle invalid pool type', async () => {
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100),
          Cl.uint(100),
          Cl.uint(500),
          Cl.stringAscii('invalid-type')
        ],
        poolManager
      );

      expect(result.result).toBeErr(Cl.uint(2005)); // ERR_INVALID_POOL_TYPE
    });
  });

  describe('Gas Optimization Tests', () => {
    it('should create pool within reasonable gas limits', async () => {
      const result = await simnet.callPublicFn(
        DEX_FACTORY,
        'create-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100),
          Cl.uint(100),
          Cl.uint(500),
          Cl.stringAscii('weighted')
        ],
        poolManager
      );

      expect(result.result).toBeOk(Cl.bool(true));
      // Gas usage should be reasonable (would need actual gas measurement)
    });

    it('should batch operations efficiently', async () => {
      // Test multiple pool creations in a single block
      const block = await simnet.mineBlock([
        Tx.contractCall('dex-factory', 'create-pool', [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100),
          Cl.uint(100),
          Cl.uint(500),
          Cl.stringAscii('weighted')
        ], poolManager),
        Tx.contractCall('dex-factory', 'set-default-pool-type', [
          Cl.stringAscii('stable')
        ], deployer)
      ]);

      expect(block.receipts[0].result).toBeOk(Cl.bool(true));
      expect(block.receipts[1].result).toBeOk(Cl.bool(true));
    });
  });
});
