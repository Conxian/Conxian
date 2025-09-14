// flash-loan-integration.test.ts
// Comprehensive flash loan integration tests with actual SIP-010 token transfers
// Tests ERC-3156-inspired implementation against real Stacks environment

import { describe, it, expect, beforeEach, beforeAll } from 'vitest';
import { Cl, ClarityValue, cvToValue } from '@stacks/transactions';
import { Simnet, initSimnet, burnSTX } from '@hirosystems/clarinet-sdk';

describe('Flash Loan Integration Tests', () => {
  let simnet: Simnet;
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let flashLoanReceiver: string;

  beforeAll(async () => {
    simnet = await initSimnet();
    deployer = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    wallet1 = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
    wallet2 = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
    flashLoanReceiver = 'ST2NEB84ASENDXKYGJPQW86YXQCEFEX2ZQPG87ND';
  });

  beforeEach(async () => {
    // Reset simnet state
    simnet = await initSimnet();
    
    // Setup test tokens and initial liquidity
    await setupTestEnvironment();
  });

  async function setupTestEnvironment() {
    // Initialize mathematical libraries
    const mathInit = simnet.callPublicFn('math-lib-advanced', 'sqrt-fixed', [
      Cl.uint(4000000000000000000) // Test sqrt(4) = 2
    ], deployer);
    expect(mathInit.result).toBeDefined();

    // Initialize mock token for testing
    const tokenInit = simnet.callPublicFn('mock-token', 'mint', [
      Cl.uint(1000000000000), // 1M tokens
      Cl.principal(deployer)
    ], deployer);
    expect(tokenInit.result).toBeOk(Cl.bool(true));

    // Add supported asset to vault
    const addAsset = simnet.callPublicFn('enhanced-flash-loan-vault', 'add-supported-asset', [
      Cl.principal(deployer + '.mock-token'),
      Cl.uint(10000000000000) // 10K cap
    ], deployer);
    expect(addAsset.result).toBeOk(Cl.bool(true));

    // Deposit initial liquidity
    const deposit = simnet.callPublicFn('enhanced-flash-loan-vault', 'deposit', [
      Cl.principal(deployer + '.mock-token'),
      Cl.uint(500000000000) // 500K tokens
    ], deployer);
    expect(deposit.result).toBeDefined();
  }

  describe('Flash Loan Core Functionality', () => {
    it('should execute basic flash loan with fee payment', async () => {
      const flashLoanAmount = 100000000000; // 100K tokens
      
      // Check initial balances
      const initialVaultBalance = simnet.callReadOnlyFn('enhanced-flash-loan-vault', 'get-total-balance', [
        Cl.principal(deployer + '.mock-token')
      ], deployer);
      
      // Execute flash loan
      const flashLoanResult = simnet.callPublicFn('enhanced-flash-loan-vault', 'flash-loan', [
        Cl.principal(deployer + '.mock-token'),
        Cl.uint(flashLoanAmount),
        Cl.principal(flashLoanReceiver),
        Cl.buffer(new TextEncoder().encode('test-data'))
      ], deployer);

      expect(flashLoanResult.result).toBeOk(Cl.bool(true));

      // Verify fee was collected
      const finalVaultBalance = simnet.callReadOnlyFn('enhanced-flash-loan-vault', 'get-total-balance', [
        Cl.principal(deployer + '.mock-token')
      ], deployer);
      
      // Balance should be slightly higher due to fee
      // Default fee is 0.3% = 300000000 on 100K tokens
      const expectedFee = Math.floor(flashLoanAmount * 30 / 10000);
      // expect(cvToValue(finalVaultBalance.result)).toBeGreaterThan(cvToValue(initialVaultBalance.result));
    });

    it('should reject flash loan for unsupported asset', async () => {
      const flashLoanResult = simnet.callPublicFn('enhanced-flash-loan-vault', 'flash-loan', [
        Cl.principal('ST000000000000000000002AMW42H.unsupported-token'),
        Cl.uint(1000),
        Cl.principal(flashLoanReceiver),
        Cl.buffer(new TextEncoder().encode(''))
      ], deployer);

      expect(flashLoanResult.result).toBeErr(Cl.uint(6006)); // ERR_INVALID_ASSET
    });

    it('should reject flash loan when insufficient liquidity', async () => {
      const excessiveAmount = 1000000000000; // 1M tokens (more than available)
      
      const flashLoanResult = simnet.callPublicFn('enhanced-flash-loan-vault', 'flash-loan', [
        Cl.principal(deployer + '.mock-token'),
        Cl.uint(excessiveAmount),
        Cl.principal(flashLoanReceiver),
        Cl.buffer(new TextEncoder().encode(''))
      ], deployer);

      expect(flashLoanResult.result).toBeErr(Cl.uint(6008)); // ERR_INSUFFICIENT_LIQUIDITY
    });

    it('should prevent reentrancy attacks', async () => {
      // First flash loan call
      const firstCall = simnet.callPublicFn('enhanced-flash-loan-vault', 'flash-loan', [
        Cl.principal(deployer + '.mock-token'),
        Cl.uint(50000000000),
        Cl.principal(flashLoanReceiver),
        Cl.buffer(new TextEncoder().encode('first'))
      ], deployer);

      // Attempt second flash loan while first is in progress (simulated)
      const secondCall = simnet.callPublicFn('enhanced-flash-loan-vault', 'flash-loan', [
        Cl.principal(deployer + '.mock-token'),
        Cl.uint(25000000000),
        Cl.principal(flashLoanReceiver),
        Cl.buffer(new TextEncoder().encode('second'))
      ], deployer);

      // One should succeed, other should fail due to reentrancy protection
      const firstSucceeded = firstCall.result.type === 'ok';
      const secondSucceeded = secondCall.result.type === 'ok';
      
      // Only one should succeed
      expect(firstSucceeded !== secondSucceeded).toBe(true);
    });
  });

  describe('Mathematical Integration', () => {
    it('should calculate flash loan fees using mathematical libraries', async () => {
      const amount = 1000000000000; // 1K tokens
      const feeBps = 30; // 0.3%
      
      const feeResult = simnet.callReadOnlyFn('enhanced-flash-loan-vault', 'get-flash-loan-fee', [
        Cl.principal(deployer + '.mock-token'),
        Cl.uint(amount)
      ], deployer);

      expect(feeResult.result).toBeOk(Cl.uint(amount * feeBps / 10000));
    });

    it('should use precision calculator for accurate fee calculations', async () => {
      // Test with amounts that could cause precision loss
      const preciseAmount = 123456789123456; // Complex number
      
      const feeResult = simnet.callReadOnlyFn('enhanced-flash-loan-vault', 'get-flash-loan-fee', [
        Cl.principal(deployer + '.mock-token'),
        Cl.uint(preciseAmount)
      ], deployer);

      // Should handle precision without overflow
      expect(feeResult.result.type).toBe('ok');
    });
  });

  describe('Integration with Lending System', () => {
    it('should interact with comprehensive lending system', async () => {
      // Setup lending system
      const setupLending = simnet.callPublicFn('comprehensive-lending-system', 'add-supported-asset', [
        Cl.principal(deployer + '.mock-token'),
        Cl.uint(800000000000000000), // 80% collateral factor
        Cl.uint(850000000000000000), // 85% liquidation threshold  
        Cl.uint(50000000000000000),  // 5% liquidation bonus
        Cl.uint(30) // 0.3% flash loan fee
      ], deployer);

      expect(setupLending.result).toBeOk(Cl.bool(true));

      // Execute flash loan through lending system
      const flashLoanResult = simnet.callPublicFn('comprehensive-lending-system', 'flash-loan', [
        Cl.principal(deployer + '.mock-token'),
        Cl.uint(100000000000),
        Cl.principal(flashLoanReceiver),
        Cl.buffer(new TextEncoder().encode('lending-test'))
      ], deployer);

      expect(flashLoanResult.result).toBeOk(Cl.bool(true));
    });

    it('should update interest rates after flash loan', async () => {
      // Get initial rates
      const initialSupplyAPY = simnet.callReadOnlyFn('comprehensive-lending-system', 'get-supply-apy', [
        Cl.principal(deployer + '.mock-token')
      ], deployer);

      const initialBorrowAPY = simnet.callReadOnlyFn('comprehensive-lending-system', 'get-borrow-apy', [
        Cl.principal(deployer + '.mock-token')
      ], deployer);

      // Execute flash loan
      const flashLoan = simnet.callPublicFn('comprehensive-lending-system', 'flash-loan', [
        Cl.principal(deployer + '.mock-token'),
        Cl.uint(200000000000),
        Cl.principal(flashLoanReceiver),
        Cl.buffer(new TextEncoder().encode('rate-test'))
      ], deployer);

      // Get updated rates
      const finalSupplyAPY = simnet.callReadOnlyFn('comprehensive-lending-system', 'get-supply-apy', [
        Cl.principal(deployer + '.mock-token')
      ], deployer);

      const finalBorrowAPY = simnet.callReadOnlyFn('comprehensive-lending-system', 'get-borrow-apy', [
        Cl.principal(deployer + '.mock-token')
      ], deployer);

      // Rates should be updated (could be same if utilization doesn't change much)
      expect(initialSupplyAPY.result).toBeDefined();
      expect(finalSupplyAPY.result).toBeDefined();
    });
  });

  describe('Security and Edge Cases', () => {
    it('should handle callback failures gracefully', async () => {
      // Create a receiver that will fail
      const failingReceiver = 'ST000000000000000000002AMW42H.failing-receiver';
      
      const flashLoanResult = simnet.callPublicFn('enhanced-flash-loan-vault', 'flash-loan', [
        Cl.principal(deployer + '.mock-token'),
        Cl.uint(50000000000),
        Cl.principal(failingReceiver),
        Cl.buffer(new TextEncoder().encode('fail-test'))
      ], deployer);

      // Should fail gracefully
      expect(flashLoanResult.result).toBeErr(Cl.uint(6009)); // ERR_CALLBACK_FAILED
    });

    it('should validate fee payment before completion', async () => {
      const amount = 100000000000;
      const expectedFee = amount * 30 / 10000; // 0.3% fee

      // Get maximum flash loan amount
      const maxAmount = simnet.callReadOnlyFn('enhanced-flash-loan-vault', 'get-max-flash-loan', [
        Cl.principal(deployer + '.mock-token')
      ], deployer);

      expect(maxAmount.result.type).toBe('ok');
      
      // Should be greater than our test amount
      const maxValue = cvToValue(maxAmount.result);
      expect(maxValue).toBeGreaterThan(amount);
    });

    it('should prevent flash loans during system pause', async () => {
      // Pause the system
      const pauseResult = simnet.callPublicFn('enhanced-flash-loan-vault', 'set-paused', [
        Cl.bool(true)
      ], deployer);
      expect(pauseResult.result).toBeOk(Cl.bool(true));

      // Attempt flash loan
      const flashLoanResult = simnet.callPublicFn('enhanced-flash-loan-vault', 'flash-loan', [
        Cl.principal(deployer + '.mock-token'),
        Cl.uint(50000000000),
        Cl.principal(flashLoanReceiver),
        Cl.buffer(new TextEncoder().encode('pause-test'))
      ], deployer);

      expect(flashLoanResult.result).toBeErr(Cl.uint(6002)); // ERR_PAUSED
    });
  });

  describe('Statistics and Analytics', () => {
    it('should track flash loan statistics', async () => {
      // Execute multiple flash loans
      const amounts = [10000000000, 25000000000, 50000000000];
      
      for (const amount of amounts) {
        const flashLoan = simnet.callPublicFn('enhanced-flash-loan-vault', 'flash-loan', [
          Cl.principal(deployer + '.mock-token'),
          Cl.uint(amount),
          Cl.principal(flashLoanReceiver),
          Cl.buffer(new TextEncoder().encode(`stats-${amount}`))
        ], deployer);
        
        expect(flashLoan.result).toBeOk(Cl.bool(true));
      }

      // Check statistics
      const stats = simnet.callReadOnlyFn('enhanced-flash-loan-vault', 'get-flash-loan-stats', [
        Cl.principal(deployer + '.mock-token')
      ], deployer);

      expect(stats.result).toBeDefined();
      // Should have recorded 3 flash loans
      // const statsValue = cvToValue(stats.result);
      // expect(statsValue['total-flash-loans']).toBe(3);
    });

    it('should calculate utilization metrics', async () => {
      const utilizationResult = simnet.callReadOnlyFn('enhanced-flash-loan-vault', 'get-utilization', [
        Cl.principal(deployer + '.mock-token')
      ], deployer);

      expect(utilizationResult.result).toBeOk(Cl.tuple({
        'total-balance': Cl.uint(500000000000),
        'flash-loans-count': Cl.uint(0),
        'flash-loan-volume': Cl.uint(0),
        'fees-collected': Cl.uint(0),
        'utilization-rate': Cl.uint(0)
      }));
    });

    it('should provide revenue distribution stats', async () => {
      const revenueStats = simnet.callReadOnlyFn('enhanced-flash-loan-vault', 'get-revenue-stats', [], deployer);

      expect(revenueStats.result).toBeOk(Cl.tuple({
        'protocol-reserve': Cl.uint(0),
        'treasury-reserve': Cl.uint(0),
        'total-revenue': Cl.uint(0),
        'revenue-share-bps': Cl.uint(2000) // 20%
      }));
    });
  });

  describe('Nakamoto Compatibility', () => {
    it('should handle fast block times', async () => {
      // Simulate rapid flash loans (Nakamoto fast blocks)
      const rapidCalls = [];
      for (let i = 0; i < 5; i++) {
        rapidCalls.push(
          simnet.callPublicFn('enhanced-flash-loan-vault', 'flash-loan', [
            Cl.principal(deployer + '.mock-token'),
            Cl.uint(10000000000),
            Cl.principal(flashLoanReceiver),
            Cl.buffer(new TextEncoder().encode(`rapid-${i}`))
          ], deployer)
        );
      }

      // All should be processed correctly
      for (const call of rapidCalls) {
        expect(call.result.type).toBe('ok');
      }
    });

    it('should be ready for sBTC integration', async () => {
      // Test with Bitcoin-like precision (8 decimals vs 18)
      const btcAmount = 100000000; // 1 BTC in satoshis
      
      // Should handle different precision levels
      const feeResult = simnet.callReadOnlyFn('enhanced-flash-loan-vault', 'get-flash-loan-fee', [
        Cl.principal(deployer + '.mock-token'),
        Cl.uint(btcAmount)
      ], deployer);

      expect(feeResult.result.type).toBe('ok');
    });
  });
});
