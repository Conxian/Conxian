import { Cl, ClarityType, ClarityValue, ResponseOk, ResponseError, principalCV } from '@stacks/transactions';
import { describe, expect, it, beforeEach, run } from '@stacks/clarigen/sdk';
import { simnet } from '../.stacks/Clarigen';
import { expectOk, expectErr, simnet } from '@stacks/clarigen';

describe('Lending System Oracle Integration Tests', () => {
  const { oracle, lending } = simnet.getDeployedContractIds();
  const admin = simnet.deployer;
  const user1 = simnet.accounts.get('wallet_1')!;
  
  // Test tokens
  const usda = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5.usda';
  const wstx = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5.wstx';
  
  // Initial prices (6 decimals)
  const usdPrice = 1000000; // $1.00
  const stxPrice = 2500000;  // $2.50
  
  beforeEach(() => {
    // Reset the simnet
    simnet.mineEmptyBlock(0);
    
    // Set up initial prices in oracle
    simnet.callPublicFn(
      'oracle',
      'set-price',
      [Cl.principal(usda), Cl.uint(usdPrice)],
      admin
    );
    
    simnet.callPublicFn(
      'oracle',
      'set-price',
      [Cl.principal(wstx), Cl.uint(stxPrice)],
      admin
    );
    
    // Set oracle contract in lending system
    simnet.callPublicFn(
      'comprehensive-lending-system',
      'set-oracle-contract',
      [Cl.principal(oracle)],
      admin
    );
    
    // Add supported assets
    simnet.callPublicFn(
      'comprehensive-lending-system',
      'add-supported-asset',
      [
        Cl.contractPrincipal(usda),
        Cl.uint(800000000000000000), // 80% collateral factor
        Cl.uint(850000000000000000), // 85% liquidation threshold
        Cl.uint(10000000000000000),  // 1% reserve factor
        Cl.uint(5000000000000000)    // 0.5% liquidation bonus
      ],
      admin
    );
    
    simnet.callPublicFn(
      'comprehensive-lending-system',
      'add-supported-asset',
      [
        Cl.contractPrincipal(wstx),
        Cl.uint(650000000000000000), // 65% collateral factor
        Cl.uint(700000000000000000), // 70% liquidation threshold
        Cl.uint(10000000000000000),  // 1% reserve factor
        Cl.uint(100000000000000000)  // 10% liquidation bonus
      ],
      admin
    );
  });

  describe('Price Integration', () => {
    it('should get asset price from oracle', () => {
      const price = simnet.callReadOnlyFn(
        'comprehensive-lending-system',
        'get-asset-price',
        [Cl.principal(usda)],
        admin
      );
      expect(price).toBeOk(Cl.uint(usdPrice));
    });
    
    it('should handle stale prices', () => {
      // Make price stale
      const staleThreshold = 24 * 60 * 30; // 24 hours in blocks (30 blocks per minute)
      simnet.mineEmptyBlock(staleThreshold + 1);
      
      const isFresh = simnet.callReadOnlyFn(
        'comprehensive-lending-system',
        'is-asset-price-fresh',
        [Cl.principal(usda)],
        admin
      );
      expect(isFresh).toBeOk(Cl.bool(false));
    });
  });

  describe('Health Factor Calculation', () => {
    it('should calculate health factor with oracle prices', () => {
      // User supplies 10 wSTX ($25) as collateral
      const supplyAmount = 10 * 1e8; // 10 wSTX (8 decimals)
      simnet.callPublicFn(
        'comprehensive-lending-system',
        'supply',
        [
          Cl.contractPrincipal(wstx),
          Cl.uint(supplyAmount)
        ],
        user1
      );
      
      // Enable collateral
      simnet.callPublicFn(
        'comprehensive-lending-system',
        'set-user-asset-use-as-collateral',
        [Cl.principal(wstx), Cl.bool(true)],
        user1
      );
      
      // Borrow 5 USDA ($5)
      const borrowAmount = 5 * 1e8; // 5 USDA (8 decimals)
      simnet.callPublicFn(
        'comprehensive-lending-system',
        'borrow',
        [
          Cl.contractPrincipal(usda),
          Cl.uint(borrowAmount)
        ],
        user1
      );
      
      // Get health factor
      const healthFactor = simnet.callReadOnlyFn(
        'comprehensive-lending-system',
        'get-health-factor',
        [Cl.principal(user1)],
        user1
      );
      
      // Expected calculation:
      // Collateral: 10 wSTX * $2.50 = $25 * 65% collateral factor = $16.25
      // Debt: $5
      // Health factor = $16.25 / $5 = 3.25
      expect(healthFactor).toBeOk(Cl.uint(3250000000000000000));
    });
  });

  describe('Liquidation', () => {
    beforeEach(() => {
      // Set up a position that can be liquidated
      const supplyAmount = 10 * 1e8; // 10 wSTX ($25)
      simnet.callPublicFn(
        'comprehensive-lending-system',
        'supply',
        [Cl.contractPrincipal(wstx), Cl.uint(supplyAmount)],
        user1
      );
      
      // Enable collateral
      simnet.callPublicFn(
        'comprehensive-lending-system',
        'set-user-asset-use-as-collateral',
        [Cl.principal(wstx), Cl.bool(true)],
        user1
      );
      
      // Borrow close to the limit
      const borrowAmount = 15 * 1e8; // 15 USDA ($15)
      simnet.callPublicFn(
        'comprehensive-lending-system',
        'borrow',
        [Cl.contractPrincipal(usda), Cl.uint(borrowAmount)],
        user1
      );
    });
    
    it('should liquidate undercollateralized position using oracle prices', () => {
      // Price of wSTX drops to $1.50 (from $2.50)
      const newStxPrice = 1500000; // $1.50
      simnet.callPublicFn(
        'oracle',
        'set-price',
        [Cl.principal(wstx), Cl.uint(newStxPrice)],
        admin
      );
      
      // Check position is underwater
      const healthFactor = simnet.callReadOnlyFn(
        'comprehensive-lending-system',
        'get-health-factor',
        [Cl.principal(user1)],
        admin
      );
      
      // Collateral: 10 wSTX * $1.50 = $15 * 65% = $9.75
      // Debt: $15
      // Health factor = $9.75 / $15 = 0.65 (below 1.0)
      expect(healthFactor).toBeOk(Cl.uint(650000000000000000));
      
      // Liquidate half the debt (7.5 USDA)
      const liquidateAmount = 7.5 * 1e8;
      const liquidator = simnet.accounts.get('wallet_2')!;
      
      // TODO: Set up liquidator's USDA balance and approvals
      
      const liquidate = simnet.callPublicFn(
        'comprehensive-lending-system',
        'liquidate',
        [
          Cl.principal(user1),
          Cl.uint(liquidateAmount),
          Cl.contractPrincipal(wstx),
          Cl.contractPrincipal(usda)
        ],
        liquidator
      );
      
      expect(liquidate).toBeOk(Cl.bool(true));
      
      // TODO: Verify liquidation amounts and state changes
    });
  });
});

// Run the tests
run();
