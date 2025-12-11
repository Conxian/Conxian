
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
    const crypto = require('crypto');
    const salt = Buffer.from('0102030405060708090a0b0c0d0e0f10', 'hex'); // 16 bytes

    // Define order parameters
    const tokenIn = Cl.contractPrincipal(deployer, 'cxd-token');
    const tokenOut = Cl.contractPrincipal(deployer, 'cxs-token');
    const amountIn = Cl.uint(1000);
    const minOut = Cl.uint(900);

    // Construct the tuple as expected by Clarity for hashing
    // Note: Contract currently uses salt-only hashing due to Clarity version constraints.
    // const orderTuple = Cl.tuple({ ... });
    
    // Serialize and Hash
    // const serialized = Cl.serialize(orderTuple);
    // const hash = crypto.createHash('sha256').update(serialized).digest();
    
    // Hash salt only
    const hash = crypto.createHash('sha256').update(salt).digest();

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
      [
        Cl.uint(0),
        tokenIn, // token-in-trait
        tokenOut, // token-out
        amountIn, // amount-in
        minOut, // min-out
        Cl.buffer(salt) // salt
      ],
      wallet1
    );
    expect(revealResult.result).toBeOk(Cl.uint(0)); // Batch ID 0

    // 4. Advance to End of Batch (another 10 blocks)
    // Batch 0 ends at block 20. Current is ~11.
    simnet.mineEmptyBlocks(10);

    // 5. Execute Batch
    const executeResult = simnet.callPublicFn(
      'mev-protector',
      'execute-order-in-batch',
      [
        Cl.uint(0), // batch-id
        Cl.uint(0), // order-index
        Cl.contractPrincipal(deployer, 'mock-pool'),
        tokenIn,
        tokenOut,
        Cl.contractPrincipal(deployer, 'oracle')
      ],
      deployer // Owner
    );
    // Since mock-pool swaps 1:1, amount-out should be 1000.
    // Oracle price check should pass (1:1).
    expect(executeResult.result).toBeOk(Cl.uint(1000));
  });
});
