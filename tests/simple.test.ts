import { describe, it, expect } from 'vitest';

describe('Simple Test', () => {
  it('should have access to the simnet object', () => {
    expect(globalThis.simnet).toBeDefined();
  });
});
