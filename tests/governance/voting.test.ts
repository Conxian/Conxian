import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Governance Voting', () => {
  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml', false, {
      trackCosts: false,
      trackCoverage: false,
    });
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), 'Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  it('allows owner to set the proposal engine contract and rejects others', () => {
    const setByOwner = simnet.callPublicFn('governance-voting', 'set-proposal-engine-contract', [
      Cl.standardPrincipal(deployer),
    ], deployer);
    expect(setByOwner.result).toBeOk(Cl.bool(true));

    const setByNonOwner = simnet.callPublicFn('governance-voting', 'set-proposal-engine-contract', [
      Cl.standardPrincipal(wallet1),
    ], wallet1);

    // (err u100) ERR_UNAUTHORIZED
    expect(setByNonOwner.result).toBeErr(Cl.uint(100));
  });

  it('records a vote when called by the configured engine and prevents double voting', () => {
    // Configure the engine as the deployer
    const setByOwner = simnet.callPublicFn('governance-voting', 'set-proposal-engine-contract', [
      Cl.standardPrincipal(deployer),
    ], deployer);
    expect(setByOwner.result).toBeOk(Cl.bool(true));

    const proposalId = Cl.uint(1);

    const firstVote = simnet.callPublicFn('governance-voting', 'vote', [
      proposalId,
      Cl.bool(true),
      Cl.uint(100),
      Cl.standardPrincipal(wallet1),
    ], deployer);
    expect(firstVote.result).toBeOk(Cl.bool(true));

    // Duplicate vote for same proposal & voter should fail with ERR_ALREADY_VOTED (u105)
    const secondVote = simnet.callPublicFn('governance-voting', 'vote', [
      proposalId,
      Cl.bool(false),
      Cl.uint(50),
      Cl.standardPrincipal(wallet1),
    ], deployer);
    expect(secondVote.result).toBeErr(Cl.uint(105));

    const stored = simnet.callReadOnlyFn('governance-voting', 'get-vote', [
      proposalId,
      Cl.standardPrincipal(wallet1),
    ], deployer);

    expect(stored.result).toBeOk(Cl.some(Cl.tuple({
      support: Cl.bool(true),
      votes: Cl.uint(100),
    })));
  });
});
