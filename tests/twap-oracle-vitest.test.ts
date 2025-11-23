import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { Simnet, Tx } from '@stacks/clarinet-sdk';

describe('TWAP Oracle', () => {
  let simnet: Simnet;
  const deployer = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
  const wallet1 = 'ST3J2GVMMM2R07ZFBJDWTYEYAR8FZH5WKDTFJ9AHA';

  beforeAll(async () => {
    simnet = (global as any).simnet;
  });

  it('updates TWAP successfully', async () => {
    const block = await simnet.mineBlock([
      Tx.contractCall(
        'twap-oracle',
        'update-twap',
        [
          Cl.principal(wallet1),
          Cl.uint(3600),
          Cl.uint(1000)
        ],
        deployer
      ),
    ]);

    expect(block.receipts.length).toBe(1);
    expect(block.receipts[0].result).toBeOk(Cl.bool(true));
    
    // Check event was emitted
    const events = block.receipts[0].events;
    expect(events.some(e => e.data.event === "twap-updated")).toBe(true);

    // Verify TWAP value
    const twap = await simnet.readOnlyFn(
      'twap-oracle',
      'get-twap',
      [
        Cl.principal(wallet1),
        Cl.uint(3600)
      ],
      deployer
    );
    expect(twap.result).toBeOk(Cl.uint(1000));
  });

  it('fails unauthorized TWAP update', async () => {
    const block = await simnet.mineBlock([
      Tx.contractCall(
        'twap-oracle',
        'update-twap',
        [
          Cl.principal(wallet1),
          Cl.uint(3600),
          Cl.uint(1000)
        ],
        wallet1 // Not authorized
      ),
    ]);

    expect(block.receipts.length).toBe(1);
    expect(block.receipts[0].result).toBeErr(Cl.uint(1100)); // ERR_UNAUTHORIZED
  });

  it('handles edge cases correctly', async () => {
    // Test with zero period
    const block = await simnet.mineBlock([
      Tx.contractCall(
        'twap-oracle',
        'update-twap',
        [
          Cl.principal(wallet1),
          Cl.uint(0), // Invalid period
          Cl.uint(1000)
        ],
        deployer
      ),
    ]);

    expect(block.receipts[0].result).toBeErr(); // Should fail with some error
  });
});
