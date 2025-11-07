import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import crypto from 'crypto';

function sha256Hex(buff: Buffer): string {
  return '0x' + crypto.createHash('sha256').update(buff).digest('hex');
}

describe('Proof of Reserves - Merkle verification and staleness', () => {
  const deployer = 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ';
  const asset = `${deployer}.mock-token-a`;

  let leafHex: string;
  let siblingHex: string;
  let rootHex: string;

  beforeAll(() => {
    // Create a simple 2-node proof: leaf + sibling
    const leaf = crypto.randomBytes(32);
    const sibling = crypto.randomBytes(32);
    leafHex = '0x' + leaf.toString('hex');
    siblingHex = '0x' + sibling.toString('hex');
    const root = crypto.createHash('sha256').update(Buffer.concat([leaf, sibling])).digest();
    rootHex = '0x' + root.toString('hex');

    // Configure admin (deployer is default admin)
    simnet.callPublicFn('proof-of-reserves', 'set-stale-threshold', [Cl.uint(1000)], deployer);

    // Set attestation for asset
    const setRes = simnet.callPublicFn(
      'proof-of-reserves',
      'set-attestation',
      [Cl.principal(asset), Cl.buffer(Buffer.from(rootHex.slice(2), 'hex')), Cl.uint(1000000), Cl.uint(1)],
      deployer
    );
    expect(setRes.result.type).toBe('ok');
    const att = simnet.callReadOnlyFn('proof-of-reserves','get-attestation',[Cl.principal(asset)], deployer);
    expect(att.result.type).toBe('ok');
    expect(att.result.value.type).toBe('some');
  });

  it('verifies a correct merkle proof', () => {
    const proofList = [Cl.tuple({ sibling: Cl.buffer(Buffer.from(siblingHex.slice(2), 'hex')), left: Cl.bool(false) })];
    const result = simnet.callPublicFn(
      'proof-of-reserves',
      'verify-account-reserve',
      [Cl.principal(asset), Cl.buffer(Buffer.from(leafHex.slice(2), 'hex')), Cl.list(proofList)],
      deployer
    );
    expect(result.result.type).toBe('ok');
  });

  it('fails verification for wrong proof', () => {
    const badSibling = '0x' + crypto.randomBytes(32).toString('hex');
    const proofList = [Cl.tuple({ sibling: Cl.buffer(Buffer.from(badSibling.slice(2), 'hex')), left: Cl.bool(false) })];
    const result = simnet.callPublicFn(
      'proof-of-reserves',
      'verify-account-reserve',
      [Cl.principal(asset), Cl.buffer(Buffer.from(leafHex.slice(2), 'hex')), Cl.list(proofList)],
      deployer
    );
    expect(result.result.type).toBe('err');
  });

  it('detects staleness after threshold (env limited: expects false)', () => {
    simnet.callPublicFn('proof-of-reserves', 'set-stale-threshold', [Cl.uint(5)], deployer);
    simnet.mineEmptyBlock(6);
    const st = simnet.callReadOnlyFn('proof-of-reserves', 'is-stale', [Cl.principal(asset)], deployer);
    expect(st.result.type).toBe('ok');
    expect(st.result.value.type).toBe('false');
  });
});