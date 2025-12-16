/// <reference path="../../vitest-clarity-matchers.d.ts" />
import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { initSimnet, type Simnet } from "@stacks/clarinet-sdk";
import { Cl } from "@stacks/transactions";

let simnet: Simnet;
let wallet1: string;
let wallet2: string;
let wallet3: string;
let deployer: string;

describe("Guardian Registry", () => {
  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml");
  });

  beforeEach(async () => {
    await simnet.initSession("0", "0");
    const accounts = simnet.getAccounts();
    wallet1 =
      accounts.get("wallet_1") || "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5";
    wallet2 =
      accounts.get("wallet_2") || "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG";
    wallet3 =
      accounts.get("wallet_3") || "ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC";
    deployer = accounts.get("deployer")!;

    // Mint CXD tokens to wallets for bonding (deployer is minter by default)
    simnet.callPublicFn(
      "cxd-token",
      "mint",
      [Cl.standardPrincipal(wallet1), Cl.uint(10000000)],
      deployer
    );
    simnet.callPublicFn(
      "cxd-token",
      "mint",
      [Cl.standardPrincipal(wallet2), Cl.uint(10000000)],
      deployer
    );
    simnet.callPublicFn(
      "cxd-token",
      "mint",
      [Cl.standardPrincipal(wallet3), Cl.uint(10000000)],
      deployer
    );
  });

  it("allows a principal to register as guardian with a positive bond", () => {
    const res = simnet.callPublicFn(
      "guardian-registry",
      "register-guardian",
      [
        Cl.standardPrincipal(wallet1),
        Cl.uint(1000),
        Cl.contractPrincipal(deployer, "cxd-token"),
      ],
      wallet1
    );

    expect(res.result).toBeOk(Cl.bool(true));

    const view = simnet.callReadOnlyFn(
      "guardian-registry",
      "is-guardian",
      [Cl.standardPrincipal(wallet1)],
      wallet1
    );

    expect(view.result).toBeOk(Cl.bool(true));
  });

  it("supports unbonding and deactivates when bond is zero", () => {
    simnet.callPublicFn(
      "guardian-registry",
      "register-guardian",
      [
        Cl.standardPrincipal(wallet1),
        Cl.uint(1000),
        Cl.contractPrincipal(deployer, "cxd-token"),
      ],
      wallet1
    );

    const unbond = simnet.callPublicFn(
      "guardian-registry",
      "unbond-guardian",
      [
        Cl.standardPrincipal(wallet1),
        Cl.uint(1000),
        Cl.contractPrincipal(deployer, "cxd-token"),
      ],
      wallet1
    );

    expect(unbond.result).toBeOk(Cl.bool(true));

    const view = simnet.callReadOnlyFn(
      "guardian-registry",
      "is-guardian",
      [Cl.standardPrincipal(wallet1)],
      wallet1
    );

    expect(view.result).toBeOk(Cl.bool(false));
  });

  it("computes guardian tiers based on configurable bond thresholds", () => {
    simnet.callPublicFn(
      "guardian-registry",
      "set-min-bond-tiers",
      [Cl.uint(100), Cl.uint(500)],
      deployer
    );

    simnet.callPublicFn(
      "guardian-registry",
      "register-guardian",
      [
        Cl.standardPrincipal(wallet1),
        Cl.uint(50),
        Cl.contractPrincipal(deployer, "cxd-token"),
      ],
      wallet1
    );

    const tier0 = simnet.callReadOnlyFn(
      "guardian-registry",
      "get-guardian-tier",
      [Cl.standardPrincipal(wallet1)],
      wallet1
    );

    expect(tier0.result).toBeOk(Cl.some(Cl.uint(0)));

    simnet.callPublicFn(
      "guardian-registry",
      "register-guardian",
      [
        Cl.standardPrincipal(wallet2),
        Cl.uint(100),
        Cl.contractPrincipal(deployer, "cxd-token"),
      ],
      wallet2
    );

    const tier1 = simnet.callReadOnlyFn(
      "guardian-registry",
      "get-guardian-tier",
      [Cl.standardPrincipal(wallet2)],
      wallet2
    );

    expect(tier1.result).toBeOk(Cl.some(Cl.uint(1)));

    simnet.callPublicFn(
      "guardian-registry",
      "register-guardian",
      [
        Cl.standardPrincipal(wallet3),
        Cl.uint(600),
        Cl.contractPrincipal(deployer, "cxd-token"),
      ],
      wallet3
    );

    const tier2 = simnet.callReadOnlyFn(
      "guardian-registry",
      "get-guardian-tier",
      [Cl.standardPrincipal(wallet3)],
      wallet3
    );

    expect(tier2.result).toBeOk(Cl.some(Cl.uint(2)));
  });

  it("accrues and allows guardians to claim rewards", () => {
    simnet.callPublicFn(
      "guardian-registry",
      "register-guardian",
      [
        Cl.standardPrincipal(wallet1),
        Cl.uint(1000),
        Cl.contractPrincipal(deployer, "cxd-token"),
      ],
      wallet1
    );

    const credit = simnet.callPublicFn(
      "guardian-registry",
      "credit-reward",
      [Cl.standardPrincipal(wallet1), Cl.uint(100)],
      deployer
    );

    expect(credit.result).toBeOk(Cl.bool(true));

    const accrued = simnet.callReadOnlyFn(
      "guardian-registry",
      "get-accrued-rewards",
      [Cl.standardPrincipal(wallet1)],
      wallet1
    );

    expect(accrued.result).toBeOk(Cl.uint(100));

    const claim = simnet.callPublicFn(
      "guardian-registry",
      "claim-rewards",
      [Cl.standardPrincipal(wallet1)],
      wallet1
    );

    expect(claim.result).toBeOk(Cl.uint(100));

    const accruedAfter = simnet.callReadOnlyFn(
      "guardian-registry",
      "get-accrued-rewards",
      [Cl.standardPrincipal(wallet1)],
      wallet1
    );

    expect(accruedAfter.result).toBeOk(Cl.uint(0));
  });
});
