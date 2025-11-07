import { describe, it, expect, beforeAll } from 'vitest';
import { Simnet } from '@stacks/clarinet-sdk';
import { Cl, ClarityType } from '@stacks/transactions';

function hexToBytes(hex: string): Uint8Array {
  if (hex.startsWith('0x')) hex = hex.slice(2);
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(hex.substr(i * 2, 2), 16);
  }
  return bytes;
}

describe('BTC Adapter', () => {
  const simnet: Simnet = (global as any).simnet;
  let deployer: any;
  let wallet1: any;

  beforeAll(async () => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer');
    wallet1 = accounts.get('wallet_1');
  });

  it('registers and confirms a BTC deposit', async () => {
    const txId = hexToBytes('0x' + '11'.repeat(32));
    const amount = 1000;

    const reg = await simnet.callPublicFn(
      'btc-adapter',
      'register-btc-deposit',
      [Cl.buffer(txId), Cl.principal(wallet1.address), Cl.uint(amount)],
      deployer.address
    );
    expect(reg.result.type).toBe(ClarityType.ResponseOk);

    const status1 = await simnet.callReadOnlyFn(
      'btc-adapter',
      'get-btc-deposit-status',
      [Cl.buffer(txId)],
      wallet1.address
    );
    expect(status1.type).toBe(ClarityType.ResponseOk);

    const conf = await simnet.callPublicFn(
      'btc-adapter',
      'confirm-btc-deposit',
      [Cl.buffer(txId)],
      deployer.address
    );
    expect(conf.result.type).toBe(ClarityType.ResponseOk);
  });
});
