import { describe, it, expect, beforeAll } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { resolve } from 'path';

let simnet: any;

beforeAll(async () => {
  simnet = await initSimnet(resolve(__dirname, '../Clarinet.toml'));
});

describe('Simple Test', () => {
  it('should have access to the simnet object', () => {
    expect(simnet).toBeDefined();
  });
});
