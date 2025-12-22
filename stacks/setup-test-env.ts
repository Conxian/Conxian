// stacks/setup-test-env.ts
import { Simnet } from '@stacks/clarinet-sdk';
import { resolve } from 'path';

const manifestPath = resolve(__dirname, '../Clarinet.toml');

const simnet = new Simnet({
  manifestPath: manifestPath,
  defaultSender: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
});

globalThis.simnet = simnet;
