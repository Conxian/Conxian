import { describe, it, expect, beforeAll } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { resolve } from 'path';

let simnet: any;

beforeAll(async () => {
  simnet = await initSimnet(resolve(__dirname, '../Clarinet.minimal.toml'));
});

describe('Single Contract Compilation Test', () => {
  it('should successfully deploy the ownable contract', () => {
    const contractSource = simnet.getContractSource('ownable');
    expect(contractSource).toBeDefined();
  });
});
