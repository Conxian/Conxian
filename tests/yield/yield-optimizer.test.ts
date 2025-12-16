import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

// Sanity tests for yield-optimizer: ownership, strategy registration,
// and best-strategy tracking.
describe("Yield Optimizer", () => {
  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml");
  });

  beforeEach(async () => {
    // initSession takes (path, manifestPath)
    await simnet.initSession(process.cwd(), "Clarinet.toml");
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });

  it("allows owner to adjust max risk", () => {
    const res = simnet.callPublicFn(
      "yield-optimizer",
      "set-max-risk",
      [Cl.uint(80)],
      deployer
    );

    expect(res.result).toBeOk(Cl.bool(true));
  });

  it("tracks a newly added strategy and updates best-strategy", () => {
    const strategy = Cl.contractPrincipal(deployer, "sbtc-vault");

    const add = simnet.callPublicFn(
      "yield-optimizer",
      "add-strategy",
      [
        strategy,
        Cl.uint(1_000), // APY (bps-style)
        Cl.uint(30), // risk-score <= default max-risk
      ],
      deployer
    );
    expect(add.result).toBeOk(Cl.bool(true));

    const info = simnet.callReadOnlyFn(
      "yield-optimizer",
      "get-strategy",
      [strategy],
      deployer
    );
    expect(info.result).toBeSome();

    const best = simnet.callReadOnlyFn(
      "yield-optimizer",
      "get-best-strategy",
      [],
      deployer
    );
    expect(best.result).toBeOk(strategy);
  });
});
