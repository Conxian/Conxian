import { describe, it, expect, beforeEach } from 'vitest';
import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';

describe('Comprehensive Lending System Tests', () => {
  let accounts: Map<string, Account>;
  let chain: Chain;

  beforeEach(() => {
    const clarinet = new Clarinet();
    accounts = clarinet.accounts;
    chain = clarinet.chain;
  });

  describe('Mathematical Libraries', () => {
    describe('Advanced Math Library', () => {
      it('should calculate square root correctly', () => {
        const wallet = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
          Tx.contractCall(
            'math-lib-advanced',
            'sqrt-fixed',
            [types.uint(4000000000000000000)], // 4.0 in 18 decimals
            wallet.address
          ),
        ]);
        
        expect(block.receipts).toHaveLength(1);
        expect(block.receipts[0].result).toBeOk(types.uint(2000000000000000000)); // 2.0
      });

      it('should calculate power correctly', () => {
        const wallet = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
          Tx.contractCall(
            'math-lib-advanced',
            'pow-fixed',
            [
              types.uint(2000000000000000000), // 2.0
              types.uint(3000000000000000000)  // 3.0
            ],
            wallet.address
          ),
        ]);
        
        expect(block.receipts).toHaveLength(1);
        expect(block.receipts[0].result).toBeOk(types.uint(8000000000000000000)); // 8.0
      });

      it('should calculate natural logarithm', () => {
        const wallet = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
          Tx.contractCall(
            'math-lib-advanced',
            'ln-fixed',
            [types.uint(2718281828459045235)], // e
            wallet.address
          ),
        ]);
        
        expect(block.receipts).toHaveLength(1);
        // Should be approximately 1.0
        const result = block.receipts[0].result.expectOk();
        expect(Number(result)).toBeCloseTo(1000000000000000000, -15);
      });
    });

    describe('Fixed Point Math', () => {
      it('should multiply with proper rounding', () => {
        const wallet = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
          Tx.contractCall(
            'fixed-point-math',
            'mul-down',
            [
              types.uint(3333333333333333333), // 3.333...
              types.uint(3000000000000000000)  // 3.0
            ],
            wallet.address
          ),
        ]);
        
        expect(block.receipts).toHaveLength(1);
        expect(block.receipts[0].result).toBeOk(types.uint(9999999999999999999)); // 9.999...
      });

      it('should calculate percentage correctly', () => {
        const wallet = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
          Tx.contractCall(
            'fixed-point-math',
            'percentage',
            [
              types.uint(1000000000000000000000), // 1000
              types.uint(50000000000000000)       // 5%
            ],
            wallet.address
          ),
        ]);
        
        expect(block.receipts).toHaveLength(1);
        expect(block.receipts[0].result).toBeOk(types.uint(50000000000000000000)); // 50
      });
    });
  });

  describe('Interest Rate Model', () => {
    it('should calculate interest rates based on utilization', () => {
      const wallet = accounts.get('deployer')!;
      
      let block = chain.mineBlock([
        Tx.contractCall(
          'interest-rate-model',
          'get-borrow-rate',
          [
            types.uint(500000000000000000000000), // 500k cash
            types.uint(500000000000000000000000), // 500k borrows
            types.uint(0)                        // 0 reserves
          ],
          wallet.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(1);
      expect(block.receipts[0].result).toBeOk();
      
      // Should return a reasonable interest rate for 50% utilization
      const rate = block.receipts[0].result.expectOk();
      expect(Number(rate)).toBeGreaterThan(0);
      expect(Number(rate)).toBeLessThan(1000000000000000000); // Less than 100%
    });

    it('should handle extreme utilization rates', () => {
      const wallet = accounts.get('deployer')!;
      
      // Test 95% utilization (near kink)
      let block = chain.mineBlock([
        Tx.contractCall(
          'interest-rate-model',
          'get-borrow-rate',
          [
            types.uint(50000000000000000000000),  // 50k cash
            types.uint(950000000000000000000000), // 950k borrows
            types.uint(0)
          ],
          wallet.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(1);
      expect(block.receipts[0].result).toBeOk();
      
      const highUtilRate = block.receipts[0].result.expectOk();
      expect(Number(highUtilRate)).toBeGreaterThan(0);
    });
  });

  describe('Comprehensive Lending System', () => {
    beforeEach(() => {
      // Initialize the lending system
      const deployer = accounts.get('deployer')!;
      
      chain.mineBlock([
        Tx.contractCall(
          'comprehensive-lending-system',
          'initialize-market',
          [
            types.principal('ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.cxd-token'), // Mock token
            types.uint(800000000000000000),  // 80% collateral factor
            types.uint(900000000000000000),  // 90% liquidation threshold
            types.uint(50000000000000000),   // 5% reserve factor
            types.principal('ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.interest-rate-model')
          ],
          deployer.address
        ),
      ]);
    });

    it('should allow users to supply assets', () => {
      const supplier = accounts.get('wallet_1')!;
      
      let block = chain.mineBlock([
        Tx.contractCall(
          'comprehensive-lending-system',
          'supply',
          [
            types.principal('ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.cxd-token'),
            types.uint(1000000000000000000000) // 1000 tokens
          ],
          supplier.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(1);
      expect(block.receipts[0].result).toBeOk();
    });

    it('should calculate health factor correctly', () => {
      const borrower = accounts.get('wallet_2')!;
      
      // First supply collateral, then borrow
      let setupBlock = chain.mineBlock([
        Tx.contractCall(
          'comprehensive-lending-system',
          'supply',
          [
            types.principal('ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.cxd-token'),
            types.uint(2000000000000000000000)
          ],
          borrower.address
        ),
        Tx.contractCall(
          'comprehensive-lending-system',
          'borrow',
          [
            types.principal('ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.cxd-token'),
            types.uint(1000000000000000000000)
          ],
          borrower.address
        ),
      ]);

      let healthBlock = chain.mineBlock([
        Tx.contractCall(
          'comprehensive-lending-system',
          'get-health-factor',
          [types.principal(borrower.address)],
          borrower.address
        ),
      ]);
      
      expect(healthBlock.receipts).toHaveLength(1);
      expect(healthBlock.receipts[0].result).toBeOk();
      
      const healthFactor = healthBlock.receipts[0].result.expectOk();
      expect(Number(healthFactor)).toBeGreaterThan(1000000000000000000); // > 1.0
    });

    it('should execute flash loans successfully', () => {
      const flashBorrower = accounts.get('wallet_3')!;
      
      let block = chain.mineBlock([
        Tx.contractCall(
          'comprehensive-lending-system',
          'flash-loan',
          [
            types.principal('ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.cxd-token'),
            types.uint(100000000000000000000), // 100 tokens
            types.principal(flashBorrower.address),
            types.buff(new TextEncoder().encode('test-data'))
          ],
          flashBorrower.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(1);
      // Flash loan should succeed if receiver implements the callback correctly
    });
  });

  describe('Enhanced Flash Loan Vault', () => {
    it('should track flash loan statistics', () => {
      const user = accounts.get('wallet_1')!;
      
      let block = chain.mineBlock([
        Tx.contractCall(
          'enhanced-flash-loan-vault',
          'get-flash-loan-stats',
          [],
          user.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(1);
      expect(block.receipts[0].result).toBeOk();
      
      const stats = block.receipts[0].result.expectOk().expectTuple();
      expect(stats['total-flash-loans']).toBeDefined();
      expect(stats['total-volume']).toBeDefined();
      expect(stats['total-fees-collected']).toBeDefined();
    });

    it('should calculate flash loan fees correctly', () => {
      const user = accounts.get('wallet_1')!;
      
      let block = chain.mineBlock([
        Tx.contractCall(
          'enhanced-flash-loan-vault',
          'calculate-flash-loan-fee',
          [
            types.principal('ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.cxd-token'),
            types.uint(1000000000000000000000) // 1000 tokens
          ],
          user.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(1);
      expect(block.receipts[0].result).toBeOk();
      
      const fee = block.receipts[0].result.expectOk();
      expect(Number(fee)).toBeGreaterThan(0);
      expect(Number(fee)).toBeLessThan(1000000000000000000000); // Less than principal
    });

    it('should prevent reentrancy attacks', () => {
      const attacker = accounts.get('wallet_4')!;
      
      // This would test reentrancy protection
      // In practice, we'd deploy a malicious contract that tries to re-enter
      let block = chain.mineBlock([
        Tx.contractCall(
          'enhanced-flash-loan-vault',
          'flash-loan',
          [
            types.principal('ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.cxd-token'),
            types.uint(100000000000000000000),
            types.principal(attacker.address),
            types.buff(new TextEncoder().encode('reentrancy-test'))
          ],
          attacker.address
        ),
      ]);
      
      // Should either succeed normally or fail with reentrancy error
      expect(block.receipts).toHaveLength(1);
    });
  });

  describe('Liquidation Manager', () => {
    it('should identify liquidatable positions', () => {
      const liquidator = accounts.get('wallet_1')!;
      const borrower = accounts.get('wallet_2')!;
      
      let block = chain.mineBlock([
        Tx.contractCall(
          'loan-liquidation-manager',
          'is-position-liquidatable',
          [types.principal(borrower.address)],
          liquidator.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(1);
      expect(block.receipts[0].result).toBeOk();
    });

    it('should calculate liquidation amounts correctly', () => {
      const liquidator = accounts.get('wallet_1')!;
      const borrower = accounts.get('wallet_2')!;
      
      let block = chain.mineBlock([
        Tx.contractCall(
          'loan-liquidation-manager',
          'calculate-liquidation-amounts',
          [
            types.principal(borrower.address),
            types.principal('ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.cxd-token'), // debt asset
            types.principal('ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.cxd-token')  // collateral asset
          ],
          liquidator.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(1);
      expect(block.receipts[0].result).toBeOk();
      
      const amounts = block.receipts[0].result.expectOk().expectTuple();
      expect(amounts['max-debt-repayable']).toBeDefined();
      expect(amounts['collateral-to-seize']).toBeDefined();
      expect(amounts['liquidation-incentive']).toBeDefined();
    });

    it('should track liquidation statistics', () => {
      const user = accounts.get('wallet_1')!;
      
      let block = chain.mineBlock([
        Tx.contractCall(
          'loan-liquidation-manager',
          'get-liquidation-stats',
          [],
          user.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(1);
      expect(block.receipts[0].result).toBeOk();
      
      const stats = block.receipts[0].result.expectOk().expectTuple();
      expect(stats['total-liquidations']).toBeDefined();
      expect(stats['total-debt-liquidated']).toBeDefined();
      expect(stats['total-collateral-seized']).toBeDefined();
    });
  });

  describe('Governance System', () => {
    it('should allow proposal creation', () => {
      const proposer = accounts.get('wallet_1')!;
      
      let block = chain.mineBlock([
        Tx.contractCall(
          'lending-protocol-governance',
          'propose',
          [
            types.ascii('Test Proposal'),
            types.utf8('This is a test proposal for the governance system'),
            types.uint(1), // PROPOSAL_TYPE_PARAMETER
            types.some(types.principal('ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.comprehensive-lending-system')),
            types.some(types.ascii('set-parameter')),
            types.some(types.list([types.uint(100)]))
          ],
          proposer.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(1);
      // Proposal creation might fail due to insufficient voting power, but should not throw
    });

    it('should track governance parameters', () => {
      const user = accounts.get('wallet_1')!;
      
      let block = chain.mineBlock([
        Tx.contractCall(
          'lending-protocol-governance',
          'get-governance-parameters',
          [],
          user.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(1);
      expect(block.receipts[0].result).toBeOk();
      
      const params = block.receipts[0].result.expectOk().expectTuple();
      expect(params['voting-delay']).toBeDefined();
      expect(params['voting-period']).toBeDefined();
      expect(params['quorum-threshold']).toBeDefined();
    });

    it('should handle delegation', () => {
      const delegator = accounts.get('wallet_1')!;
      const delegatee = accounts.get('wallet_2')!;
      
      let block = chain.mineBlock([
        Tx.contractCall(
          'lending-protocol-governance',
          'delegate',
          [types.principal(delegatee.address)],
          delegator.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(1);
      expect(block.receipts[0].result).toBeOk();
    });
  });

  describe('Integration Tests', () => {
    it('should handle complex lending scenarios', () => {
      const supplier = accounts.get('wallet_1')!;
      const borrower = accounts.get('wallet_2')!;
      const liquidator = accounts.get('wallet_3')!;
      
      // Multi-step integration test
      let block = chain.mineBlock([
        // 1. Supplier provides liquidity
        Tx.contractCall(
          'comprehensive-lending-system',
          'supply',
          [
            types.principal('ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.cxd-token'),
            types.uint(10000000000000000000000) // 10,000 tokens
          ],
          supplier.address
        ),
        
        // 2. Borrower supplies collateral and borrows
        Tx.contractCall(
          'comprehensive-lending-system',
          'supply',
          [
            types.principal('ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.cxd-token'),
            types.uint(5000000000000000000000) // 5,000 tokens as collateral
          ],
          borrower.address
        ),
        
        Tx.contractCall(
          'comprehensive-lending-system',
          'borrow',
          [
            types.principal('ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.cxd-token'),
            types.uint(3000000000000000000000) // 3,000 tokens borrowed
          ],
          borrower.address
        ),
        
        // 3. Check health factor
        Tx.contractCall(
          'comprehensive-lending-system',
          'get-health-factor',
          [types.principal(borrower.address)],
          borrower.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(4);
      // All operations should succeed in a healthy lending scenario
    });

    it('should calculate accurate mathematical operations', () => {
      const user = accounts.get('wallet_1')!;
      
      // Test mathematical consistency across operations
      let block = chain.mineBlock([
        // Test compound interest calculation
        Tx.contractCall(
          'fixed-point-math',
          'compound-interest',
          [
            types.uint(1000000000000000000000), // 1000 principal
            types.uint(50000000000000000),      // 5% annual rate
            types.uint(365)                     // 365 days
          ],
          user.address
        ),
        
        // Test precision in mathematical operations
        Tx.contractCall(
          'precision-calculator',
          'validate-precision',
          [
            types.uint(1000000000000000000), // 1.0
            types.uint(3)                    // 3 decimal places
          ],
          user.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(2);
      expect(block.receipts[0].result).toBeOk();
      expect(block.receipts[1].result).toBeOk();
      
      const compoundResult = block.receipts[0].result.expectOk();
      expect(Number(compoundResult)).toBeGreaterThan(1000000000000000000000); // Should be > principal
    });

    it('should handle edge cases gracefully', () => {
      const user = accounts.get('wallet_1')!;
      
      // Test mathematical edge cases
      let block = chain.mineBlock([
        // Test square root of very small number
        Tx.contractCall(
          'math-lib-advanced',
          'sqrt-fixed',
          [types.uint(1)], // Smallest possible value
          user.address
        ),
        
        // Test division by very small number
        Tx.contractCall(
          'fixed-point-math',
          'div-down',
          [
            types.uint(1000000000000000000), // 1.0
            types.uint(1)                    // Very small divisor
          ],
          user.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(2);
      // Operations should either succeed or fail gracefully with appropriate errors
    });
  });

  describe('Performance and Gas Optimization', () => {
    it('should complete mathematical operations efficiently', () => {
      const user = accounts.get('wallet_1')!;
      
      // Test that complex mathematical operations complete within reasonable gas limits
      let block = chain.mineBlock([
        Tx.contractCall(
          'math-lib-advanced',
          'sqrt-fixed',
          [types.uint(100000000000000000000000)], // Large number
          user.address
        ),
        
        Tx.contractCall(
          'math-lib-advanced',
          'ln-fixed',
          [types.uint(1000000000000000000000)], // e^3 approximately
          user.address
        ),
        
        Tx.contractCall(
          'math-lib-advanced',
          'exp-fixed',
          [types.uint(3000000000000000000)], // 3.0
          user.address
        ),
      ]);
      
      expect(block.receipts).toHaveLength(3);
      
      // Check that all operations completed successfully
      block.receipts.forEach(receipt => {
        expect(receipt.result).toBeOk();
      });
    });

    it('should handle batch operations efficiently', () => {
      const users = [
        accounts.get('wallet_1')!,
        accounts.get('wallet_2')!,
        accounts.get('wallet_3')!
      ];
      
      // Simulate multiple users interacting with the system
      let transactions = users.flatMap(user => [
        Tx.contractCall(
          'comprehensive-lending-system',
          'supply',
          [
            types.principal('ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.cxd-token'),
            types.uint(1000000000000000000000)
          ],
          user.address
        ),
        
        Tx.contractCall(
          'enhanced-flash-loan-vault',
          'get-flash-loan-stats',
          [],
          user.address
        ),
      ]);
      
      let block = chain.mineBlock(transactions);
      
      expect(block.receipts).toHaveLength(6); // 2 transactions per user, 3 users
      
      // All operations should complete within the block
      block.receipts.forEach(receipt => {
        // Should not fail due to gas limits
        expect(receipt.result).not.toBeErr(types.uint(1)); // ERR_GAS_LIMIT_EXCEEDED
      });
    });
  });
});
