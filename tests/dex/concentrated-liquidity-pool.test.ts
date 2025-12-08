import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

// Baseline tests for concentrated-liquidity-pool to ensure core read-only
// views behave as expected with the current deployment configuration.
describe("Concentrated Liquidity Pool", () => {
  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml", false, {
      trackCosts: false,
      trackCoverage: false,
    });
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), "Clarinet.toml");
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });

  it("exposes static reserves in get-reserves", () => {
    const reserves = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "get-reserves",
      [],
      deployer
    );

    expect(reserves.result).toBeOk(
      Cl.tuple({
        reserve0: Cl.uint(0),
        reserve1: Cl.uint(0),
      })
    );
  });

  it("reports last-token-id as u0 before any mints", () => {
    const lastId = simnet.callReadOnlyFn(
      "concentrated-liquidity-pool",
      "get-last-token-id",
      [],
      deployer
    );

    expect(lastId.result).toBeOk(Cl.uint(0));
  });

  it("rejects swap before initialization", () => {
    const tokenIn = Cl.contractPrincipal(deployer, "cxd-token");
    const tokenOut = Cl.contractPrincipal(deployer, "cxlp-token");

    const res = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "swap",
      [Cl.uint(100n), tokenIn, tokenOut],
      wallet1
    );

    expect(res.result).toBeErr(Cl.uint(3009));
  });

  it("rejects swap without liquidity after initialization", () => {
    const tokenIn = Cl.contractPrincipal(deployer, "cxd-token");
    const tokenOut = Cl.contractPrincipal(deployer, "cxlp-token");

    const init = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [tokenIn, tokenOut, Cl.uint(1), Cl.int(0), Cl.uint(30)],
      deployer
    );
    expect(init.result).toBeOk(Cl.bool(true));

    const res = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "swap",
      [Cl.uint(100n), tokenIn, tokenOut],
      wallet1
    );

    expect(res.result).toBeErr(Cl.uint(1307));
  });

  it("rejects remove-liquidity for unknown position id", () => {
    const token0 = Cl.contractPrincipal(deployer, "cxd-token");
    const token1 = Cl.contractPrincipal(deployer, "cxlp-token");

    const res = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "remove-liquidity",
      [Cl.uint(1), token0, token1],
      wallet1
    );

    expect(res.result).toBeErr(Cl.uint(3006));
  });
});
