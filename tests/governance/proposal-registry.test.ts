import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Proposal Registry', () => {
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

  it('allows owner to set engine and voting contracts', () => {
    const setEngine = simnet.callPublicFn('proposal-registry', 'set-proposal-engine-contract', [
      Cl.standardPrincipal(deployer),
    ], deployer);
    expect(setEngine.result).toBeOk(Cl.bool(true));

    const setVoting = simnet.callPublicFn('proposal-registry', 'set-voting-contract', [
      Cl.standardPrincipal(deployer),
    ], deployer);
    expect(setVoting.result).toBeOk(Cl.bool(true));
  });

  it('creates a proposal when called by configured engine account', () => {
    // Configure the engine to be the deployer account
    simnet.callPublicFn('proposal-registry', 'set-proposal-engine-contract', [
      Cl.standardPrincipal(deployer),
    ], deployer);

    const create = simnet.callPublicFn('proposal-registry', 'create-proposal', [
      Cl.standardPrincipal(wallet1),
      Cl.stringAscii('Test proposal'),
      Cl.uint(1),
      Cl.uint(100),
    ], deployer);

    expect(create.result).toBeOk(Cl.uint(1));

    const proposal = simnet.callReadOnlyFn('proposal-registry', 'get-proposal', [
      Cl.uint(1),
    ], deployer);

    // We only assert that a proposal exists and is wrapped in an Ok
    expect(proposal.result).toBeOk();
  });

  it('updates votes, marks executed and canceled when called by authorized contracts', () => {
    // Configure engine & voting contracts to be the deployer
    simnet.callPublicFn('proposal-registry', 'set-proposal-engine-contract', [
      Cl.standardPrincipal(deployer),
    ], deployer);
    simnet.callPublicFn('proposal-registry', 'set-voting-contract', [
      Cl.standardPrincipal(deployer),
    ], deployer);

    // Create a proposal as the engine
    simnet.callPublicFn('proposal-registry', 'create-proposal', [
      Cl.standardPrincipal(wallet1),
      Cl.stringAscii('Execution proposal'),
      Cl.uint(1),
      Cl.uint(100),
    ], deployer);

    const updateVotes = simnet.callPublicFn('proposal-registry', 'update-votes', [
      Cl.uint(1),
      Cl.uint(10),
      Cl.uint(2),
    ], deployer);
    expect(updateVotes.result).toBeOk(Cl.bool(true));

    const executed = simnet.callPublicFn('proposal-registry', 'set-executed', [
      Cl.uint(1),
    ], deployer);
    expect(executed.result).toBeOk(Cl.bool(true));

    const canceled = simnet.callPublicFn('proposal-registry', 'set-canceled', [
      Cl.uint(1),
    ], deployer);
    expect(canceled.result).toBeOk(Cl.bool(true));
  });
});
