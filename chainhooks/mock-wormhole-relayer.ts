// mock-wormhole-relayer.ts
// Minimal stub to simulate relaying a VAA-like message into the simnet.

import { initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

export async function relayMessage(msgId: Buffer, guardianIndex: number, payload: Buffer) {
  const simnet = await initSimnet();
  const accounts = simnet.getAccounts();
  const deployer = accounts.get('deployer')!;

  simnet.callPublicFn('interop-wormhole-inbox', 'set-guardian-set-index', [Cl.uint(guardianIndex)], deployer);
  return simnet.callPublicFn(
    'interop-wormhole-inbox',
    'receive-message',
    [Cl.buff(msgId), Cl.uint(guardianIndex), Cl.buff(payload)],
    deployer
  );
}