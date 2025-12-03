import { describe, it, expect } from 'vitest';

describe('sanity', () => {
  it('should run', () => {
    expect(true).toBe(true);
  });
  it('should have simnet', () => {
    const simnet = (global as any).simnet;
    expect(simnet).toBeDefined();
  });
});
