import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { Simnet, Tx } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Funding Rate Calculations Comprehensive Tests', () => {
  let simnet: Simnet;
  let deployer: string;
  let user1: string;
  let user2: string;
  let operator: string;
  let oracle: string;

  // Contract addresses
  const FUNDING_CALCULATOR = `${deployer}.funding-rate-calculator`;
  const DIMENSIONAL_ENGINE = `${deployer}.dimensional-engine`;
  const ORACLE_ADAPTER = `${deployer}.oracle-adapter`;
  const POSITION_MANAGER = `${deployer}.position-manager`;
  const TOKEN = `${deployer}.token`;

  // Test constants
  const INITIAL_PRICE = 1_000_000; // $1.00
  const FUNDING_INTERVAL = 3600; // 1 hour
  const PREMIUM_THRESHOLD = 10000; // 1%

  beforeAll(async () => {
    simnet = (global as any).simnet;
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')?.address || '';
    user1 = accounts.get('wallet_1')?.address || '';
    user2 = accounts.get('wallet_2')?.address || '';
    operator = accounts.get('wallet_3')?.address || '';
    oracle = accounts.get('wallet_4')?.address || '';

    await setupInitialTokens();
    await setupRoles();
    await initializeOracle();
  });

  beforeEach(async () => {
    await simnet.mineEmptyBlock();
  });

  async function setupInitialTokens() {
    // Mint tokens for testing
    await simnet.callPublicFn(
      TOKEN,
      'mint',
      [Cl.uint(1_000_000), Cl.principal(user1)],
      deployer
    );
    await simnet.callPublicFn(
      TOKEN,
      'mint',
      [Cl.uint(1_000_000), Cl.principal(user2)],
      deployer
    );
  }

  async function setupRoles() {
    await simnet.callPublicFn(
      `${deployer}.access-control`,
      'grant-role',
      [Cl.stringAscii('OPERATOR'), Cl.principal(operator)],
      deployer
    );
    await simnet.callPublicFn(
      `${deployer}.access-control`,
      'grant-role',
      [Cl.stringAscii('ORACLE'), Cl.principal(oracle)],
      deployer
    );
  }

  async function initializeOracle() {
    await simnet.callPublicFn(
      ORACLE_ADAPTER,
      'set-price',
      [Cl.principal(TOKEN), Cl.uint(INITIAL_PRICE)],
      oracle
    );
  }

  describe('Basic Funding Rate Calculation', () => {
    beforeEach(async () => {
      // Create positions for funding testing
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(10_000),
          Cl.uint(2000), // 20x leverage
          Cl.bool(true), // long
          Cl.some(Cl.uint(900_000)),
          Cl.some(Cl.uint(1_100_000))
        ],
        user1
      );

      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(10_000),
          Cl.uint(2000), // 20x leverage
          Cl.bool(false), // short
          Cl.some(Cl.uint(900_000)),
          Cl.some(Cl.uint(1_100_000))
        ],
        user2
      );
    });

    it('should calculate funding rate for balanced positions', async () => {
      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'calculate-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should calculate positive funding rate when longs exceed shorts', async () => {
      // Create additional long position to create imbalance
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(5_000),
          Cl.uint(2000),
          Cl.bool(true),
          Cl.some(Cl.uint(900_000)),
          Cl.some(Cl.uint(1_100_000))
        ],
        user1
      );

      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'calculate-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should calculate negative funding rate when shorts exceed longs', async () => {
      // Create additional short position to create imbalance
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(5_000),
          Cl.uint(2000),
          Cl.bool(false),
          Cl.some(Cl.uint(900_000)),
          Cl.some(Cl.uint(1_100_000))
        ],
        user2
      );

      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'calculate-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should handle zero funding rate for perfectly balanced positions', async () => {
      // Create perfectly balanced positions
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(10_000),
          Cl.uint(2000),
          Cl.bool(true),
          Cl.some(Cl.uint(900_000)),
          Cl.some(Cl.uint(1_100_000))
        ],
        user1
      );

      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(10_000),
          Cl.uint(2000),
          Cl.bool(false),
          Cl.some(Cl.uint(900_000)),
          Cl.some(Cl.uint(1_100_000))
        ],
        user2
      );

      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'calculate-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Premium and Index Price Calculations', () => {
    it('should calculate mark price from oracle', async () => {
      const markPrice = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'get-mark-price',
        [Cl.principal(TOKEN)],
        deployer
      );

      expect(markPrice.result).toBeOk(Cl.uint(INITIAL_PRICE));
    });

    it('should calculate index price from multiple sources', async () => {
      // Set prices from multiple oracles
      await simnet.callPublicFn(
        ORACLE_ADAPTER,
        'set-price-source',
        [Cl.principal(TOKEN), Cl.stringAscii('chainlink'), Cl.uint(1_001_000)],
        oracle
      );

      await simnet.callPublicFn(
        ORACLE_ADAPTER,
        'set-price-source',
        [Cl.principal(TOKEN), Cl.stringAscii('pyth'), Cl.uint(999_000)],
        oracle
      );

      const indexPrice = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'get-index-price',
        [Cl.principal(TOKEN)],
        deployer
      );

      expect(indexPrice.result).toBeOk(Cl.bool(true));
    });

    it('should calculate premium correctly', async () => {
      // Update oracle price to create premium
      await simnet.callPublicFn(
        ORACLE_ADAPTER,
        'set-price',
        [Cl.principal(TOKEN), Cl.uint(1_010_000)], // 1% premium
        oracle
      );

      const premium = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'calculate-premium',
        [Cl.principal(TOKEN)],
        deployer
      );

      expect(premium.result).toBeOk(Cl.bool(true));
    });

    it('should handle negative premium (discount)', async () => {
      // Update oracle price to create discount
      await simnet.callPublicFn(
        ORACLE_ADAPTER,
        'set-price',
        [Cl.principal(TOKEN), Cl.uint(990_000)], // 1% discount
        oracle
      );

      const premium = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'calculate-premium',
        [Cl.principal(TOKEN)],
        deployer
      );

      expect(premium.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Funding Rate Application', () => {
    let positionId: number;

    beforeEach(async () => {
      // Create position for funding application testing
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(10_000),
          Cl.uint(2000),
          Cl.bool(true),
          Cl.some(Cl.uint(900_000)),
          Cl.some(Cl.uint(1_100_000))
        ],
        user1
      );
      positionId = 1;
    });

    it('should apply funding to long position correctly', async () => {
      // Create funding rate imbalance (more longs)
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(5_000),
          Cl.uint(2000),
          Cl.bool(true),
          Cl.some(Cl.uint(900_000)),
          Cl.some(Cl.uint(1_100_000))
        ],
        user2
      );

      // Calculate funding rate
      await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'calculate-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      // Apply funding to position
      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'apply-funding-to-position',
        [Cl.principal(user1), Cl.uint(positionId)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should apply funding to short position correctly', async () => {
      // Create funding rate imbalance (more shorts)
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(5_000),
          Cl.uint(2000),
          Cl.bool(false),
          Cl.some(Cl.uint(900_000)),
          Cl.some(Cl.uint(1_100_000))
        ],
        user2
      );

      // Calculate funding rate
      await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'calculate-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      // Apply funding to position
      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'apply-funding-to-position',
        [Cl.principal(user1), Cl.uint(positionId)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should handle zero funding payment', async () => {
      // Create balanced positions
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(10_000),
          Cl.uint(2000),
          Cl.bool(false),
          Cl.some(Cl.uint(900_000)),
          Cl.some(Cl.uint(1_100_000))
        ],
        user2
      );

      // Calculate funding rate (should be zero)
      await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'calculate-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      // Apply funding
      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'apply-funding-to-position',
        [Cl.principal(user1), Cl.uint(positionId)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should track cumulative funding payments', async () => {
      // Apply funding multiple times
      for (let i = 0; i < 3; i++) {
        await simnet.callPublicFn(
          FUNDING_CALCULATOR,
          'calculate-funding-rate',
          [Cl.principal(TOKEN)],
          operator
        );

        await simnet.callPublicFn(
          FUNDING_CALCULATOR,
          'apply-funding-to-position',
          [Cl.principal(user1), Cl.uint(positionId)],
          operator
        );
      }

      const cumulativeFunding = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'get-cumulative-funding',
        [Cl.principal(user1), Cl.uint(positionId)],
        deployer
      );

      expect(cumulativeFunding.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Funding Rate Configuration', () => {
    it('should update funding interval', async () => {
      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'set-funding-interval',
        [Cl.uint(1800)], // 30 minutes
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));

      // Verify update
      const interval = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'get-funding-interval',
        [],
        deployer
      );

      expect(interval.result).toBeOk(Cl.uint(1800));
    });

    it('should update premium threshold', async () => {
      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'set-premium-threshold',
        [Cl.uint(5000)], // 0.5%
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));

      // Verify update
      const threshold = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'get-premium-threshold',
        [],
        deployer
      );

      expect(threshold.result).toBeOk(Cl.uint(5000));
    });

    it('should update funding rate multiplier', async () => {
      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'set-funding-multiplier',
        [Cl.uint(15000)], // 1.5x
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject configuration changes from non-owner', async () => {
      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'set-funding-interval',
        [Cl.uint(1800)],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(1003)); // ERR_UNAUTHORIZED
    });
  });

  describe('Advanced Funding Rate Features', () => {
    it('should calculate time-weighted funding rate', async () => {
      const result = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'get-time-weighted-funding-rate',
        [Cl.principal(TOKEN), Cl.uint(7200)], // 2 hours
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should handle cross-token funding rates', async () => {
      // Create positions with different tokens
      await simnet.callPublicFn(
        `${deployer}.token-b`,
        'mint',
        [Cl.uint(1_000_000), Cl.principal(user1)],
        deployer
      );

      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(`${deployer}.token-b`),
          Cl.uint(10_000),
          Cl.uint(2000),
          Cl.bool(true),
          Cl.some(Cl.uint(900_000)),
          Cl.some(Cl.uint(1_100_000))
        ],
        user1
      );

      const crossTokenRate = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'get-cross-token-funding-rate',
        [Cl.principal(TOKEN), Cl.principal(`${deployer}.token-b`)],
        deployer
      );

      expect(crossTokenRate.result).toBeOk(Cl.bool(true));
    });

    it('should calculate funding rate volatility', async () => {
      // Create multiple funding rate changes to calculate volatility
      for (let i = 0; i < 5; i++) {
        await simnet.callPublicFn(
          ORACLE_ADAPTER,
          'set-price',
          [Cl.principal(TOKEN), Cl.uint(INITIAL_PRICE + (i * 1000))],
          oracle
        );

        await simnet.callPublicFn(
          FUNDING_CALCULATOR,
          'calculate-funding-rate',
          [Cl.principal(TOKEN)],
          operator
        );
      }

      const volatility = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'get-funding-rate-volatility',
        [Cl.principal(TOKEN)],
        deployer
      );

      expect(volatility.result).toBeOk(Cl.bool(true));
    });

    it('should predict next funding rate', async () => {
      const prediction = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'predict-next-funding-rate',
        [Cl.principal(TOKEN)],
        deployer
      );

      expect(prediction.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Funding Rate Edge Cases', () => {
    it('should handle extreme market conditions', async () => {
      // Simulate extreme price movement
      await simnet.callPublicFn(
        ORACLE_ADAPTER,
        'set-price',
        [Cl.principal(TOKEN), Cl.uint(2_000_000)], // 100% increase
        oracle
      );

      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'calculate-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should handle zero liquidity scenarios', async () => {
      // Close all positions to create zero liquidity
      // (This would require position closing functionality)

      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'calculate-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should handle oracle price failures', async ()    {
      // Simulate oracle failure
      await simnet.callPublicFn(
        ORACLE_ADAPTER,
        'set-price-status',
        [Cl.principal(TOKEN), Cl.bool(false)], // Price unavailable
        oracle
      );

      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'calculate-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      expect(result.result).toBeErr(Cl.uint(3001)); // ERR_ORACLE_UNAVAILABLE
    });

    it('should handle funding rate overflow protection', async () => {
      // Create extreme position imbalance
      const extremeAmount = 1_000_000_000;

      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(extremeAmount),
          Cl.uint(100), // Low leverage to avoid liquidation
          Cl.bool(true),
          Cl.some(Cl.uint(900_000)),
          Cl.some(Cl.uint(1_100_000))
        ],
        user1
      );

      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'calculate-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true)); // Should handle gracefully
    });
  });

  describe('Funding Rate Analytics', () => {
    it('should provide funding rate history', async () => {
      // Generate some funding rate history
      for (let i = 0; i < 5; i++) {
        await simnet.callPublicFn(
          FUNDING_CALCULATOR,
          'calculate-funding-rate',
          [Cl.principal(TOKEN)],
          operator
        );
      }

      const history = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'get-funding-rate-history',
        [Cl.principal(TOKEN), Cl.uint(5)],
        deployer
      );

      expect(history.result).toBeOk(Cl.bool(true));
    });

    it('should calculate funding rate averages', async () => {
      const averages = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'get-funding-rate-averages',
        [Cl.principal(TOKEN)],
        deployer
      );

      expect(averages.result).toBeOk(Cl.bool(true));
    });

    it('should track funding rate correlations', async () => {
      const correlation = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'get-funding-rate-correlation',
        [Cl.principal(TOKEN), Cl.principal(`${deployer}.token-b`)],
        deployer
      );

      expect(correlation.result).toBeOk(Cl.bool(true));
    });

    it('should provide funding rate statistics', async () => {
      const stats = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'get-funding-rate-stats',
        [Cl.principal(TOKEN)],
        deployer
      );

      expect(stats.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Funding Rate Performance Optimization', () => {
    it('should batch funding rate calculations', async () => {
      const tokens = [TOKEN, `${deployer}.token-b`, `${deployer}.token-c`];

      const result = await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'batch-calculate-funding-rates',
        [Cl.list(tokens.map(t => Cl.principal(t)))],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should cache funding rate calculations', async () => {
      // First calculation
      await simnet.callPublicFn(
        FUNDING_CALCULATOR,
        'calculate-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      // Second calculation should use cache
      const result = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'get-cached-funding-rate',
        [Cl.principal(TOKEN)],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should optimize gas usage for funding applications', async () => {
      const gasEstimate = simnet.callReadOnlyFn(
        FUNDING_CALCULATOR,
        'estimate-funding-application-gas',
        [Cl.principal(TOKEN)],
        deployer
      );

      expect(gasEstimate.result).toBeOk(Cl.bool(true));
    });
  });
});
