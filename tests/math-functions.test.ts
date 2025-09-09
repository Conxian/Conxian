import { describe, expect, it, beforeEach } from '@jest/globals';
import { Cl } from '@stacks/transactions';

// Test suite for comprehensive mathematical function validation
describe('Conxian Mathematical Functions Tests', () => {
  let deployer: string;
  let mathLibContract: string;
  let fixedPointContract: string;
  let precisionCalculatorContract: string;

  beforeEach(() => {
    deployer = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    mathLibContract = `${deployer}.math-lib-advanced`;
    fixedPointContract = `${deployer}.fixed-point-math`;
    precisionCalculatorContract = `${deployer}.precision-calculator`;
  });

  describe('Square Root Function Tests', () => {
    const testCases = [
      { input: 0, expected: 0, description: 'sqrt(0) = 0' },
      { input: 1000000000000000000, expected: 1000000000000000000, description: 'sqrt(1) = 1' },
      { input: 4000000000000000000, expected: 2000000000000000000, description: 'sqrt(4) = 2' },
      { input: 9000000000000000000, expected: 3000000000000000000, description: 'sqrt(9) = 3' },
      { input: 16000000000000000000, expected: 4000000000000000000, description: 'sqrt(16) = 4' },
      { input: 25000000000000000000, expected: 5000000000000000000, description: 'sqrt(25) = 5' },
      { input: 2000000000000000000, expected: 1414213562373095048, description: 'sqrt(2) ≈ 1.414' },
      { input: 3000000000000000000, expected: 1732050807568877293, description: 'sqrt(3) ≈ 1.732' },
      { input: 5000000000000000000, expected: 2236067977499789696, description: 'sqrt(5) ≈ 2.236' },
      { input: 10000000000000000000, expected: 3162277660168379332, description: 'sqrt(10) ≈ 3.162' }
    ];

    testCases.forEach(({ input, expected, description }) => {
      it(`should calculate ${description}`, async () => {
        const result = simnet.callReadOnlyFn(
          mathLibContract,
          'sqrt-fixed',
          [Cl.uint(input)],
          deployer
        );

        expect(result.result).toBeOk();
        const actualValue = result.result.expectOk().expectUint();
        
        // Allow for 0.01% precision tolerance
        const tolerance = Math.floor(expected * 0.0001);
        expect(Math.abs(Number(actualValue) - expected)).toBeLessThanOrEqual(tolerance);

        // Test precision validation
        const precisionCheck = simnet.callPublicFn(
          precisionCalculatorContract,
          'detect-precision-loss',
          [
            Cl.stringAscii('sqrt'),
            Cl.uint(input),
            Cl.uint(0),
            Cl.uint(expected),
            Cl.uint(actualValue)
          ],
          deployer
        );

        expect(precisionCheck.result).toBeOk();
      });
    });

    it('should handle edge cases gracefully', async () => {
      // Test maximum uint value
      const maxUint = '340282366920938463463374607431768211455';
      const result = simnet.callReadOnlyFn(
        mathLibContract,
        'sqrt-fixed',
        [Cl.uint(maxUint)],
        deployer
      );

      // Should either succeed or return appropriate error
      if (result.result.isOk) {
        expect(result.result.expectOk()).toBeDefined();
      } else {
        expect(result.result.expectErr()).toBeUint();
      }
    });

    it('should validate input ranges', async () => {
      const validationResult = simnet.callPublicFn(
        precisionCalculatorContract,
        'validate-input-range',
        [
          Cl.stringAscii('sqrt'),
          Cl.uint(1000000000000000000),
          Cl.uint(0),
          Cl.uint('340282366920938463463374607431768211455')
        ],
        deployer
      );

      expect(validationResult.result).toBeOk();
    });
  });

  describe('Power Function Tests', () => {
    const testCases = [
      { base: 2000000000000000000, exp: 0, expected: 1000000000000000000, description: '2^0 = 1' },
      { base: 2000000000000000000, exp: 1000000000000000000, expected: 2000000000000000000, description: '2^1 = 2' },
      { base: 2000000000000000000, exp: 2000000000000000000, expected: 4000000000000000000, description: '2^2 = 4' },
      { base: 2000000000000000000, exp: 3000000000000000000, expected: 8000000000000000000, description: '2^3 = 8' },
      { base: 3000000000000000000, exp: 2000000000000000000, expected: 9000000000000000000, description: '3^2 = 9' },
      { base: 5000000000000000000, exp: 2000000000000000000, expected: 25000000000000000000, description: '5^2 = 25' },
      { base: 10000000000000000000, exp: 2000000000000000000, expected: 100000000000000000000, description: '10^2 = 100' }
    ];

    testCases.forEach(({ base, exp, expected, description }) => {
      it(`should calculate ${description}`, async () => {
        const result = simnet.callReadOnlyFn(
          mathLibContract,
          'pow-fixed',
          [Cl.uint(base), Cl.uint(exp)],
          deployer
        );

        expect(result.result).toBeOk();
        const actualValue = result.result.expectOk().expectUint();
        
        // Allow for 0.01% precision tolerance
        const tolerance = Math.floor(expected * 0.0001);
        expect(Math.abs(Number(actualValue) - expected)).toBeLessThanOrEqual(tolerance);

        // Run benchmark test
        const benchmarkResult = simnet.callPublicFn(
          precisionCalculatorContract,
          'run-pow-benchmark',
          [Cl.uint(base), Cl.uint(exp), Cl.uint(expected)],
          deployer
        );

        expect(benchmarkResult.result).toBeOk();
        const benchmark = benchmarkResult.result.expectOk().expectTuple();
        expect(benchmark['passed']).toBeBool(true);
      });
    });

    it('should handle fractional exponents', async () => {
      // Test 4^0.5 = 2 (square root)
      const result = simnet.callReadOnlyFn(
        mathLibContract,
        'pow-fixed',
        [Cl.uint(4000000000000000000), Cl.uint(500000000000000000)], // 4^0.5
        deployer
      );

      expect(result.result).toBeOk();
      const actualValue = result.result.expectOk().expectUint();
      const expected = 2000000000000000000; // 2.0
      const tolerance = Math.floor(expected * 0.001); // 0.1% tolerance for fractional powers
      
      expect(Math.abs(Number(actualValue) - expected)).toBeLessThanOrEqual(tolerance);
    });
  });

  describe('Natural Logarithm Function Tests', () => {
    const testCases = [
      { input: 1000000000000000000, expected: 0, description: 'ln(1) = 0' },
      { input: 2718281828459045235, expected: 1000000000000000000, description: 'ln(e) = 1' },
      { input: 7389056098930650227, expected: 2000000000000000000, description: 'ln(e²) = 2' },
      { input: 2000000000000000000, expected: 693147180559945309, description: 'ln(2) ≈ 0.693' },
      { input: 10000000000000000000, expected: 2302585092994045684, description: 'ln(10) ≈ 2.303' }
    ];

    testCases.forEach(({ input, expected, description }) => {
      it(`should calculate ${description}`, async () => {
        const result = simnet.callReadOnlyFn(
          mathLibContract,
          'ln-fixed',
          [Cl.uint(input)],
          deployer
        );

        expect(result.result).toBeOk();
        const actualValue = result.result.expectOk().expectUint();
        
        // Allow for 0.1% precision tolerance for ln function
        const tolerance = Math.max(Math.floor(Math.abs(expected) * 0.001), 1000000000000000); // min 0.001
        expect(Math.abs(Number(actualValue) - expected)).toBeLessThanOrEqual(tolerance);
      });
    });

    it('should reject invalid inputs', async () => {
      // Test ln(0) - should return error
      const result = simnet.callReadOnlyFn(
        mathLibContract,
        'ln-fixed',
        [Cl.uint(0)],
        deployer
      );

      expect(result.result).toBeErr();
    });
  });

  describe('Exponential Function Tests', () => {
    const testCases = [
      { input: 0, expected: 1000000000000000000, description: 'exp(0) = 1' },
      { input: 1000000000000000000, expected: 2718281828459045235, description: 'exp(1) = e' },
      { input: 2000000000000000000, expected: 7389056098930650227, description: 'exp(2) = e²' },
      { input: 693147180559945309, expected: 2000000000000000000, description: 'exp(ln(2)) = 2' },
      { input: 2302585092994045684, expected: 10000000000000000000, description: 'exp(ln(10)) = 10' }
    ];

    testCases.forEach(({ input, expected, description }) => {
      it(`should calculate ${description}`, async () => {
        const result = simnet.callReadOnlyFn(
          mathLibContract,
          'exp-fixed',
          [Cl.uint(input)],
          deployer
        );

        expect(result.result).toBeOk();
        const actualValue = result.result.expectOk().expectUint();
        
        // Allow for 0.1% precision tolerance for exp function
        const tolerance = Math.floor(expected * 0.001);
        expect(Math.abs(Number(actualValue) - expected)).toBeLessThanOrEqual(tolerance);
      });
    });

    it('should handle large inputs gracefully', async () => {
      // Test exp(20) - should either succeed or return overflow error
      const result = simnet.callReadOnlyFn(
        mathLibContract,
        'exp-fixed',
        [Cl.uint(20000000000000000000)],
        deployer
      );

      // Should either succeed or return appropriate overflow error
      if (result.result.isOk) {
        expect(result.result.expectOk()).toBeDefined();
      } else {
        expect(result.result.expectErr()).toBeUint();
      }
    });
  });

  describe('Fixed-Point Math Operations Tests', () => {
    it('should perform precise multiplication', async () => {
      const result = simnet.callReadOnlyFn(
        fixedPointContract,
        'mul-down',
        [Cl.uint(1500000000000000000), Cl.uint(2000000000000000000)], // 1.5 * 2.0 = 3.0
        deployer
      );

      expect(result.result).toBeOk();
      const actualValue = result.result.expectOk().expectUint();
      expect(actualValue).toBe(3000000000000000000n);
    });

    it('should perform precise division', async () => {
      const result = simnet.callReadOnlyFn(
        fixedPointContract,
        'div-down',
        [Cl.uint(6000000000000000000), Cl.uint(2000000000000000000)], // 6.0 / 2.0 = 3.0
        deployer
      );

      expect(result.result).toBeOk();
      const actualValue = result.result.expectOk().expectUint();
      expect(actualValue).toBe(3000000000000000000n);
    });

    it('should handle rounding correctly', async () => {
      // Test floor function
      const floorResult = simnet.callReadOnlyFn(
        fixedPointContract,
        'floor-fixed',
        [Cl.uint(1750000000000000000)], // 1.75 -> 1.0
        deployer
      );

      expect(floorResult.result).toBeOk();
      expect(floorResult.result.expectOk().expectUint()).toBe(1000000000000000000n);

      // Test ceil function
      const ceilResult = simnet.callReadOnlyFn(
        fixedPointContract,
        'ceil-fixed',
        [Cl.uint(1250000000000000000)], // 1.25 -> 2.0
        deployer
      );

      expect(ceilResult.result).toBeOk();
      expect(ceilResult.result.expectOk().expectUint()).toBe(2000000000000000000n);
    });
  });

  describe('Precision and Performance Tests', () => {
    it('should track precision loss accurately', async () => {
      const result = simnet.callPublicFn(
        precisionCalculatorContract,
        'detect-precision-loss',
        [
          Cl.stringAscii('test-op'),
          Cl.uint(1000000000000000000),
          Cl.uint(2000000000000000000),
          Cl.uint(3000000000000000000), // expected
          Cl.uint(3000100000000000000)  // actual (slight loss)
        ],
        deployer
      );

      expect(result.result).toBeOk();
      const metrics = result.result.expectOk().expectTuple();
      expect(metrics['within-threshold']).toBeBool(true);
      expect(Number(metrics['precision-loss'])).toBe(100000000000000);
    });

    it('should validate mathematical constants', async () => {
      const result = simnet.callPublicFn(
        precisionCalculatorContract,
        'validate-mathematical-constants',
        [],
        deployer
      );

      expect(result.result).toBeOk();
      const constants = result.result.expectOk().expectTuple();
      expect(constants['pi-valid']).toBeBool(true);
      expect(constants['e-valid']).toBeBool(true);
      expect(constants['ln2-valid']).toBeBool(true);
    });

    it('should track error accumulation in complex calculations', async () => {
      const operations = [
        Cl.stringAscii('sqrt'),
        Cl.stringAscii('pow'),
        Cl.stringAscii('ln'),
        Cl.stringAscii('exp')
      ];
      
      const intermediateResults = [
        Cl.uint(1414213562373095048), // sqrt(2)
        Cl.uint(2000000000000000000), // 2^1
        Cl.uint(693147180559945309),  // ln(2)
        Cl.uint(2000000000000000000)  // exp(ln(2))
      ];

      const result = simnet.callPublicFn(
        precisionCalculatorContract,
        'track-error-accumulation',
        [
          Cl.list(operations),
          Cl.list(intermediateResults),
          Cl.uint(2000000000000000000), // expected final result
          Cl.uint(2000050000000000000)  // actual final result
        ],
        deployer
      );

      expect(result.result).toBeOk();
      const tracking = result.result.expectOk().expectTuple();
      expect(tracking['error-within-threshold']).toBeBool(true);
    });

    it('should profile operation performance', async () => {
      const result = simnet.callPublicFn(
        precisionCalculatorContract,
        'profile-operation-performance',
        [
          Cl.stringAscii('sqrt'),
          Cl.uint(50), // execution time
          Cl.uint(1000000000000000000) // input size
        ],
        deployer
      );

      expect(result.result).toBeOk();
      const profile = result.result.expectOk().expectTuple();
      expect(profile['within-threshold']).toBeBool(true);
    });

    it('should provide precision statistics', async () => {
      // First, run some operations to generate stats
      await simnet.callPublicFn(
        precisionCalculatorContract,
        'detect-precision-loss',
        [
          Cl.stringAscii('test'),
          Cl.uint(1000000000000000000),
          Cl.uint(0),
          Cl.uint(2000000000000000000),
          Cl.uint(2000010000000000000)
        ],
        deployer
      );

      const stats = simnet.callReadOnlyFn(
        precisionCalculatorContract,
        'get-precision-stats',
        [],
        deployer
      );

      expect(stats.result).toBeTuple();
      const statsData = stats.result.expectTuple();
      expect(Number(statsData['total-operations'])).toBeGreaterThan(0);
    });
  });

  describe('Edge Cases and Error Handling', () => {
    it('should handle zero inputs appropriately', async () => {
      // Test sqrt(0)
      const sqrtZero = simnet.callReadOnlyFn(
        mathLibContract,
        'sqrt-fixed',
        [Cl.uint(0)],
        deployer
      );
      expect(sqrtZero.result).toBeOk();
      expect(sqrtZero.result.expectOk().expectUint()).toBe(0n);

      // Test ln(0) - should error
      const lnZero = simnet.callReadOnlyFn(
        mathLibContract,
        'ln-fixed',
        [Cl.uint(0)],
        deployer
      );
      expect(lnZero.result).toBeErr();
    });

    it('should handle maximum values', async () => {
      const maxValue = '340282366920938463463374607431768211455';
      
      // Test operations with maximum values
      const sqrtMax = simnet.callReadOnlyFn(
        mathLibContract,
        'sqrt-fixed',
        [Cl.uint(maxValue)],
        deployer
      );

      // Should either succeed or return appropriate overflow error
      if (sqrtMax.result.isOk) {
        expect(sqrtMax.result.expectOk()).toBeDefined();
      } else {
        expect(sqrtMax.result.expectErr()).toBeUint();
      }
    });

    it('should detect precision loss exceeding thresholds', async () => {
      const result = simnet.callPublicFn(
        precisionCalculatorContract,
        'detect-precision-loss',
        [
          Cl.stringAscii('test-op'),
          Cl.uint(1000000000000000000),
          Cl.uint(0),
          Cl.uint(1000000000000000000), // expected
          Cl.uint(1020000000000000000)  // actual (2% loss - exceeds threshold)
        ],
        deployer
      );

      expect(result.result).toBeErr();
      expect(result.result.expectErr()).toBeUint(1004); // ERR_PRECISION_LOSS_EXCEEDED
    });
  });

  describe('Integration Tests', () => {
    it('should work together for complex DeFi calculations', async () => {
      // Simulate a liquidity calculation: sqrt(x * y) for constant product
      const tokenX = 1000000000000000000000; // 1000 tokens
      const tokenY = 2000000000000000000000; // 2000 tokens
      
      // Calculate product
      const product = simnet.callReadOnlyFn(
        fixedPointContract,
        'mul-down',
        [Cl.uint(tokenX), Cl.uint(tokenY)],
        deployer
      );

      expect(product.result).toBeOk();
      const productValue = product.result.expectOk().expectUint();

      // Calculate square root of product (geometric mean)
      const liquidity = simnet.callReadOnlyFn(
        mathLibContract,
        'sqrt-fixed',
        [Cl.uint(productValue)],
        deployer
      );

      expect(liquidity.result).toBeOk();
      const liquidityValue = liquidity.result.expectOk().expectUint();
      
      // Expected: sqrt(1000 * 2000) = sqrt(2,000,000) ≈ 1414.21
      const expected = 1414213562373095048000; // scaled by 10^18
      const tolerance = Math.floor(expected * 0.001); // 0.1% tolerance
      
      expect(Math.abs(Number(liquidityValue) - expected)).toBeLessThanOrEqual(tolerance);
    });

    it('should handle weighted pool calculations', async () => {
      // Simulate weighted pool invariant: (x/w1)^w1 * (y/w2)^w2
      const tokenX = 1000000000000000000000; // 1000 tokens
      const tokenY = 500000000000000000000;  // 500 tokens
      const weightX = 800000000000000000;    // 0.8 (80%)
      const weightY = 200000000000000000;    // 0.2 (20%)

      // Calculate (x/w1)^w1
      const xOverW1 = simnet.callReadOnlyFn(
        fixedPointContract,
        'div-down',
        [Cl.uint(tokenX), Cl.uint(weightX)],
        deployer
      );

      expect(xOverW1.result).toBeOk();

      const xPowW1 = simnet.callReadOnlyFn(
        mathLibContract,
        'pow-fixed',
        [Cl.uint(xOverW1.result.expectOk().expectUint()), Cl.uint(weightX)],
        deployer
      );

      expect(xPowW1.result).toBeOk();

      // This demonstrates the mathematical functions working together
      // for complex DeFi calculations
    });
  });
});