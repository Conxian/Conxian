import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl, ClarityType } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;
let wallet2: string;

describe('Governance Token', () => {
  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml');
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), 'Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 =
      accounts.get("wallet_1") || "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5";
    wallet2 =
      accounts.get("wallet_2") || "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG";
  });

  it("has correct initial metadata and zero supply", () => {
    const name = simnet.callReadOnlyFn(
      "governance-token",
      "get-name",
      [],
      deployer
    );
    expect(name.result).toBeOk(Cl.stringAscii("ConxianGovernance"));

    const symbol = simnet.callReadOnlyFn(
      "governance-token",
      "get-symbol",
      [],
      deployer
    );
    expect(symbol.result).toBeOk(Cl.stringAscii("CXVG"));

    const decimals = simnet.callReadOnlyFn(
      "governance-token",
      "get-decimals",
      [],
      deployer
    );
    expect(decimals.result).toBeOk(Cl.uint(6));

    const supply = simnet.callReadOnlyFn(
      "governance-token",
      "get-total-supply",
      [],
      deployer
    );
    expect(supply.result).toBeOk(Cl.uint(0));

    const uri = simnet.callReadOnlyFn(
      "governance-token",
      "get-token-uri",
      [],
      deployer
    );
    expect(uri.result).toBeOk(Cl.none());
  });

  it("allows owner to mint and updates balances and voting power", () => {
    const amount = Cl.uint(1_000_000_000);

    const mint = simnet.callPublicFn(
      "governance-token",
      "mint",
      [amount, Cl.standardPrincipal(wallet1)],
      deployer
    );
    expect(mint.result).toBeOk(Cl.bool(true));

    const balance = simnet.callReadOnlyFn(
      "governance-token",
      "get-balance",
      [Cl.standardPrincipal(wallet1)],
      deployer
    );
    expect(balance.result).toBeOk(amount);

    const supply = simnet.callReadOnlyFn(
      "governance-token",
      "get-total-supply",
      [],
      deployer
    );
    expect(supply.result).toBeOk(amount);

    const power = simnet.callReadOnlyFn(
      "governance-token",
      "get-voting-power",
      [Cl.standardPrincipal(wallet1)],
      deployer
    );
    expect(power.result).toBeOk(amount);
  });

  it("rejects minting from non-owner", () => {
    const res = simnet.callPublicFn(
      "governance-token",
      "mint",
      [Cl.uint(1_000), Cl.standardPrincipal(wallet1)],
      wallet1
    );

    // ERR_UNAUTHORIZED = (err u100)
    expect(res.result).toBeErr(Cl.uint(100));
  });

  it("supports transfers and updates voting power of sender and recipient", () => {
    const mint = simnet.callPublicFn(
      "governance-token",
      "mint",
      [Cl.uint(1_000_000), Cl.standardPrincipal(wallet1)],
      deployer
    );
    expect(mint.result).toBeOk(Cl.bool(true));

    const transfer = simnet.callPublicFn(
      "governance-token",
      "transfer",
      [
        Cl.uint(200_000),
        Cl.standardPrincipal(wallet1),
        Cl.standardPrincipal(wallet2),
        Cl.none(),
      ],
      wallet1
    );
    expect(transfer.result).toBeOk(Cl.bool(true));

    const power1 = simnet.callReadOnlyFn(
      "governance-token",
      "get-voting-power",
      [Cl.standardPrincipal(wallet1)],
      deployer
    );
    const power2 = simnet.callReadOnlyFn(
      "governance-token",
      "get-voting-power",
      [Cl.standardPrincipal(wallet2)],
      deployer
    );

    expect(power1.result).toBeOk(Cl.uint(800_000));
    expect(power2.result).toBeOk(Cl.uint(200_000));
  });

  it("supports delegation and undelegation of voting power", () => {
    // Mint balances to both wallets
    simnet.callPublicFn(
      "governance-token",
      "mint",
      [Cl.uint(1_000), Cl.standardPrincipal(wallet1)],
      deployer
    );
    simnet.callPublicFn(
      "governance-token",
      "mint",
      [Cl.uint(500), Cl.standardPrincipal(wallet2)],
      deployer
    );

    // wallet1 delegates 400 votes to wallet2
    const del = simnet.callPublicFn(
      "governance-token",
      "delegate-voting-power",
      [Cl.standardPrincipal(wallet2), Cl.uint(400)],
      wallet1
    );
    expect(del.result).toBeOk(Cl.bool(true));

    const pow1AfterDel = simnet.callReadOnlyFn(
      "governance-token",
      "get-voting-power",
      [Cl.standardPrincipal(wallet1)],
      deployer
    );
    const pow2AfterDel = simnet.callReadOnlyFn(
      "governance-token",
      "get-voting-power",
      [Cl.standardPrincipal(wallet2)],
      deployer
    );

    expect(pow1AfterDel.result).toBeOk(Cl.uint(1_000));
    expect(pow2AfterDel.result).toBeOk(Cl.uint(900));

    // wallet1 undelegates 200 votes
    const undel = simnet.callPublicFn(
      "governance-token",
      "undelegate-voting-power",
      [Cl.standardPrincipal(wallet2), Cl.uint(200)],
      wallet1
    );
    expect(undel.result).toBeOk(Cl.bool(true));

    const pow1Final = simnet.callReadOnlyFn(
      "governance-token",
      "get-voting-power",
      [Cl.standardPrincipal(wallet1)],
      deployer
    );
    const pow2Final = simnet.callReadOnlyFn(
      "governance-token",
      "get-voting-power",
      [Cl.standardPrincipal(wallet2)],
      deployer
    );

    expect(pow1Final.result).toBeOk(Cl.uint(1_200));
    expect(pow2Final.result).toBeOk(Cl.uint(700));
  });

  it("reports whether an account has voting power", () => {
    const before = simnet.callPublicFn(
      "governance-token",
      "has-voting-power",
      [Cl.standardPrincipal(wallet1)],
      wallet1
    );
    expect(before.result).toBeOk(Cl.bool(false));

    simnet.callPublicFn(
      "governance-token",
      "mint",
      [Cl.uint(1_000), Cl.standardPrincipal(wallet1)],
      deployer
    );

    const after = simnet.callPublicFn(
      "governance-token",
      "has-voting-power",
      [Cl.standardPrincipal(wallet1)],
      wallet1
    );
    expect(after.result).toBeOk(Cl.bool(true));
  });

  it("should allow owner to configure system integration (set-token-uri)", () => {
    const receipt = simnet.callPublicFn(
      "governance-token",
      "set-token-uri",
      [Cl.some(Cl.stringUtf8("ipfs://cxvg-metadata"))],
      deployer
    );
    expect(receipt.result).toBeOk(Cl.bool(true));
  });
});
