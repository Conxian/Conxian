import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from '@stacks/clarinet-sdk';

/**
 * Wormhole Inbox/Outbox Interop Tests
 */
describe('Wormhole Interoperability', () => {
  let simnet: any;
  let accounts: Map<string, string>;
  let deployer: string;

  beforeAll(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('receives a message with guardian-set validation and idempotency', async () => {
    const setGuardian = simnet.callPublicFn(
      'interop-wormhole-inbox',
      'set-guardian-set-index',
      [Cl.uint(1)],
      deployer
    );
    expect(setGuardian.result).toBeOk(Cl.bool(true));

    const msgId = Buffer.alloc(32, 1); // dummy id of 32 bytes
    const payload = Buffer.from('governance-update');

    const first = simnet.callPublicFn(
      'interop-wormhole-inbox',
      'receive-message',
      [Cl.buffer(msgId), Cl.uint(1), Cl.buffer(payload)],
      deployer
    );
    expect(first.result).toBeOk(Cl.bool(true));

    const replay = simnet.callPublicFn(
      'interop-wormhole-inbox',
      'receive-message',
      [Cl.buffer(msgId), Cl.uint(1), Cl.buffer(payload)],
      deployer
    );
    expect(replay.result).toBeErr(Cl.uint(93002));
  });

  it('emits an outbound intent and returns intent id', async () => {
    const destAddr = Buffer.alloc(32, 2);
    const payload = Buffer.from('intent-payload');

    const intent = simnet.callPublicFn(
      'interop-wormhole-outbox',
      'emit-intent',
      [Cl.stringAscii('ETH'), Cl.buffer(destAddr), Cl.buffer(payload)],
      deployer
    );
    expect(intent.result).toBeOk(Cl.uint(1));
    const idCV = intent.result.value;

    const got = simnet.callReadOnlyFn(
      'interop-wormhole-outbox',
      'get-intent',
      [idCV],
      deployer
    );
    expect(got.result.value).toBeDefined();
  });

  it('handles governance and PoR attestation via stubs', async () => {
    const gov = simnet.callPublicFn(
      'interop-wormhole-handlers',
      'handle-governance',
      [Cl.buffer(Buffer.from('set-param:x=42'))],
      deployer
    );
    expect(gov.result).toBeOk(Cl.bool(true));

    const por = simnet.callPublicFn(
      'interop-wormhole-handlers',
      'handle-por-attestation',
      [Cl.buffer(Buffer.alloc(32, 3)), Cl.buffer(Buffer.alloc(32, 4))],
      deployer
    );
    expect(por.result).toBeOk(Cl.bool(true));
  });
});