import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

const asset = () => Cl.contractPrincipal(deployer, 'cxd-token');

// Integration tests for dimensional-engine + position-manager + collateral-manager.
// These ensure that opening/closing positions works end-to-end with the current
// on-chain contracts and aggregator configuration.
describe('Dimensional Engine / Position Manager Integration', () => {
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
    wallet1 = accounts.get('wallet_1') || 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';

    // Configure oracle-aggregator-v2 with a simple price for the core asset so
    // that position-manager pricing calls succeed.
    const register = simnet.callPublicFn('oracle-aggregator-v2', 'register-oracle', [
      Cl.standardPrincipal(wallet1),
      Cl.bool(true),
    ], deployer);
    expect(register.result).toBeOk(Cl.bool(true));

    const priceUpdate = simnet.callPublicFn('oracle-aggregator-v2', 'update-price', [
      asset(),
      Cl.uint(100_000),
    ], wallet1);
    expect(priceUpdate.result).toBeOk(Cl.bool(true));
  });

  it('opens and closes a long position through dimensional-engine', () => {
    // Provide enough internal collateral for wallet1 via collateral-manager.
    // open-position will compute total-cost = collateral + collateral * fee-rate.
    // With fee-rate = u30, collateral = 100 => total-cost = 3_100.
    const deposit = simnet.callPublicFn('collateral-manager', 'deposit-funds', [
      Cl.uint(5_000),
      asset(),
    ], wallet1);
    expect(deposit.result).toBeOk(Cl.bool(true));

    const open = simnet.callPublicFn('dimensional-engine', 'open-position', [
      asset(),
      Cl.uint(100),
      Cl.uint(2),
      Cl.bool(true),
      Cl.none(),
      Cl.none(),
    ], wallet1);
    expect(open.result).toBeOk();

    const positionId = (open.result as any).value as any;

    // Position should be visible in position-manager
    const position = simnet.callReadOnlyFn('position-manager', 'get-position', [
      positionId,
    ], wallet1);
    expect(position.result).toBeOk();

    const close = simnet.callPublicFn('dimensional-engine', 'close-position', [
      positionId,
      asset(),
      Cl.none(),
    ], wallet1);
    expect(close.result).toBeOk();
  });

  it('rejects opening a position when collateral is insufficient', () => {
    const open = simnet.callPublicFn('dimensional-engine', 'open-position', [
      asset(),
      Cl.uint(100),
      Cl.uint(2),
      Cl.bool(true),
      Cl.none(),
      Cl.none(),
    ], wallet1);

    // ERR_INSUFFICIENT_BALANCE from collateral-manager (u2003)
    expect(open.result).toBeErr(Cl.uint(2003));
  });

  it('propagates position-manager errors when closing a non-existent position', () => {
    const res = simnet.callPublicFn('dimensional-engine', 'close-position', [
      Cl.uint(999),
      asset(),
      Cl.none(),
    ], wallet1);

    // ERR_POSITION_NOT_FOUND from position-manager = (err u4000)
    expect(res.result).toBeErr(Cl.uint(4000));
  });
});
