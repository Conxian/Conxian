import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;
let wallet2: string;

const cxdToken = () => Cl.contractPrincipal(deployer, 'cxd-token');
const insuranceFund = () => Cl.contractPrincipal('STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ', 'conxian-insurance-fund');
const feeSwitch = () => Cl.contractPrincipal('STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ', 'protocol-fee-switch');

// Full-system integration: route fees from CXD through the protocol fee switch
// into treasury / staking / insurance recipients using only real contracts.
describe('Full System - Fees Routed to Insurance', () => {
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
    wallet2 = accounts.get('wallet_2')!;
  });

  it('routes CXD fees via protocol-fee-switch into insurance fund', () => {
    const feeAmount = 10_000n; // Pre-collected fee amount in CXD base units

    // Owner sets deployer as a minter and mints CXD directly to the
    // protocol-fee-switch contract so it can route already-collected fees.
    const setMinter = simnet.callPublicFn('cxd-token', 'set-minter', [
      Cl.principal(deployer),
      Cl.bool(true),
    ], deployer);
    expect(setMinter.result).toBeOk(Cl.bool(true));

    const mint = simnet.callPublicFn('cxd-token', 'mint', [
      feeSwitch(),
      Cl.uint(feeAmount),
    ], deployer);
    expect(mint.result).toBeOk(Cl.bool(true));

    // Configure recipients: treasury -> wallet1, staking -> wallet2,
    // insurance -> conxian-insurance-fund contract.
    const setRecipients = simnet.callPublicFn('protocol-fee-switch', 'set-recipients', [
      Cl.standardPrincipal(wallet1),
      Cl.standardPrincipal(wallet2),
      insuranceFund(),
    ], deployer);
    expect(setRecipients.result).toBeOk(Cl.bool(true));

    // Configure fee splits and module fee for DEX.
    const setSplits = simnet.callPublicFn('protocol-fee-switch', 'set-fee-splits', [
      Cl.uint(2_000), // 20% treasury
      Cl.uint(6_000), // 60% staking
      Cl.uint(2_000), // 20% insurance
      Cl.uint(0),
    ], deployer);
    expect(setSplits.result).toBeOk(Cl.bool(true));

    const setModuleFee = simnet.callPublicFn('protocol-fee-switch', 'set-module-fee', [
      Cl.stringAscii('DEX'),
      Cl.uint(100), // 1% base fee in BPS (not used directly in this test)
    ], deployer);
    expect(setModuleFee.result).toBeOk(Cl.bool(true));

    // Route an already-collected fee amount held by the fee switch contract.
    const route = simnet.callPublicFn('protocol-fee-switch', 'route-fees', [
      cxdToken(),
      Cl.uint(feeAmount),
      Cl.bool(false),
      Cl.stringAscii('DEX'),
    ], deployer);
    expect(route.result).toBeOk(Cl.uint(Number(feeAmount)));

    // Check that the configured fee rate is visible via read-only.
    const feeRate = simnet.callReadOnlyFn('protocol-fee-switch', 'get-fee-rate', [
      Cl.stringAscii('DEX'),
    ], deployer);
    expect(feeRate.result).toBeOk(Cl.uint(100));

    // Verify CXD balances reflect fee routing and respect the configured splits.
    const treasuryBal = simnet.callReadOnlyFn('cxd-token', 'get-balance', [
      Cl.standardPrincipal(wallet1),
    ], deployer);
    expect(treasuryBal.result).toBeOk(Cl.uint(2_000));

    const stakingBal = simnet.callReadOnlyFn('cxd-token', 'get-balance', [
      Cl.standardPrincipal(wallet2),
    ], deployer);
    expect(stakingBal.result).toBeOk(Cl.uint(6_000));

    const insuranceBal = simnet.callReadOnlyFn('cxd-token', 'get-balance', [
      insuranceFund(),
    ], deployer);
    expect(insuranceBal.result).toBeOk(Cl.uint(2_000));
  });
});
