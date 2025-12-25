import { initSimnet } from '@stacks/clarinet-sdk';
import { resolve } from 'path';

module.exports = async () => {
  const simnet = await initSimnet(resolve(__dirname, '../Clarinet.toml'));
  globalThis.simnet = simnet;
};
