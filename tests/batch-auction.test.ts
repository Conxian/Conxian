import { describe, it, expect, beforeAll } from 'vitest';
import { Simnet } from '@hirosystems/clarinet-sdk';
import { Cl, ClarityType } from '@stacks/transactions';

describe('Batch Auction', () => {
  const simnet: Simnet = (global as any).simnet;
  let deployer: any;
  let wallet1: any;

  beforeAll(async () => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer');
    wallet1 = accounts.get('wallet_1');
  });

  it('creates auction and accepts bids during active window', async () => {
    // create-auction(asset-to-sell principal, amount-to-sell uint, duration-blocks uint)
    const create = await simnet.callPublicFn(
      'batch-auction',
      'create-auction',
      [Cl.principal(deployer.address), Cl.uint(1_000_000), Cl.uint(10)],
      deployer.address
    );
    expect(create.result.type).toBe(ClarityType.ResponseOk);

    const auctionId = 0; // first id

    const bid = await simnet.callPublicFn(
      'batch-auction',
      'place-bid',
      [Cl.uint(auctionId), Cl.uint(50_000), Cl.uint(100)],
      wallet1.address
    );
    expect(bid.result.type).toBe(ClarityType.ResponseOk);
  });
});
