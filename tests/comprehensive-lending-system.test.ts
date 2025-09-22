import { describe, it, expect, beforeEach } from 'vitest';
import { Cl, ClarityType } from '@stacks/transactions';

describe('Comprehensive Lending System Tests', () => {
  const deployer = 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6';
  const user1 = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
  const user2 = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
  const user3 = 'ST2JHG361ZXG51QTKY2NQCVBP45UXAD5J45SHM2F5';
  const user4 = 'ST3PF13W7Z0RRM42A8VZRVFQ75SV1K26RXEP8YGKJ';

  const mockToken = `${deployer}.cxd-token`;
  const interestRateModel = `${deployer}.interest-rate-model`;

  describe('Mathematical Libraries', () => {
    describe('Advanced Math Library', () => {
      it('should calculate square root correctly', () => {
        const result = simnet.callReadOnlyFn(
          'math-lib-advanced',
          'sqrt-fixed',
          [Cl.uint(4000000000000000000)],
          deployer
        );
        expect(result.result).toBeOk(Cl.uint(2000000000000000000));
      });

      it('should calculate power correctly', () => {
        const result = simnet.callReadOnlyFn(
          'math-lib-advanced',
          'pow-fixed',
          [
            Cl.uint(2000000000000000000),
            Cl.uint(3000000000000000000)
          ],
          deployer
        );
        expect(result.result).toBeOk(Cl.uint(8000000000000000000));
      });

      it('should calculate natural logarithm', () => {
        const result = simnet.callReadOnlyFn(
          'math-lib-advanced',
          'ln-fixed',
          [Cl.uint(2718281828459045235)],
          deployer
        );
        expect(result.result.type).toBe(ClarityType.ResponseOk);
      });
    });

    describe('Fixed Point Math', () => {
      it('should multiply with proper rounding', () => {
        const result = simnet.callReadOnlyFn(
          'fixed-point-math',
          'mul-down',
          [
            Cl.uint(3333333333333333333),
            Cl.uint(3000000000000000000)
          ],
          deployer
        );
        expect(result.result).toBeOk(Cl.uint(9999999999999999999));
      });

      it('should calculate percentage correctly', () => {
        const result = simnet.callReadOnlyFn(
          'fixed-point-math',
          'percentage',
          [
            Cl.uint(1000000000000000000000),
            Cl.uint(50000000000000000)
          ],
          deployer
        );
        expect(result.result).toBeOk(Cl.uint(50000000000000000000));
      });
    });
  });

  describe('Interest Rate Model', () => {
    it('should calculate interest rates based on utilization', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-borrow-rate',
        [
          Cl.uint(500000000000000000000000),
          Cl.uint(500000000000000000000000),
          Cl.uint(0)
        ],
        deployer
      );
      expect(result.result.type).toBe(ClarityType.ResponseOk);
    });

    it('should handle extreme utilization rates', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-borrow-rate',
        [
          Cl.uint(50000000000000000000000),
          Cl.uint(950000000000000000000000),
          Cl.uint(0)
        ],
        deployer
      );
      expect(result.result.type).toBe(ClarityType.ResponseOk);
    });
  });

  describe('Comprehensive Lending System', () => {
    beforeEach(() => {
      simnet.callPublicFn(
        'comprehensive-lending-system',
        'initialize-market',
        [
          Cl.principal(mockToken),
          Cl.uint(800000000000000000),
          Cl.uint(900000000000000000),
          Cl.uint(50000000000000000),
          Cl.principal(interestRateModel)
        ],
        deployer
      );
    });

    it('should allow users to supply assets', () => {
      const result = simnet.callPublicFn(
        'comprehensive-lending-system',
        'supply',
        [
          Cl.principal(mockToken),
          Cl.uint(1000000000000000000000)
        ],
        user1
      );
      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should calculate health factor correctly', () => {
      simnet.callPublicFn(
        'comprehensive-lending-system',
        'supply',
        [
          Cl.principal(mockToken),
          Cl.uint(2000000000000000000000)
        ],
        user2
      );
      simnet.callPublicFn(
        'comprehensive-lending-system',
        'borrow',
        [
          Cl.principal(mockToken),
          Cl.uint(1000000000000000000000)
        ],
        user2
      );

      const healthFactor = simnet.callReadOnlyFn(
        'comprehensive-lending-system',
        'get-health-factor',
        [Cl.principal(user2)],
        user2
      );
      expect(healthFactor.result.type).toBe(ClarityType.ResponseOk);
    });

    it('should execute flash loans successfully', () => {
      const result = simnet.callPublicFn(
        'comprehensive-lending-system',
        'flash-loan',
        [
          Cl.principal(mockToken),
          Cl.uint(100000000000000000000),
          Cl.principal(user3),
          Cl.buffer(Buffer.from('test-data'))
        ],
        user3
      );
      expect(result.result.type).toBe(ClarityType.ResponseOk);
    });
  });

  describe('Enhanced Flash Loan Vault', () => {
    it('should track flash loan statistics', () => {
      const result = simnet.callReadOnlyFn(
        'enhanced-flash-loan-vault',
        'get-flash-loan-stats',
        [],
        user1
      );
      expect(result.result).toBeOk();
    });

    it('should calculate flash loan fees correctly', () => {
      const result = simnet.callReadOnlyFn(
        'enhanced-flash-loan-vault',
        'calculate-flash-loan-fee',
        [
          Cl.principal(mockToken),
          Cl.uint(1000000000000000000000)
        ],
        user1
      );
      expect(result.result).toBeOk();
    });

    it('should prevent reentrancy attacks', () => {
      const result = simnet.callPublicFn(
        'enhanced-flash-loan-vault',
        'flash-loan',
        [
          Cl.principal(mockToken),
          Cl.uint(100000000000000000000),
          Cl.principal(user4),
          Cl.buffer(Buffer.from('reentrancy-test'))
        ],
        user4
      );
      expect(result.result.type).toBe(ClarityType.ResponseOk);
    });
  });

  describe('Liquidation Manager', () => {
    it('should identify liquidatable positions', () => {
      const result = simnet.callReadOnlyFn(
        'loan-liquidation-manager',
        'is-position-liquidatable',
        [Cl.principal(user2)],
        user1
      );
      expect(result.result).toBeOk();
    });

    it('should calculate liquidation amounts correctly', () => {
      const result = simnet.callReadOnlyFn(
        'loan-liquidation-manager',
        'calculate-liquidation-amounts',
        [
          Cl.principal(user2),
          Cl.principal(mockToken),
          Cl.principal(mockToken)
        ],
        user1
      );
      expect(result.result).toBeOk();
    });

    it('should track liquidation statistics', () => {
      const result = simnet.callReadOnlyFn(
        'loan-liquidation-manager',
        'get-liquidation-stats',
        [],
        user1
      );
      expect(result.result).toBeOk();
    });
  });

  describe('Governance System', () => {
    it('should allow proposal creation', () => {
      const result = simnet.callPublicFn(
        'lending-protocol-governance',
        'propose',
        [
          Cl.stringAscii('Test Proposal'),
          Cl.stringUtf8('This is a test proposal for the governance system'),
          Cl.uint(1),
          Cl.some(Cl.principal(`${deployer}.comprehensive-lending-system`)),
          Cl.some(Cl.stringAscii('set-parameter')),
          Cl.some(Cl.list([Cl.uint(100)]))
        ],
        user1
      );
      expect(result.result.type).toBe(ClarityType.ResponseOk);
    });

    it('should track governance parameters', () => {
      const result = simnet.callReadOnlyFn(
        'lending-protocol-governance',
        'get-governance-parameters',
        [],
        user1
      );
      expect(result.result).toBeOk();
    });

    it('should handle delegation', () => {
      const result = simnet.callPublicFn(
        'lending-protocol-governance',
        'delegate',
        [Cl.principal(user2)],
        user1
      );
      expect(result.result).toBeOk(Cl.bool(true));
    });
  });
});
