import { describe, it, expect } from 'vitest';
import { PERFORMANCE_BENCHMARKS, LOAD_PROFILES, GAP_ANALYSIS_AREAS } from './performance-benchmarks';

function inRange(n: number, min: number, max: number) {
  return typeof n === 'number' && n >= min && n <= max;
}

describe('Multi-dimensional performance benchmarks (dimension 10^k)', () => {
  it('benchmarks have valid shapes and thresholds', () => {
    expect(Array.isArray(PERFORMANCE_BENCHMARKS)).toBe(true);
    for (const b of PERFORMANCE_BENCHMARKS) {
      expect(typeof b.component).toBe('string');
      expect(typeof b.operation).toBe('string');
      expect(b.expectedTPS).toBeGreaterThan(0);
      expect(b.maxLatencyMs).toBeGreaterThan(0);
      expect(inRange(b.maxErrorRate, 0, 1)).toBe(true);
      expect(b.maxGasUsage).toBeGreaterThan(0);
      const t = b.criticalThresholds;
      expect(inRange(t.warningLevel, 0, 1)).toBe(true);
      expect(inRange(t.errorLevel, 0, 1)).toBe(true);
      expect(inRange(t.criticalLevel, 0, 1)).toBe(true);
      // Ensure ordering critical <= error <= warning (stricter as load worsens)
      expect(t.criticalLevel <= t.errorLevel && t.errorLevel <= t.warningLevel).toBe(true);
    }
  });

  it('load profiles cover dimensions 0..5 with sane resource limits', () => {
    expect(Array.isArray(LOAD_PROFILES)).toBe(true);
    for (const p of LOAD_PROFILES) {
      expect(inRange(p.dimension, 0, 5)).toBe(true);
      expect(p.totalTransactions).toBeGreaterThan(0);
      expect(p.concurrentUsers).toBeGreaterThan(0);
      expect(p.expectedSystemTPS).toBeGreaterThan(0);
      const r = p.resourceLimits;
      expect(r.maxMemoryMB).toBeGreaterThan(0);
      expect(r.maxGasPerBlock).toBeGreaterThan(0);
      expect(r.maxStorageMB).toBeGreaterThan(0);
      const mix = Object.values(p.transactionMix || {});
      expect(mix.length).toBeGreaterThan(0);
      const sum = mix.reduce((a, b) => a + b, 0);
      expect(sum).toBeGreaterThan(0);
      expect(sum).toBeLessThanOrEqual(100);
    }
  });

  it('gap analysis entries are scoped to valid dimensions and risk levels', () => {
    const risks = new Set(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']);
    for (const g of GAP_ANALYSIS_AREAS) {
      expect(risks.has(g.riskLevel)).toBe(true);
      expect(Array.isArray(g.testAreas) && g.testAreas.length > 0).toBe(true);
      expect(Array.isArray(g.applicableDimensions)).toBe(true);
      for (const d of g.applicableDimensions) expect(inRange(d, 0, 5)).toBe(true);
      expect(Array.isArray(g.mitigationStrategies) && g.mitigationStrategies.length > 0).toBe(true);
    }
  });
});
