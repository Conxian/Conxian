
import { describe, it, expect, beforeEach } from 'vitest';
import { initSimnet } from '@hirosystems/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('MEV Protector', () => {
  let simnet: any;
  let accounts: any;
  let deployer: string;
  let wallet1: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();

    if (accounts.has('deployer')) {
      deployer = accounts.get('deployer');
    } else {
      deployer = "ST3N0ZC9HBPDEBEJ1H1QFGMJF3PSNGW3FYZSVN513";
    }

    if (accounts.has('wallet_1')) {
      wallet1 = accounts.get('wallet_1');
    } else {
      wallet1 = "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5";
    }
  });

  it('allows committing an order', () => {
    const hash = '0x' + '0'.repeat(64);
    const result = simnet.callPublicFn(
      'mev-protector',
      'commit-order',
      [Cl.bufferFromHex(hash)],
      wallet1
    );
    expect(result.result).toBeOk(Cl.uint(0));
  });

  it('prevents early reveal', () => {
    const hash = '0x' + '0'.repeat(64); // Dummy hash
    simnet.callPublicFn('mev-protector', 'commit-order', [Cl.bufferFromHex(hash)], wallet1);

    // Try to reveal immediately
    const result = simnet.callPublicFn(
      'mev-protector',
      'reveal-order',
      [Cl.uint(0), Cl.bufferFromHex('0x' + '0'.repeat(256))], // Dummy payload
      wallet1
    );

    expect(result.result).toBeErr(Cl.uint(4002)); // ERR_REVEAL_PERIOD_ENDED (actually wait period hasn't ended)
  });

  it('completes full batch lifecycle', () => {
    const payload = Cl.bufferFromHex('0x' + '0'.repeat(256));
    // Calculate hash of payload (mocking sha256 behavior if needed, or using known hash)
    // Since we can't easily do sha256 in JS that matches Clarity exactly without library, 
    // we rely on the fact that the contract checks (sha256 payload) == commitment.
    // However, in simnet, we might need to actually generate the hash.
    // For now, let's assume we can use a dummy hash and just check the flow logic, 
    // BUT the contract enforces `(is-eq (sha256 payload) hash)`.
    // So we need a valid hash.
    // We can use a simpler payload like 0x01

    // In this environment, we might not have a sha256 lib handy. 
    // We can use `simnet.runSnippet` or similar if available, or just skip the hash check by mocking? No, contract is real.
    // Let's use a known hash for 0x00...00 (32 bytes)
    // SHA256(0x00...00 32 bytes) = ...
    // Actually, let's just use a simple payload and pre-calculate hash if possible.
    // Or, we can use the `sha256` function from `@stacks/encryption` or node crypto if available.
    // Since we are in `vitest` with node env, we can use `crypto`.

    const crypto = require('crypto');
    const payloadHex = '01020304';
    const payloadBuffer = Buffer.from(payloadHex, 'hex');
    const hash = crypto.createHash('sha256').update(payloadBuffer).digest();

    // 1. Commit
    const commitResult = simnet.callPublicFn(
      'mev-protector',
      'commit-order',
      [Cl.buffer(hash)],
      wallet1
    );
    expect(commitResult.result).toBeOk(Cl.uint(0)); // Commitment ID 0

    // 2. Advance to Reveal Period (10 blocks)
    simnet.mineEmptyBlocks(10);

    // 3. Reveal
    const revealResult = simnet.callPublicFn(
      'mev-protector',
      'reveal-order',
      [Cl.uint(0), Cl.buffer(payloadBuffer)],
      wallet1
    );
    expect(revealResult.result).toBeOk(Cl.uint(0)); // Batch ID 0

    // 4. Advance to End of Batch (another 10 blocks)
    // Batch 0 ends at block 20. Current is ~11.
    simnet.mineEmptyBlocks(10);

    // 5. Execute Batch
    const executeResult = simnet.callPublicFn(
      'mev-protector',
      'execute-batch',
      [Cl.uint(0)],
      deployer // Owner
    );
    expect(executeResult.result).toBeOk(Cl.bool(true));
  });
});
