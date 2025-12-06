import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Proposal Engine - Admin Controls', () => {
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

  it('allows owner to set voting period and quorum percentage and transfer ownership', () => {
    const setPeriod = simnet.callPublicFn('proposal-engine', 'set-voting-period', [
      Cl.uint(1440),
    ], deployer);
    expect(setPeriod.result).toBeOk(Cl.bool(true));

    const badPeriod = simnet.callPublicFn('proposal-engine', 'set-voting-period', [
      Cl.uint(0),
    ], deployer);
    // ERR_INVALID_VOTING_PERIOD = (err u109)
    expect(badPeriod.result).toBeErr(Cl.uint(109));

    const setQuorum = simnet.callPublicFn('proposal-engine', 'set-quorum-percentage', [
      Cl.uint(7500),
    ], deployer);
    expect(setQuorum.result).toBeOk(Cl.bool(true));

    const transfer = simnet.callPublicFn('proposal-engine', 'transfer-ownership', [
      Cl.standardPrincipal(wallet1),
    ], deployer);
    expect(transfer.result).toBeOk(Cl.bool(true));

    // After ownership transfer, deployer should no longer be able to change params
    const failSetPeriod = simnet.callPublicFn('proposal-engine', 'set-voting-period', [
      Cl.uint(100),
    ], deployer);
    expect(failSetPeriod.result).toBeErr(Cl.uint(100));

    // But new owner can
    const successSetPeriod = simnet.callPublicFn('proposal-engine', 'set-voting-period', [
      Cl.uint(100),
    ], wallet1);
    expect(successSetPeriod.result).toBeOk(Cl.bool(true));
  });

  it("enforces quorum percentage bounds between 10% and 100%", () => {
    const zeroQuorum = simnet.callPublicFn(
      "proposal-engine",
      "set-quorum-percentage",
      [Cl.uint(0)],
      deployer
    );
    // Uses ERR_UNAUTHORIZED (u100) for invalid quorum as well
    expect(zeroQuorum.result).toBeErr(Cl.uint(100));

    const lowQuorum = simnet.callPublicFn(
      "proposal-engine",
      "set-quorum-percentage",
      [Cl.uint(500)],
      deployer
    );
    expect(lowQuorum.result).toBeErr(Cl.uint(100));

    const minQuorum = simnet.callPublicFn(
      "proposal-engine",
      "set-quorum-percentage",
      [Cl.uint(1_000)],
      deployer
    );
    expect(minQuorum.result).toBeOk(Cl.bool(true));

    const fullQuorum = simnet.callPublicFn(
      "proposal-engine",
      "set-quorum-percentage",
      [Cl.uint(10_000)],
      deployer
    );
    expect(fullQuorum.result).toBeOk(Cl.bool(true));
  });
});
