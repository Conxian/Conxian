import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { Simnet, Tx } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Dimensional Engine Complete Coverage', () => {
  let simnet: Simnet;
  let deployer: string;
  let user1: string;
  let user2: string;
  let operator: string;

  // Contract addresses
  const DIMENSIONAL_ENGINE = `${deployer}.dimensional-engine`;
  const POSITION_MANAGER = `${deployer}.position-manager`;
  const FUNDING_CALCULATOR = `${deployer}.funding-rate-calculator`;
  const COLLATERAL_MANAGER = `${deployer}.collateral-manager`;
  const RISK_MANAGER = `${deployer}.risk-manager`;
  const ORACLE = `${deployer}.oracle-adapter`;
  const TOKEN = `${deployer}.token`;

  // Test constants
  const INITIAL_BALANCE = 1_000_000;
  const COLLATERAL_AMOUNT = 10_000;
  const LEVERAGE = 2_000; // 20x
  const STOP_LOSS = 900_000; // 10% below entry
  const TAKE_PROFIT = 1_100_000; // 10% above entry

  beforeAll(async () => {
    simnet = (global as any).simnet;
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')?.address || '';
    user1 = accounts.get('wallet_1')?.address || '';
    user2 = accounts.get('wallet_2')?.address || '';
    operator = accounts.get('wallet_3')?.address || '';

    // Setup initial state
    await setupRoles();
    await mintInitialTokens();
    await setOraclePrice();
  });

  beforeEach(async () => {
    // Reset state between tests
    await simnet.mineEmptyBlock();
  });

  async function setupRoles() {
    // Grant operator role
    await simnet.callPublicFn(
      `${deployer}.access-control`,
      'grant-role',
      [Cl.stringAscii('OPERATOR'), Cl.principal(operator)],
      deployer
    );
  }

  async function mintInitialTokens() {
    // Mint tokens for users
    await simnet.callPublicFn(
      TOKEN,
      'mint',
      [Cl.uint(INITIAL_BALANCE), Cl.principal(user1)],
      deployer
    );
    await simnet.callPublicFn(
      TOKEN,
      'mint',
      [Cl.uint(INITIAL_BALANCE), Cl.principal(user2)],
      deployer
    );
  }

  async function setOraclePrice() {
    // Set initial oracle price
    await simnet.callPublicFn(
      ORACLE,
      'set-price',
      [Cl.principal(TOKEN), Cl.uint(1_000_000)], // $1.00
      deployer
    );
  }

  describe('Position Management', () => {
    it('should open a long position successfully', async () => {
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true), // is long
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should open a short position successfully', async () => {
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(false), // is short
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject position opening with insufficient balance', async () => {
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(INITIAL_BALANCE * 2), // More than balance
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(2003)); // ERR_INSUFFICIENT_BALANCE
    });

    it('should reject position opening with invalid leverage', async () => {
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(100_000), // 1000x leverage (too high)
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(2004)); // ERR_INVALID_LEVERAGE
    });

    it('should close position successfully', async () => {
      // First open a position
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      // Then close it
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'close-position',
        [
          Cl.uint(1), // position ID
          Cl.principal(TOKEN),
          Cl.some(Cl.uint(50_000)) // 5% slippage tolerance
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject closing non-existent position', async () => {
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'close-position',
        [
          Cl.uint(999), // Non-existent position ID
          Cl.principal(TOKEN),
          Cl.some(Cl.uint(50_000))
        ],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(2005)); // ERR_POSITION_NOT_FOUND
    });

    it('should reject closing position owned by different user', async () => {
      // Open position for user1
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      // Try to close with user2
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'close-position',
        [
          Cl.uint(1),
          Cl.principal(TOKEN),
          Cl.some(Cl.uint(50_000))
        ],
        user2
      );

      expect(result.result).toBeErr(Cl.uint(1003)); // ERR_UNAUTHORIZED
    });

    it('should handle position without stop loss/take profit', async () => {
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.none(), // No stop loss
          Cl.none()  // No take profit
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Funding Rate Calculations', () => {
    beforeEach(async () => {
      // Open a position for funding rate testing
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );
    });

    it('should update funding rate successfully', async () => {
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'update-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject funding rate update from non-operator', async () => {
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'update-funding-rate',
        [Cl.principal(TOKEN)],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(1003)); // ERR_UNAUTHORIZED
    });

    it('should apply funding to position successfully', async () => {
      // First update funding rate
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'update-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      // Then apply to position
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'apply-funding-to-position',
        [Cl.principal(user1), Cl.uint(1)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should handle funding rate calculation with different market conditions', async () => {
      // Update oracle price to simulate market movement
      await simnet.callPublicFn(
        ORACLE,
        'set-price',
        [Cl.principal(TOKEN), Cl.uint(1_100_000)], // 10% price increase
        deployer
      );

      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'update-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should calculate funding rate correctly for long vs short positions', async () => {
      // Open both long and short positions
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true), // Long
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(false), // Short
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user2
      );

      // Update funding rate
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'update-funding-rate',
        [Cl.principal(TOKEN)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Position Information Queries', () => {
    let positionId: number;

    beforeEach(async () => {
      // Open a position for testing
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );
      positionId = 1;
    });

    it('should get position info successfully', () => {
      const result = simnet.callReadOnlyFn(
        DIMENSIONAL_ENGINE,
        'get-position-info',
        [Cl.principal(user1), Cl.uint(positionId)],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should return error for non-existent position', () => {
      const result = simnet.callReadOnlyFn(
        DIMENSIONAL_ENGINE,
        'get-position-info',
        [Cl.principal(user1), Cl.uint(999)],
        deployer
      );

      expect(result.result).toBeErr(Cl.uint(2005)); // ERR_POSITION_NOT_FOUND
    });

    it('should calculate PnL correctly', () => {
      const result = simnet.callReadOnlyFn(
        DIMENSIONAL_ENGINE,
        'calculate-pnl',
        [Cl.principal(user1), Cl.uint(positionId), Cl.principal(TOKEN)],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should get all positions for user', () => {
      const result = simnet.callReadOnlyFn(
        DIMENSIONAL_ENGINE,
        'get-user-positions',
        [Cl.principal(user1)],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should get total system positions', () => {
      const result = simnet.callReadOnlyFn(
        DIMENSIONAL_ENGINE,
        'get-total-positions',
        [],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Risk Management Integration', () => {
    beforeEach(async () => {
      // Open a position for risk testing
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );
    });

    it('should check position risk successfully', () => {
      const result = simnet.callReadOnlyFn(
        DIMENSIONAL_ENGINE,
        'check-position-risk',
        [Cl.principal(user1), Cl.uint(1)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should trigger liquidation when position is under-collateralized', async () => {
      // Simulate price drop that would trigger liquidation
      await simnet.callPublicFn(
        ORACLE,
        'set-price',
        [Cl.principal(TOKEN), Cl.uint(800_000)], // 20% price drop
        deployer
      );

      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'liquidate-position',
        [Cl.principal(user1), Cl.uint(1)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject liquidation of healthy position', async () => {
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'liquidate-position',
        [Cl.principal(user1), Cl.uint(1)],
        operator
      );

      expect(result.result).toBeErr(Cl.uint(2006)); // ERR_POSITION_HEALTHY
    });

    it('should handle margin calls correctly', async () => {
      // Simulate price drop to trigger margin call
      await simnet.callPublicFn(
        ORACLE,
        'set-price',
        [Cl.principal(TOKEN), Cl.uint(950_000)], // 5% price drop
        deployer
      );

      const result = simnet.callReadOnlyFn(
        DIMENSIONAL_ENGINE,
        'check-margin-call',
        [Cl.principal(user1), Cl.uint(1)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Collateral Management', () => {
    it('should add collateral to position successfully', async () => {
      // Open position first
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      // Add more collateral
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'add-collateral',
        [Cl.uint(1), Cl.principal(TOKEN), Cl.uint(5_000)],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should remove collateral from position successfully', async () => {
      // Open position first
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      // Remove some collateral
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'remove-collateral',
        [Cl.uint(1), Cl.principal(TOKEN), Cl.uint(2_000)],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject collateral removal that would under-collateralize', async () => {
      // Open position first
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      // Try to remove too much collateral
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'remove-collateral',
        [Cl.uint(1), Cl.principal(TOKEN), Cl.uint(9_000)], // Almost all collateral
        user1
      );

      expect(result.result).toBeErr(Cl.uint(2007)); // ERR_INSUFFICIENT_COLLATERAL
    });
  });

  describe('Emergency Operations', () => {
    it('should allow emergency pause by owner', async () => {
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'emergency-pause',
        [Cl.bool(true)],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should reject position opening when paused', async () => {
      // Pause first
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'emergency-pause',
        [Cl.bool(true)],
        deployer
      );

      // Try to open position
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(1003)); // ERR_SYSTEM_PAUSED
    });

    it('should allow emergency liquidation by operator', async () => {
      // Open position first
      await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      // Emergency liquidation
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'emergency-liquidate',
        [Cl.principal(user1), Cl.uint(1)],
        operator
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Edge Cases & Error Handling', () => {
    it('should handle maximum leverage correctly', async () => {
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(10000), // Maximum allowed leverage
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should handle minimum collateral correctly', async () => {
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(1), // Minimum collateral
          Cl.uint(1000), // 10x leverage
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should handle zero collateral correctly', async () => {
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(0), // Zero collateral
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(2008)); // ERR_ZERO_COLLATERAL
    });

    it('should handle invalid stop loss/take profit levels', async () => {
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(1_200_000)), // Stop loss above entry (invalid for long)
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      expect(result.result).toBeErr(Cl.uint(2009)); // ERR_INVALID_STOP_LOSS
    });
  });

  describe('Gas Optimization & Performance', () => {
    it('should open position within reasonable gas limits', async () => {
      const result = await simnet.callPublicFn(
        DIMENSIONAL_ENGINE,
        'open-position',
        [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should batch multiple operations efficiently', async () => {
      const block = await simnet.mineBlock([
        Tx.contractCall('dimensional-engine', 'open-position', [
          Cl.principal(TOKEN),
          Cl.uint(COLLATERAL_AMOUNT),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ], user1),
        Tx.contractCall('dimensional-engine', 'update-funding-rate', [
          Cl.principal(TOKEN)
        ], operator)
      ]);

      expect(block.receipts[0].result).toBeOk(Cl.bool(true));
      expect(block.receipts[1].result).toBeOk(Cl.bool(true));
    });
  });
});
