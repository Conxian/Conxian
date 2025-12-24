import { describe, it, expect, beforeAll } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { resolve } from 'path';

let simnet: any;

beforeAll(async () => {
  simnet = await initSimnet(resolve(__dirname, '../Clarinet.lending.toml'));
});

describe('Isolated Lending Contract Test', () => {
  it('should successfully deploy the comprehensive-lending-system contract', () => {
    const contractSource = simnet.getContractSource('comprehensive-lending-system');
    expect(contractSource).toBeDefined();
  });
});
