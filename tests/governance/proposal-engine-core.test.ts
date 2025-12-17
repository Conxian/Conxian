import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Proposal Engine - Core Functionality', () => {
  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml');
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), 'Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  it('allows a user to create a proposal', () => {
    const proposal = simnet.callPublicFn(
      'proposal-engine',
      'propose',
      [
        Cl.stringAscii('Test Proposal'),
        Cl.list([Cl.standardPrincipal(deployer)]),
        Cl.list([Cl.uint(0)]),
        Cl.list([Cl.stringAscii('test')]),
        Cl.list([Cl.bufferFromAscii('test')]),
        Cl.uint(0),
        Cl.uint(100),
      ],
      wallet1
    );
    expect(proposal.result).toBeOk(Cl.uint(1));
  });

  it('allows a user to vote on a proposal', () => {
    simnet.callPublicFn(
      'proposal-engine',
      'propose',
      [
        Cl.stringAscii('Test Proposal'),
        Cl.list([Cl.standardPrincipal(deployer)]),
        Cl.list([Cl.uint(0)]),
        Cl.list([Cl.stringAscii('test')]),
        Cl.list([Cl.bufferFromAscii('test')]),
        Cl.uint(0),
        Cl.uint(100),
      ],
      wallet1
    );

    const vote = simnet.callPublicFn(
      'proposal-engine',
      'vote',
      [Cl.uint(1), Cl.bool(true), Cl.uint(100)],
      wallet1
    );
    expect(vote.result).toBeOk(Cl.bool(true));
  });

  it('allows a proposal to be executed after it has been approved', () => {
    simnet.callPublicFn(
      'proposal-engine',
      'propose',
      [
        Cl.stringAscii('Test Proposal'),
        Cl.list([Cl.standardPrincipal(deployer)]),
        Cl.list([Cl.uint(0)]),
        Cl.list([Cl.stringAscii('test')]),
        Cl.list([Cl.bufferFromAscii('test')]),
        Cl.uint(0),
        Cl.uint(1),
      ],
      wallet1
    );

    simnet.callPublicFn(
      'proposal-engine',
      'vote',
      [Cl.uint(1), Cl.bool(true), Cl.uint(1000000)],
      wallet1
    );

    simnet.mineEmptyBlock();

    const execute = simnet.callPublicFn(
      'proposal-engine',
      'execute',
      [Cl.uint(1)],
      wallet1
    );
    expect(execute.result).toBeOk(Cl.bool(true));
  });

  it('enforces the proposal delay', () => {
    const proposal = simnet.callPublicFn(
      'proposal-engine',
      'propose',
      [
        Cl.stringAscii('Test Proposal'),
        Cl.list([Cl.standardPrincipal(deployer)]),
        Cl.list([Cl.uint(0)]),
        Cl.list([Cl.stringAscii('test')]),
        Cl.list([Cl.bufferFromAscii('test')]),
        Cl.uint(10), // Start block is in the future
        Cl.uint(110),
      ],
      wallet1
    );

    const vote = simnet.callPublicFn(
      'proposal-engine',
      'vote',
      [Cl.uint(1), Cl.bool(true), Cl.uint(100)],
      wallet1
    );
    expect(vote.result).toBeErr(Cl.uint(103)); // ERR_PROPOSAL_NOT_ACTIVE
  });

  it('enforces the voting period', () => {
    simnet.callPublicFn(
      'proposal-engine',
      'propose',
      [
        Cl.stringAscii('Test Proposal'),
        Cl.list([Cl.standardPrincipal(deployer)]),
        Cl.list([Cl.uint(0)]),
        Cl.list([Cl.stringAscii('test')]),
        Cl.list([Cl.bufferFromAscii('test')]),
        Cl.uint(0),
        Cl.uint(1),
      ],
      wallet1
    );

    simnet.mineEmptyBlock();
    simnet.mineEmptyBlock();

    const vote = simnet.callPublicFn(
      'proposal-engine',
      'vote',
      [Cl.uint(1), Cl.bool(true), Cl.uint(100)],
      wallet1
    );
    expect(vote.result).toBeErr(Cl.uint(104)); // ERR_VOTING_CLOSED
  });
});