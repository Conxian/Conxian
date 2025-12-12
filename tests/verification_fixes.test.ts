
import { describe, it, expect, beforeAll } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: any;
let accounts: any;
let deployer: string;
let wallet1: string;

describe('Verification Fixes', () => {
  beforeAll(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });

  it('Vault: First deposit burns 1000 shares', () => {
    // Deposit 2000 into sbtc-vault.
    // sbtc-vault requires a SIP-010 token. We use mock-token.
    // We assume mock-token is already deployed by clarinet sdk.
    // We need to mint mock-tokens to wallet1 first?
    // sbtc-vault.deposit calls token.transfer.
    // mock-token usually needs minting.

    // Mint 10000 to wallet1
    simnet.callPublicFn('mock-token', 'mint', [
      Cl.uint(10000),
      Cl.standardPrincipal(wallet1)
    ], deployer);

    const depositFn = simnet.callPublicFn('sbtc-vault', 'deposit', [
      Cl.contractPrincipal(deployer, 'mock-token'),
      Cl.uint(2000)
    ], wallet1);

    // Check result. sbtc-vault returns (ok u1000).
    // First deposit burns 1000 shares. 2000 deposited - 1000 burned = 1000 user shares.
    expect(depositFn.result).toEqual(Cl.ok(Cl.uint(1000)));
  });

  it('Compliance: Enforces KYC tier', () => {
    // Check unverified
    const check1 = simnet.callPublicFn('compliance-hooks', 'check-kyc', [
      Cl.standardPrincipal(wallet1)
    ], wallet1);
    expect(check1.result).toEqual(Cl.error(Cl.uint(7000))); // ERR_UNAUTHORIZED

    // Set Tier 1
    simnet.callPublicFn('kyc-registry', 'set-identity-status', [
      Cl.standardPrincipal(wallet1),
      Cl.uint(1), // Tier 1
      Cl.uint(0),
      Cl.stringAscii("USA")
    ], deployer);

    // Call check-kyc -> success
    const check2 = simnet.callPublicFn('compliance-hooks', 'check-kyc', [
      Cl.standardPrincipal(wallet1)
    ], wallet1);
    expect(check2.result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
