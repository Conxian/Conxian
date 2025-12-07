/// <reference path="../../vitest-clarity-matchers.d.ts" />
import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { initSimnet, type Simnet } from "@stacks/clarinet-sdk";
import { Cl, ClarityType } from "@stacks/transactions";

let simnet: Simnet;
let wallet1: string;

describe("Guardian Registry", () => {
  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml", false, {
      trackCosts: false,
      trackCoverage: false,
    });
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), "Clarinet.toml");
    const accounts = simnet.getAccounts();
    wallet1 = accounts.get("wallet_1")!;
  });

  it("allows a principal to register as guardian with a positive bond", () => {
    const res = simnet.callPublicFn(
      "guardian-registry",
      "register-guardian",
      [Cl.standardPrincipal(wallet1), Cl.uint(1000)],
      wallet1
    );

    expect(res.result.type).toBe(ClarityType.ResponseOk);
    expect(res.result.value).toEqual(Cl.bool(true));

    const view = simnet.callReadOnlyFn(
      "guardian-registry",
      "is-guardian",
      [Cl.standardPrincipal(wallet1)],
      wallet1
    );

    expect(view.result.type).toBe(ClarityType.ResponseOk);
    expect(view.result.value).toEqual(Cl.bool(true));
  });

  it("supports unbonding and deactivates when bond is zero", () => {
    simnet.callPublicFn(
      "guardian-registry",
      "register-guardian",
      [Cl.standardPrincipal(wallet1), Cl.uint(1000)],
      wallet1
    );

    const unbond = simnet.callPublicFn(
      "guardian-registry",
      "unbond-guardian",
      [Cl.standardPrincipal(wallet1), Cl.uint(1000)],
      wallet1
    );

    expect(unbond.result.type).toBe(ClarityType.ResponseOk);
    expect(unbond.result.value).toEqual(Cl.bool(true));

    const view = simnet.callReadOnlyFn(
      "guardian-registry",
      "is-guardian",
      [Cl.standardPrincipal(wallet1)],
      wallet1
    );

    expect(view.result.type).toBe(ClarityType.ResponseOk);
    expect(view.result.value).toEqual(Cl.bool(false));
  });
});
