import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { Simnet, initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Governance Voting', () => {
  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml');
  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  it('allows users to lock tokens and vote via the proposal engine', () => {
    // Lock tokens in the voting contract
    const lockTx = simnet.callPublicFn('governance-voting', 'lock-tokens', [
      Cl.uint(100),
    ], wallet1);
    expect(lockTx.result).toBeOk(Cl.bool(true));

    // Propose a new proposal
    const proposalTx = simnet.callPublicFn('proposal-engine', 'propose', [
      Cl.stringAscii('Test Proposal'),
      Cl.list([Cl.standardPrincipal(wallet1)]),
      Cl.list([Cl.uint(1)]),
      Cl.list([Cl.stringAscii('test')]),
      Cl.list([Cl.bufferFromAscii('test')]),
      Cl.uint(1),
      Cl.uint(100),
    ], wallet1);
    expect(proposalTx.result).toBeOk(Cl.uint(0));

    // Vote on the proposal
    const voteTx = simnet.callPublicFn('proposal-engine', 'vote', [
      Cl.uint(0),
      Cl.bool(true),
    ], wallet1);
    expect(voteTx.result).toBeOk(Cl.bool(true));
  });
});
