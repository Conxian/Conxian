import { Cl, ClarityValue, ResponseOkCV, cvToValue } from '@stacks/transactions';
import { describe, expect, it, beforeAll } from 'vitest';
import { Simnet } from '@stacks/clarinet-sdk';
import {
  deployer,
  user1,
  user2,
  setupRoles,
  mintTokens,
  expectErr,
  expectOk,
  expectOkWithResult,
  expectErrWithCode,
  ERR_NOT_AUTHORIZED,
  ERR_INVALID_INPUT,
  ERR_INSUFFICIENT_BALANCE,
  ERR_POSITION_NOT_FOUND,
  ERR_INVALID_LEVERAGE,
  ROLE_OPERATOR,
  openPosition
} from './test-utils';

const simnet: Simnet = (global as any).simnet;

const unwrapOk = <T = unknown>(response: any): T =>
  cvToValue((response.result as ResponseOkCV<ClarityValue>).value) as T;

// Contract addresses
const TOKEN_CONTRACT = `${deployer}.token`;
const ENGINE_CONTRACT = `${deployer}.dimensional-engine`;
const ORACLE_CONTRACT = `${deployer}.oracle-adapter`;

describe('Dimensional Engine', () => {
  // Test parameters
  const INITIAL_BALANCE = 1_000_000;
  const COLLATERAL = 1_000;
  const LEVERAGE = 2_000; // 20x
  const STOP_LOSS = 900_000; // 10% below entry
  const TAKE_PROFIT = 1_100_000; // 10% above entry
  
  beforeAll(async () => {
    // Setup roles and mint initial tokens
    await setupRoles(simnet);
    await mintTokens(simnet, user1, INITIAL_BALANCE);
    await mintTokens(simnet, user2, INITIAL_BALANCE);
    
    // Set initial price in oracle
    await simnet.callPublicFn(
      ORACLE_CONTRACT,
      'set-price',
      [Cl.uint(1_000_000)], // $10.00 (6 decimals)
      deployer
    );
    
    // Set up funding rate parameters
    await simnet.callPublicFn(
      ENGINE_CONTRACT,
      'set-funding-parameters',
      [Cl.uint(144), Cl.uint(100), Cl.uint(1000)], // 144 blocks (1 day), 1% max rate, 10x sensitivity
      deployer
    );
  });
  
  describe('Admin Functions', () => {
    it('should revert funding rate update when interval not met', async () => {
      const asset = Cl.principal(TOKEN_CONTRACT);

      // First update succeeds and sets the last timestamp
      const first = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'update-funding-rate',
        [asset],
        deployer
      );
      expectOk(first);

      // Immediately updating again should fail with invalid-input
      const second = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'update-funding-rate',
        [asset],
        deployer
      );
      expectErrWithCode(second, ERR_INVALID_INPUT);
    });

    it('should reject funding rate when oracle data missing', async () => {
      const missingAsset = Cl.principal(`${deployer}.missing-asset`);

      const result = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'update-funding-rate',
        [missingAsset],
        deployer
      );

      // Oracle unwrap propagates contract-specific error (e.g., missing price feed)
      expectErr(result);
    });

    it('should allow admin to adjust funding parameters and enforce bounds', async () => {
      const update = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'set-funding-parameters',
        [Cl.uint(288), Cl.uint(50), Cl.uint(250)],
        deployer
      );
      expectOk(update);

      const invalid = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'set-funding-parameters',
        [Cl.uint(0), Cl.uint(0), Cl.uint(0)],
        deployer
      );
      expectErrWithCode(invalid, ERR_INVALID_INPUT);
    });

    it('should allow admin to set protocol fee rate', async () => {
      const result = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'set-protocol-fee-rate',
        [Cl.uint(50)], // 0.5%
        deployer
      );
      
      expectOk(result);
      
      // Verify fee rate was updated
      const feeRate = await simnet.callReadOnlyFn(
        ENGINE_CONTRACT,
        'get-protocol-fee-rate',
        [],
        user1
      );
      
      expectOkWithResult(feeRate, 50);
    });
    
    it('should prevent non-admin from setting protocol fee rate', async () => {
      const result = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'set-protocol-fee-rate',
        [Cl.uint(50)],
        user1 // Not an admin
      );
      
      expectErrWithCode(result, ERR_NOT_AUTHORIZED);
    });
    
    it('should allow operator to update funding rate', async () => {
      const result = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'update-funding-rate',
        [Cl.principal(TOKEN_CONTRACT)],
        deployer // Has operator role
      );
      
      expectOk(result);
    });
    
    it('should prevent updating funding rate too soon', async () => {
      const result = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'update-funding-rate',
        [Cl.principal(TOKEN_CONTRACT)],
        deployer
      );
      
      expectErrWithCode(result, ERR_INVALID_INPUT);
    });
  });
  
  describe('Position Management', () => {
    let positionId: number;
    
    it('should allow opening a long position', async () => {
      const result = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'open-position',
        [
          Cl.principal(TOKEN_CONTRACT),
          Cl.uint(COLLATERAL),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.some(Cl.uint(STOP_LOSS)),
          Cl.some(Cl.uint(TAKE_PROFIT))
        ],
        user1
      );
      
      expectOk(result);
      positionId = unwrapOk<number>(result);
      
      // Verify position was created
      const position = await simnet.callReadOnlyFn(
        ENGINE_CONTRACT,
        'get-position',
        [Cl.uint(positionId)],
        user1
      );
      
      expectOk(position);
      const positionData = unwrapOk<any>(position);
      expect(positionData.owner).toBe(user1);
      expect(positionData['is-active']).toBe(true);
    });
    
    it('should prevent opening position with insufficient balance', async () => {
      const largeAmount = INITIAL_BALANCE * 2;
      
      const result = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'open-position',
        [
          Cl.principal(TOKEN_CONTRACT),
          Cl.uint(largeAmount),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.none(),
          Cl.none()
        ],
        user1
      );
      
      expectErrWithCode(result, ERR_INSUFFICIENT_BALANCE);
    });
    
    it('should prevent opening position with invalid leverage', async () => {
      const invalidLeverage = 5001; // Exceeds max leverage
      
      const result = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'open-position',
        [
          Cl.principal(TOKEN_CONTRACT),
          Cl.uint(COLLATERAL),
          Cl.uint(invalidLeverage),
          Cl.bool(true),
          Cl.none(),
          Cl.none()
        ],
        user1
      );
      
      expectErrWithCode(result, ERR_INVALID_LEVERAGE);
    });
    
    it('should allow closing a position', async () => {
      const posId = await openPosition(
        simnet,
        user2,
        TOKEN_CONTRACT,
        COLLATERAL,
        LEVERAGE,
        true
      );
      
      // Close the position
      const result = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'close-position',
        [Cl.uint(posId), Cl.none()],
        user2
      );
      
      expectOk(result);
      
      // Verify position is closed
      const position = await simnet.callReadOnlyFn(
        ENGINE_CONTRACT,
        'get-position',
        [Cl.uint(posId)],
        user2
      );
      
      const positionData = unwrapOk<any>(position);
      expect(positionData['is-active']).toBe(false);
    });
    
    it('should prevent closing non-existent position', async () => {
      const nonExistentId = 9999;
      const result = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'close-position',
        [Cl.uint(nonExistentId), Cl.none()],
        user1
      );
      
      expectErrWithCode(result, ERR_POSITION_NOT_FOUND);
    });
  });
  
  describe('Liquidation', () => {
    let positionId: number;
    
    beforeAll(async () => {
      // Open a position for liquidation testing
      await simnet.callPublicFn(
        TOKEN_CONTRACT,
        'approve',
        [Cl.principal(ENGINE_CONTRACT), Cl.uint(COLLATERAL), Cl.none()],
        user2
      );
      
      const result = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'open-position',
        [
          Cl.principal(TOKEN_CONTRACT),
          Cl.uint(COLLATERAL),
          Cl.uint(LEVERAGE),
          Cl.bool(true), // long
          Cl.none(),
          Cl.none()
        ],
        user2
      );
      
      positionId = Number(cvToValue((result.result as ResponseOkCV<ClarityValue>).value));
      
      // Update price to trigger liquidation (50% price drop)
      await simnet.callPublicFn(
        ORACLE_CONTRACT,
        'set-price',
        [Cl.uint(500_000)], // $5.00 (50% drop)
        deployer
      );
    });
    
    it('should allow liquidator to close undercollateralized position', async () => {
      // User1 (liquidator) liquidates user2's position
      const result = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'liquidate-position',
        [Cl.uint(positionId)],
        user1 // Has liquidator role
      );
      
      expectOk(result);
      
      // Verify position is closed
      const position = await simnet.callReadOnlyFn(
        ENGINE_CONTRACT,
        'get-position',
        [Cl.uint(positionId)],
        user1
      );
      
      const positionData = unwrapOk<any>(position);
      expect(positionData['is-active']).toBe(false);
    });
    
    it('should prevent liquidating healthy positions', async () => {
      // Open a new position
      await simnet.callPublicFn(
        TOKEN_CONTRACT,
        'approve',
        [Cl.principal(ENGINE_CONTRACT), Cl.uint(COLLATERAL), Cl.none()],
        user1
      );
      
      const openResult = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'open-position',
        [
          Cl.principal(TOKEN_CONTRACT),
          Cl.uint(COLLATERAL),
          Cl.uint(LEVERAGE),
          Cl.bool(true),
          Cl.none(),
          Cl.none()
        ],
        user1
      );
      
      const healthyPositionId = Number(cvToValue((openResult.result as ResponseOkCV<ClarityValue>).value));
      
      // Try to liquidate healthy position
      const result = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'liquidate-position',
        [Cl.uint(healthyPositionId)],
        user2
      );
      
      expectErrWithCode(result, ERR_INVALID_INPUT);
    });
  });
  
  describe('View Functions', () => {
    it('should return protocol statistics', async () => {
      const result = await simnet.callReadOnlyFn(
        ENGINE_CONTRACT,
        'get-protocol-stats',
        [],
        user1
      );
      
      expectOk(result);
      const stats = unwrapOk<any>(result);
      expect(stats).toHaveProperty('total-positions-opened');
      expect(stats).toHaveProperty('total-volume');
      expect(stats).toHaveProperty('total-fees-collected');
      expect(stats).toHaveProperty('total-value-locked');
    });
    
    it('should return open interest for an asset', async () => {
      const result = await simnet.callReadOnlyFn(
        ENGINE_CONTRACT,
        'get-open-interest',
        [Cl.principal(TOKEN_CONTRACT)],
        user1
      );
      
      expectOk(result);
      const oi = unwrapOk<any>(result);
      expect(oi).toHaveProperty('long');
      expect(oi).toHaveProperty('short');
    });
  });
  
  describe('Edge Cases', () => {
    it('should revoke operator role and block privileged actions', async () => {
      // Grant operator role to user2, then revoke
      const grant = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'grant-role',
        [Cl.uint(ROLE_OPERATOR), Cl.principal(user2)],
        deployer
      );
      expectOk(grant);

      const revoke = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'revoke-role',
        [Cl.uint(ROLE_OPERATOR), Cl.principal(user2)],
        deployer
      );
      expectOk(revoke);

      const attempt = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'update-funding-rate',
        [Cl.principal(TOKEN_CONTRACT)],
        user2
      );
      expectErrWithCode(attempt, ERR_NOT_AUTHORIZED);
    });

    it('should handle maximum leverage correctly', async () => {
      // Set max leverage to 50x
      await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'set-risk-parameters',
        [Cl.uint(5000), Cl.uint(500), Cl.uint(1000)], // maxLeverage, maintenanceMargin, liquidationThreshold
        deployer
      );
      
      // Try to open position with max leverage
      await simnet.callPublicFn(
        TOKEN_CONTRACT,
        'approve',
        [Cl.principal(ENGINE_CONTRACT), Cl.uint(COLLATERAL), Cl.none()],
        user1
      );
      
      const result = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'open-position',
        [
          Cl.principal(TOKEN_CONTRACT),
          Cl.uint(COLLATERAL),
          Cl.uint(5000), // 50x leverage
          Cl.bool(true),
          Cl.none(),
          Cl.none()
        ],
        user1
      );
      
      expectOk(result);
    });
    
    it('should prevent zero amount deposits', async () => {
      const result = await simnet.callPublicFn(
        ENGINE_CONTRACT,
        'deposit-funds',
        [Cl.uint(0), Cl.contractPrincipal(deployer, 'token')],
        user1
      );
      
      expectErrWithCode(result, ERR_INVALID_INPUT);
    });
  });
});
