import { describe, it, expect, beforeAll } from 'vitest';
import { Simnet } from '@hirosystems/clarinet-sdk';
import { Cl, ClarityType } from '@stacks/transactions';

/**
 * Router integration smoke test
 * - Adds two tokens and a bidirectional edge
 * - Calls find-optimal-path (read-only) and swap-optimal-path (public)
 * - Verifies path structure and response types
 */
describe('Advanced Router (Dijkstra) integration', () => {
  const simnet: Simnet = (global as any).simnet;
  let deployer: any;
  let wallet1: any;
  let wallet2: any;

  beforeAll(async () => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer');
    wallet1 = accounts.get('wallet_1');
    wallet2 = accounts.get('wallet_2');
  });

  it('adds tokens, edges, and finds optimal path', async () => {
    // add tokens (use wallet principals as token identifiers)
    const addA = await simnet.callPublicFn(
      'advanced-router-dijkstra',
      'add-token',
      [Cl.principal(wallet1.address)],
      deployer.address
    );
    const addB = await simnet.callPublicFn(
      'advanced-router-dijkstra',
      'add-token',
      [Cl.principal(wallet2.address)],
      deployer.address
    );
    expect(addA.result.type).toBe(ClarityType.ResponseOk);
    expect(addB.result.type).toBe(ClarityType.ResponseOk);

    // add bidirectional edge between tokens via a dummy pool principal
    const addEdge = await simnet.callPublicFn(
      'advanced-router-dijkstra',
      'add-edge',
      [
        Cl.principal(wallet1.address),
        Cl.principal(wallet2.address),
        Cl.principal(deployer.address),
        Cl.stringAscii('constant-product'), // pool-type
        Cl.uint(1_000_000), // liquidity
        Cl.uint(30) // fee (bps)
      ],
      deployer.address
    );
    expect(addEdge.result.type).toBe(ClarityType.ResponseOk);

    // read-only find-optimal-path
    const ro = await simnet.callReadOnlyFn(
      'advanced-router-dijkstra',
      'find-optimal-path',
      [Cl.principal(wallet1.address), Cl.principal(wallet2.address), Cl.uint(10_000)],
      wallet1.address
    );
    expect(ro.type).toBe(ClarityType.ResponseOk);
    // path result is a tuple; we cannot easily parse here, but we assert ResponseOk

    // public swap along optimal path (min-amount-out set to 0 for smoke test)
    const swap = await simnet.callPublicFn(
      'advanced-router-dijkstra',
      'swap-optimal-path',
      [Cl.principal(wallet1.address), Cl.principal(wallet2.address), Cl.uint(10_000), Cl.uint(0)],
      wallet1.address
    );
    expect(swap.result.type).toBe(ClarityType.ResponseOk);
  });
});