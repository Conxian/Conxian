import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

declare global {
  const simnet: any;
}

describe("Concentrated Liquidity Pool", () => {
  let accounts: any;
  let deployer: string;
  let wallet1: string;

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), "Clarinet.toml");
    accounts = simnet.getAccounts();
    // Fallback to hardcoded addresses if get fails (common in some CI environments or non-standard Clarinet.toml)
    // Note: in Clarinet SDK, getAccounts() returns a Map<string, string> where keys are "deployer", "wallet_1", etc.
    // If the map is empty, we must fallback.

    // Explicitly handle the deployer which might be keyed as 'deployer'
    if (accounts.has("deployer")) {
      deployer = accounts.get("deployer") as string;
    } else {
      deployer = "STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ";
      // Attempt to force set if missing in simnet context?
      // No, simnet context is immutable regarding accounts usually.
    }

    if (accounts.has("wallet_1")) {
      wallet1 = accounts.get("wallet_1") as string;
    } else {
      wallet1 = "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5";
    }
  });

  it("initializes correctly", () => {
    const token0 = `${deployer}.cxd-token`;
    const token1 = `${deployer}.cxlp-token`;
    const sqrtPrice = 1000000;
    const tick = 0;
    const fee = 30;

    const result = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.principal(token0),
        Cl.principal(token1),
        Cl.uint(sqrtPrice),
        Cl.int(tick),
        Cl.uint(fee),
      ],
      deployer
    );

    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it("fails to initialize twice", () => {
    const token0 = `${deployer}.cxd-token`;
    const token1 = `${deployer}.cxlp-token`;
    const sqrtPrice = 1000000;
    const tick = 0;
    const fee = 30;

    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.principal(token0),
        Cl.principal(token1),
        Cl.uint(sqrtPrice),
        Cl.int(tick),
        Cl.uint(fee),
      ],
      deployer
    );

    const result = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.principal(token0),
        Cl.principal(token1),
        Cl.uint(sqrtPrice),
        Cl.int(tick),
        Cl.uint(fee),
      ],
      deployer
    );

    expect(result.result).toEqual(Cl.error(Cl.uint(1001))); // ERR_ALREADY_INITIALIZED (Standardized to u1001)
  });

  it("adds liquidity successfully", () => {
    // 1. Initialize
    const token0 = `${deployer}.cxd-token`;
    const token1 = `${deployer}.cxlp-token`;
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.principal(token0),
        Cl.principal(token1),
        Cl.uint(1000000),
        Cl.int(0),
        Cl.uint(30),
      ],
      deployer
    );

    // 2. Mint tokens to wallet1
    simnet.callPublicFn(
      "cxd-token",
      "mint",
      [Cl.principal(wallet1), Cl.uint(1000000)],
      deployer
    );
    simnet.callPublicFn(
      "cxlp-token",
      "mint",
      [Cl.principal(wallet1), Cl.uint(1000000)],
      deployer
    );

    // 3. Add Liquidity
    const result = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "add-liquidity",
      [
        Cl.uint(1000),
        Cl.uint(1000),
        Cl.principal(token0),
        Cl.principal(token1),
      ],
      wallet1
    );

    expect(result.result).toEqual(Cl.ok(Cl.uint(1))); // First position ID
  });

  it("gets reserves correctly", () => {
    const token0 = `${deployer}.cxd-token`;
    const token1 = `${deployer}.cxlp-token`;

    // Initialize first
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.principal(token0),
        Cl.principal(token1),
        Cl.uint(1000000),
        Cl.int(0),
        Cl.uint(30),
      ],
      deployer
    );

    // Mint to wallet1 first
    simnet.callPublicFn(
      "cxd-token",
      "mint",
      [Cl.principal(wallet1), Cl.uint(1000000)],
      deployer
    );
    simnet.callPublicFn(
      "cxlp-token",
      "mint",
      [Cl.principal(wallet1), Cl.uint(1000000)],
      deployer
    );

    // Add liquidity to increase reserves
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "add-liquidity",
      [
        Cl.uint(5000),
        Cl.uint(3000),
        Cl.principal(token0),
        Cl.principal(token1),
      ],
      wallet1
    );

    const result = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "get-reserves",
      [],
      deployer
    );

    expect(result.result).toEqual(
      Cl.ok(
        Cl.tuple({
          reserve0: Cl.uint(5000),
          reserve1: Cl.uint(3000),
        })
      )
    );
  });
});
