import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { Simnet, Tx } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Pool Management Comprehensive Tests', () => {
  let simnet: Simnet;
  let deployer: string;
  let user1: string;
  let user2: string;
  let poolManager: string;
  let liquidityProvider: string;

  // Contract addresses
  const POOL_MANAGER = `${deployer}.pool-manager`;
  const CONCENTRATED_POOL = `${deployer}.concentrated-liquidity-pool`;
  const POOL_REGISTRY = `${deployer}.pool-registry`;
  const TOKEN_A = `${deployer}.token-a`;
  const TOKEN_B = `${deployer}.token-b`;
  const LP_TOKEN = `${deployer}.cxlp-token`;

  beforeAll(async () => {
    simnet = (global as any).simnet;
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')?.address || '';
    user1 = accounts.get('wallet_1')?.address || '';
    user2 = accounts.get('wallet_2')?.address || '';
    poolManager = accounts.get('wallet_3')?.address || '';
    liquidityProvider = accounts.get('wallet_4')?.address || '';

    await setupInitialTokens();
    await setupRoles();
  });

  beforeEach(async () => {
    await simnet.mineEmptyBlock();
  });

  async function setupInitialTokens() {
    // Mint tokens for testing
    await simnet.callPublicFn(
      TOKEN_A,
      'mint',
      [Cl.uint(1_000_000), Cl.principal(user1)],
      deployer
    );
    await simnet.callPublicFn(
      TOKEN_A,
      'mint',
      [Cl.uint(1_000_000), Cl.principal(user2)],
      deployer
    );
    await simnet.callPublicFn(
      TOKEN_A,
      'mint',
      [Cl.uint(1_000_000), Cl.principal(liquidityProvider)],
      deployer
    );

    await simnet.callPublicFn(
      TOKEN_B,
      'mint',
      [Cl.uint(1_000_000), Cl.principal(user1)],
      deployer
    );
    await simnet.callPublicFn(
      TOKEN_B,
      'mint',
      [Cl.uint(1_000_000), Cl.principal(user2)],
      deployer
    );
    await simnet.callPublicFn(
      TOKEN_B,
      'mint',
      [Cl.uint(1_000_000), Cl.principal(liquidityProvider)],
      deployer
    );
  }

  async function setupRoles() {
    await simnet.callPublicFn(
      `${deployer}.access-control`,
      'grant-role',
      [Cl.stringAscii('POOL_MANAGER'), Cl.principal(poolManager)],
      deployer
    );
    await simnet.callPublicFn(
      `${deployer}.access-control`,
      'grant-role',
      [Cl.stringAscii('LIQUIDITY_PROVIDER'), Cl.principal(liquidityProvider)],
      deployer
    );
  }

  describe('Pool Creation and Initialization', () => {
    it('should create a weighted pool successfully', async () => {
      const result = await simnet.callPublicFn(
        POOL_MANAGER,
        'create-weighted-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100), // weight A
          Cl.uint(100), // weight B
          Cl.uint(500), // swap fee (0.05%)
          Cl.stringAscii('CXD-POOL')
        ],
        poolManager
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should create a stable pool successfully', async () => {
      const result = await simnet.callPublicFn(
        POOL_MANAGER,
        'create-stable-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(400), // lower fee for stable
          Cl.uint(1000), // amplification factor
          Cl.stringAscii('STABLE-POOL')
        ],
        poolManager
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should create a concentrated liquidity pool', async () => {
      const result = await simnet.callPublicFn(
        POOL_MANAGER,
        'create-concentrated-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(950000), // lower price bound ($0.95)
          Cl.uint(1050000), // upper price bound ($1.05)
          Cl.uint(600), // swap fee (0.06%)
          Cl.stringAscii('CONCENTRATED-POOL')
        ],
        poolManager
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject pool creation with invalid weights', async () => {
      const result = await simnet.callPublicFn(
        POOL_MANAGER,
        'create-weighted-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(0), // invalid weight
          Cl.uint(100),
          Cl.uint(500),
          Cl.stringAscii('INVALID-POOL')
        ],
        poolManager
      );

      expect(result.result).toBeErr(Cl.uint(2001)); // ERR_INVALID_WEIGHTS
    });

    it('should reject duplicate pool creation', async () => {
      // Create first pool
      await simnet.callPublicFn(
        POOL_MANAGER,
        'create-weighted-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100), Cl.uint(100), Cl.uint(500), Cl.stringAscii('POOL-1')
        ],
        poolManager
      );

      // Try to create duplicate
      const result = await simnet.callPublicFn(
        POOL_MANAGER,
        'create-weighted-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100), Cl.uint(100), Cl.uint(500), Cl.stringAscii('POOL-2')
        ],
        poolManager
      );

      expect(result.result).toBeErr(Cl.uint(2002)); // ERR_POOL_EXISTS
    });
  });

  describe('Liquidity Management', () => {
    let poolAddress: string;

    beforeEach(async () => {
      // Create a pool for liquidity testing
      const result = await simnet.callPublicFn(
        POOL_MANAGER,
        'create-weighted-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(100), Cl.uint(100), Cl.uint(500), Cl.stringAscii('LIQ-POOL')
        ],
        poolManager
      );
      
      // Get pool address (would be returned in real implementation)
      poolAddress = `${deployer}.weighted-pool-1`;
    });

    it('should add liquidity successfully', async () => {
      // Approve tokens first
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(poolAddress), Cl.uint(100_000)],
        liquidityProvider
      );
      await simnet.callPublicFn(
        TOKEN_B,
        'approve',
        [Cl.principal(poolAddress), Cl.uint(100_000)],
        liquidityProvider
      );

      // Add liquidity
      const result = await simnet.callPublicFn(
        poolAddress,
        'add-liquidity',
        [
          Cl.uint(100_000), // amount A
          Cl.uint(100_000), // amount B
          Cl.uint(95000),   // minimum A
          Cl.uint(95000),   // minimum B
          Cl.uint(1672531200) // deadline
        ],
        liquidityProvider
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should remove liquidity successfully', async () => {
      // First add liquidity
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(poolAddress), Cl.uint(100_000)],
        liquidityProvider
      );
      await simnet.callPublicFn(
        TOKEN_B,
        'approve',
        [Cl.principal(poolAddress), Cl.uint(100_000)],
        liquidityProvider
      );

      await simnet.callPublicFn(
        poolAddress,
        'add-liquidity',
        [Cl.uint(100_000), Cl.uint(100_000), Cl.uint(95000), Cl.uint(95000), Cl.uint(1672531200)],
        liquidityProvider
      );

      // Remove liquidity
      const result = await simnet.callPublicFn(
        poolAddress,
        'remove-liquidity',
        [
          Cl.uint(50000), // LP token amount
          Cl.uint(45000), // minimum A
          Cl.uint(45000), // minimum B
          Cl.uint(1672531200) // deadline
        ],
        liquidityProvider
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject liquidity addition with insufficient approval', async () => {
      const result = await simnet.callPublicFn(
        poolAddress,
        'add-liquidity',
        [Cl.uint(100_000), Cl.uint(100_000), Cl.uint(95000), Cl.uint(95000), Cl.uint(1672531200)],
        liquidityProvider
      );

      expect(result.result).toBeErr(Cl.uint(2003)); // ERR_INSUFFICIENT_APPROVAL
    });

    it('should reject liquidity removal with insufficient LP tokens', async () => {
      const result = await simnet.callPublicFn(
        poolAddress,
        'remove-liquidity',
        [Cl.uint(100_000), Cl.uint(95000), Cl.uint(95000), Cl.uint(1672531200)],
        liquidityProvider
      );

      expect(result.result).toBeErr(Cl.uint(2004)); // ERR_INSUFFICIENT_LP_TOKENS
    });

    it('should handle single-sided liquidity addition', async () => {
      // Approve only token A
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(poolAddress), Cl.uint(100_000)],
        liquidityProvider
      );

      const result = await simnet.callPublicFn(
        poolAddress,
        'add-single-sided-liquidity',
        [
          Cl.principal(TOKEN_A),
          Cl.uint(100_000),
          Cl.uint(95000),
          Cl.uint(1672531200)
        ],
        liquidityProvider
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Swap Operations', () => {
    let poolAddress: string;

    beforeEach(async () => {
      // Create and fund pool for swap testing
      await simnet.callPublicFn(
        POOL_MANAGER,
        'create-weighted-pool',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B), Cl.uint(100), Cl.uint(100), Cl.uint(500), Cl.stringAscii('SWAP-POOL')],
        poolManager
      );

      poolAddress = `${deployer}.weighted-pool-1`;

      // Add initial liquidity
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(poolAddress), Cl.uint(1_000_000)],
        liquidityProvider
      );
      await simnet.callPublicFn(
        TOKEN_B,
        'approve',
        [Cl.principal(poolAddress), Cl.uint(1_000_000)],
        liquidityProvider
      );

      await simnet.callPublicFn(
        poolAddress,
        'add-liquidity',
        [Cl.uint(1_000_000), Cl.uint(1_000_000), Cl.uint(950000), Cl.uint(950000), Cl.uint(1672531200)],
        liquidityProvider
      );

      // Approve tokens for user
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(poolAddress), Cl.uint(100_000)],
        user1
      );
    });

    it('should perform token swap successfully', async () => {
      const result = await simnet.callPublicFn(
        poolAddress,
        'swap',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(10_000), // amount in
          Cl.uint(9500),   // minimum out
          Cl.uint(1672531200) // deadline
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject swap with insufficient balance', async () => {
      const result = await simnet.callPublicFn(
        poolAddress,
        'swap',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(2_000_000), // More than user has
          Cl.uint(9500),
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(2005)); // ERR_INSUFFICIENT_BALANCE
    });

    it('should reject swap with insufficient liquidity', async () => {
      const result = await simnet.callPublicFn(
        poolAddress,
        'swap',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(500_000), // Too large for pool
          Cl.uint(475000),
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(2006)); // ERR_INSUFFICIENT_LIQUIDITY
    });

    it('should reject swap below minimum output', async () => {
      const result = await simnet.callPublicFn(
        poolAddress,
        'swap',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(10_000),
          Cl.uint(15_000), // Impossible minimum
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(2007)); // ERR_INSUFFICIENT_OUTPUT
    });

    it('should reject swap after deadline', async () => {
      const pastDeadline = 1640995200; // 2022-01-01 (in the past)

      const result = await simnet.callPublicFn(
        poolAddress,
        'swap',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(10_000),
          Cl.uint(9500),
          Cl.uint(pastDeadline)
        ],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(2008)); // ERR_DEADLINE_EXPIRED
    });

    it('should handle flash swaps correctly', async () => {
      const result = await simnet.callPublicFn(
        poolAddress,
        'flash-swap',
        [
          Cl.principal(TOKEN_B),
          Cl.uint(10_000),
          Cl.uint(10500), // amount to repay with fee
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Pool Configuration and Management', () => {
    let poolAddress: string;

    beforeEach(async () => {
      await simnet.callPublicFn(
        POOL_MANAGER,
        'create-weighted-pool',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B), Cl.uint(100), Cl.uint(100), Cl.uint(500), Cl.stringAscii('CONFIG-POOL')],
        poolManager
      );
      poolAddress = `${deployer}.weighted-pool-1`;
    });

    it('should allow owner to update swap fee', async () => {
      const result = await simnet.callPublicFn(
        poolAddress,
        'set-swap-fee',
        [Cl.uint(600)], // 0.06%
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject fee update from non-owner', async () => {
      const result = await simnet.callPublicFn(
        poolAddress,
        'set-swap-fee',
        [Cl.uint(600)],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(1003)); // ERR_UNAUTHORIZED
    });

    it('should allow owner to pause pool', async () => {
      const result = await simnet.callPublicFn(
        poolAddress,
        'set-paused',
        [Cl.bool(true)],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject swaps when paused', async () => {
      // Pause pool
      await simnet.callPublicFn(
        poolAddress,
        'set-paused',
        [Cl.bool(true)],
        deployer
      );

      // Try to swap
      const result = await simnet.callPublicFn(
        poolAddress,
        'swap',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(10_000),
          Cl.uint(9500),
          Cl.uint(1672531200)
        ],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(1003)); // ERR_PAUSED
    });

    it('should update pool weights correctly', async () => {
      const result = await simnet.callPublicFn(
        poolAddress,
        'update-weights',
        [Cl.uint(150), Cl.uint(50)], // Update to 75/25 split
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Concentrated Liquidity Features', () => {
    let concentratedPool: string;

    beforeEach(async () => {
      await simnet.callPublicFn(
        POOL_MANAGER,
        'create-concentrated-pool',
        [
          Cl.principal(TOKEN_A),
          Cl.principal(TOKEN_B),
          Cl.uint(950000), // $0.95
          Cl.uint(1050000), // $1.05
          Cl.uint(600),
          Cl.stringAscii('CONCENTRATED')
        ],
        poolManager
      );
      concentratedPool = `${deployer}.concentrated-pool-1`;
    });

    it('should create position in price range', async () => {
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(concentratedPool), Cl.uint(100_000)],
        liquidityProvider
      );
      await simnet.callPublicFn(
        TOKEN_B,
        'approve',
        [Cl.principal(concentratedPool), Cl.uint(100_000)],
        liquidityProvider
      );

      const result = await simnet.callPublicFn(
        concentratedPool,
        'create-position',
        [
          Cl.uint(960000), // lower tick
          Cl.uint(1040000), // upper tick
          Cl.uint(100_000), // amount A
          Cl.uint(100_000), // amount B
          Cl.uint(1672531200)
        ],
        liquidityProvider
      );

      expect(result.result).toBeOk(Cl.uint(1)); // Position ID
    });

    it('should adjust liquidity in position', async () => {
      // Create position first
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(concentratedPool), Cl.uint(100_000)],
        liquidityProvider
      );
      await simnet.callPublicFn(
        TOKEN_B,
        'approve',
        [Cl.principal(concentratedPool), Cl.uint(100_000)],
        liquidityProvider
      );

      await simnet.callPublicFn(
        concentratedPool,
        'create-position',
        [Cl.uint(960000), Cl.uint(1040000), Cl.uint(100_000), Cl.uint(100_000), Cl.uint(1672531200)],
        liquidityProvider
      );

      // Add more liquidity
      const result = await simnet.callPublicFn(
        concentratedPool,
        'adjust-liquidity',
        [
          Cl.uint(1), // position ID
          Cl.uint(50000), // additional A
          Cl.uint(50000), // additional B
          Cl.uint(0), // remove liquidity (0 = add)
          Cl.uint(1672531200)
        ],
        liquidityProvider
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should collect fees from position', async () => {
      // Create position and generate some fees through swaps
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(concentratedPool), Cl.uint(100_000)],
        liquidityProvider
      );
      await simnet.callPublicFn(
        TOKEN_B,
        'approve',
        [Cl.principal(concentratedPool), Cl.uint(100_000)],
        liquidityProvider
      );

      await simnet.callPublicFn(
        concentratedPool,
        'create-position',
        [Cl.uint(960000), Cl.uint(1040000), Cl.uint(100_000), Cl.uint(100_000), Cl.uint(1672531200)],
        liquidityProvider
      );

      // Perform some swaps to generate fees
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(concentratedPool), Cl.uint(10_000)],
        user1
      );

      await simnet.callPublicFn(
        concentratedPool,
        'swap',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B), Cl.uint(10_000), Cl.uint(9500), Cl.uint(1672531200)],
        user1
      );

      // Collect fees
      const result = await simnet.callPublicFn(
        concentratedPool,
        'collect-fees',
        [Cl.uint(1), Cl.uint(1672531200)],
        liquidityProvider
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Pool Analytics and Monitoring', () => {
    let poolAddress: string;

    beforeEach(async () => {
      await simnet.callPublicFn(
        POOL_MANAGER,
        'create-weighted-pool',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B), Cl.uint(100), Cl.uint(100), Cl.uint(500), Cl.stringAscii('ANALYTICS-POOL')],
        poolManager
      );
      poolAddress = `${deployer}.weighted-pool-1`;
    });

    it('should provide pool statistics', () => {
      const stats = simnet.callReadOnlyFn(
        poolAddress,
        'get-pool-stats',
        [],
        deployer
      );

      expect(stats.result).toBeOk(Cl.bool(true));
    });

    it('should calculate current price', () => {
      const price = simnet.callReadOnlyFn(
        poolAddress,
        'get-current-price',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B)],
        deployer
      );

      expect(price.result).toBeOk(Cl.bool(true));
    });

    it('should provide liquidity depth information', () => {
      const depth = simnet.callReadOnlyFn(
        poolAddress,
        'get-liquidity-depth',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B)],
        deployer
      );

      expect(depth.result).toBeOk(Cl.bool(true));
    });

    it('should track 24h volume', () => {
      const volume = simnet.callReadOnlyFn(
        poolAddress,
        'get-24h-volume',
        [],
        deployer
      );

      expect(volume.result).toBeOk(Cl.bool(true));
    });

    it('should calculate APR for liquidity providers', () => {
      const apr = simnet.callReadOnlyFn(
        poolAddress,
        'calculate-apr',
        [],
        deployer
      );

      expect(apr.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Emergency and Recovery Operations', () => {
    let poolAddress: string;

    beforeEach(async () => {
      await simnet.callPublicFn(
        POOL_MANAGER,
        'create-weighted-pool',
        [Cl.principal(TOKEN_A), Cl.principal(TOKEN_B), Cl.uint(100), Cl.uint(100), Cl.uint(500), Cl.stringAscii('EMERGENCY-POOL')],
        poolManager
      );
      poolAddress = `${deployer}.weighted-pool-1`;
    });

    it('should allow emergency withdrawal by owner', async () => {
      // Add liquidity first
      await simnet.callPublicFn(
        TOKEN_A,
        'approve',
        [Cl.principal(poolAddress), Cl.uint(100_000)],
        liquidityProvider
      );
      await simnet.callPublicFn(
        TOKEN_B,
        'approve',
        [Cl.principal(poolAddress), Cl.uint(100_000)],
        liquidityProvider
      );

      await simnet.callPublicFn(
        poolAddress,
        'add-liquidity',
        [Cl.uint(100_000), Cl.uint(100_000), Cl.uint(95000), Cl.uint(95000), Cl.uint(1672531200)],
        liquidityProvider
      );

      // Emergency withdrawal
      const result = await simnet.callPublicFn(
        poolAddress,
        'emergency-withdraw',
        [Cl.principal(liquidityProvider)],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject emergency withdrawal from non-owner', async () => {
      const result = await simnet.callPublicFn(
        poolAddress,
        'emergency-withdraw',
        [Cl.principal(liquidityProvider)],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(1003)); // ERR_UNAUTHORIZED
    });

    it('should allow pool migration', async () => {
      const newPoolVersion = `${deployer}.weighted-pool-v2`;
      
      const result = await simnet.callPublicFn(
        poolAddress,
        'migrate-liquidity',
        [Cl.principal(newPoolVersion)],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });
  });
});
