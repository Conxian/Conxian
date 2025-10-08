import { describe, it, expect, beforeAll } from 'vitest';
import { Simnet } from '@hirosystems/clarinet-sdk';
import { Cl, ClarityType } from '@stacks/transactions';
import { createHash } from 'crypto';

describe('MEV Protector', () => {
  const simnet: Simnet = (global as any).simnet;
  let deployer: any;
  let wallet1: any;

  beforeAll(async () => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer');
    wallet1 = accounts.get('wallet_1');
  });

  it('commit returns id and premature reveal errors', async () => {
    // Prepare payload and commitment
    const payload = Buffer.from('test-order');
    const commitment = createHash('sha256').update(payload).digest(); // 32-byte hash

    const commit = await simnet.callPublicFn(
      'mev-protector',
      'commit-order',
      [Cl.buffer(commitment)],
      wallet1.address
    );

    expect(commit.result.type).toBe(ClarityType.ResponseOk);

    // Read batch id (sanity)
    const currentBatch = await simnet.callReadOnlyFn(
      'mev-protector',
      'get-current-batch-id',
      [],
      wallet1.address
    );
    expect(currentBatch.type).toBe(ClarityType.ResponseOk);

    // Immediate reveal should fail (commit window not elapsed)
    const reveal = await simnet.callPublicFn(
      'mev-protector',
      'reveal-order',
      [Cl.uint(0), Cl.buffer(payload)],
      wallet1.address
    );
    expect(reveal.result.type).toBe(ClarityType.ResponseError);
  });
});
