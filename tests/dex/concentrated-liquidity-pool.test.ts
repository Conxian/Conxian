
import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

declare module "vitest" {
  interface Assertion<T = any> {
    toBeOk(expected?: any): any;
    toBeErr(expected?: any): any;
    toBeSome(expected?: any): any;
    toBeNone(): any;
  }
}

let simnet: Simnet;
let deployer: string;
let wallet1: string;
let clarinet: any;

describe("Concentrated Liquidity Pool", () => {
  beforeAll(async () => {
    clarinet = await initSimnet("Clarinet.toml");
    simnet = await initSimnet(clarinet);
  });

  beforeEach(async () => {
    await simnet.initSession(clarinet, "simnet");
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 =
      accounts.get("wallet_1") || "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5";
  });

  const token0 = "mock-token";
  const token1 = "mock-usda-token";

  it("should initialize correctly", () => {
    const receipt = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
        Cl.uint(79228162514264337593543950336n), // Q96 (price = 1.0)
        Cl.int(0), // Tick 0
        Cl.uint(3000), // 0.3% fee
      ],
      deployer
    );
    expect(receipt.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it("should allow minting a position", () => {
    // 1. Initialize
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
        Cl.uint(79228162514264337593543950336n),
        Cl.int(0),
        Cl.uint(3000),
      ],
      deployer
    );

    // 2. Mint tokens to wallet1 (assuming mocks have mint)
    simnet.callPublicFn(
      token0,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );
    simnet.callPublicFn(
      token1,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );

    // 3. Mint Position
    // Range: -100 to 100
    const receipt = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "mint",
      [
        Cl.standardPrincipal(wallet1),
        Cl.int(-100),
        Cl.int(100),
        Cl.uint(1000000), // Liquidity
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
      ],
      wallet1
    );

    expect(receipt.result).toEqual(Cl.ok(Cl.uint(1))); // Position ID 1

    // Verify liquidity
    const liquidity = simnet.getDataVar(
      "concentrated-liquidity-pool",
      "liquidity"
    );
    expect(liquidity).toEqual(Cl.uint(1000000));
  });

  it("should allow swapping", () => {
    // 1. Initialize & Mint
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
        Cl.uint(79228162514264337593543950336n),
        Cl.int(0),
        Cl.uint(3000),
      ],
      deployer
    );

    simnet.callPublicFn(
      token0,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );
    simnet.callPublicFn(
      token1,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );

    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "mint",
      [
        Cl.standardPrincipal(wallet1),
        Cl.int(-1000),
        Cl.int(1000),
        Cl.uint(10000000), // More liquidity
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
      ],
      wallet1
    );

    // 2. Swap token0 for token1
    const amountIn = 1000;
    const receipt = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "swap",
      [
        Cl.uint(amountIn),
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
      ],
      wallet1
    );

    // Debug logging: inspect swap result when tests fail
    // eslint-disable-next-line no-console
    console.log("CLP swap receipt result:", receipt.result);

    expect(receipt.result).toEqual(Cl.ok(expect.anything())); // Should return amount out

    // Check amount out is roughly what we expect (price is 1.0, so slightly less than 1000 due to fees)
    // Fee = 0.3% = 3
    // Amount remaining = 997
    // Output approx 997 (since ample liquidity and price ~1)
    const amountOut = (receipt.result as any).value.value;
    expect(Number(amountOut)).toBeLessThan(1000);
    expect(Number(amountOut)).toBeGreaterThan(990);
  });

  it("should allow burning a position", () => {
    // 1. Initialize & Mint
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
        Cl.uint(79228162514264337593543950336n),
        Cl.int(0),
        Cl.uint(3000),
      ],
      deployer
    );

    simnet.callPublicFn(
      token0,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );
    simnet.callPublicFn(
      token1,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );

    const mintReceipt = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "mint",
      [
        Cl.standardPrincipal(wallet1),
        Cl.int(-100),
        Cl.int(100),
        Cl.uint(1000000),
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
      ],
      wallet1
    );
    const posId = (mintReceipt.result as any).value; // Should be u1

    // MANUALLY FUND POOL because mint() does not transfer tokens
    simnet.callPublicFn(
      token0,
      "mint",
      [
        Cl.uint(1000000000),
        Cl.contractPrincipal(deployer, "concentrated-liquidity-pool"),
      ],
      deployer
    );
    simnet.callPublicFn(
      token1,
      "mint",
      [
        Cl.uint(1000000000),
        Cl.contractPrincipal(deployer, "concentrated-liquidity-pool"),
      ],
      deployer
    );

    // 2. Burn (Decrease Liquidity)
    const receipt = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "decrease-liquidity",
      [
        posId,
        Cl.uint(500000), // Remove half
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
      ],
      wallet1
    );

    console.log("CLP burn receipt result:", receipt.result);

    expect(receipt.result).toEqual(Cl.ok(expect.anything()));

    // Verify liquidity reduced
    const liquidity = simnet.getDataVar(
      "concentrated-liquidity-pool",
      "liquidity"
    );
    expect(liquidity).toEqual(Cl.uint(500000));
  });

  it("rejects zero-amount liquidity removal", () => {
    // Initialize pool
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
        Cl.uint(79228162514264337593543950336n),
        Cl.int(0),
        Cl.uint(3000),
      ],
      deployer
    );

    // Need a position to call decrease-liquidity
    simnet.callPublicFn(
      token0,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );
    simnet.callPublicFn(
      token1,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "mint",
      [
        Cl.standardPrincipal(wallet1),
        Cl.int(-100),
        Cl.int(100),
        Cl.uint(1000000),
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
      ],
      wallet1
    );

    const receipt = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "decrease-liquidity",
      [
        Cl.uint(1),
        Cl.uint(0),
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
      ],
      wallet1
    );

    expect(receipt.result).toEqual(Cl.error(Cl.uint(101))); // ERR_INVALID_AMOUNT
  });

  it("rejects removing more liquidity than exists", () => {
    // 1. Initialize & Mint
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
        Cl.uint(79228162514264337593543950336n),
        Cl.int(0),
        Cl.uint(3000),
      ],
      deployer
    );

    simnet.callPublicFn(
      token0,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );
    simnet.callPublicFn(
      token1,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );

    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "mint",
      [
        Cl.standardPrincipal(wallet1),
        Cl.int(-100),
        Cl.int(100),
        Cl.uint(1000000),
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
      ],
      wallet1
    );

    const before = simnet.getDataVar(
      "concentrated-liquidity-pool",
      "liquidity"
    );

    const receipt = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "decrease-liquidity",
      [
        Cl.uint(1),
        Cl.uint(2000000), // More than total liquidity in position
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
      ],
      wallet1
    );

    expect(receipt.result).toEqual(Cl.error(Cl.uint(1002))); // ERR_INSUFFICIENT_LIQUIDITY

    // Liquidity should remain unchanged
    const after = simnet.getDataVar("concentrated-liquidity-pool", "liquidity");
    expect(after).toEqual(before);
  });

  it("fails to initialize twice", () => {
    // Initialize first
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
        Cl.uint(79228162514264337593543950336n),
        Cl.int(0),
        Cl.uint(3000),
      ],
      deployer
    );

    // Try to initialize again
    const result = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
        Cl.uint(79228162514264337593543950336n),
        Cl.int(0),
        Cl.uint(3000),
      ],
      deployer
    );

    expect(result.result).toBeErr(Cl.uint(1001)); // ERR_ALREADY_INITIALIZED
  });

  it("adds liquidity successfully via add-liquidity wrapper", () => {
    // 1. Initialize
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
        Cl.uint(79228162514264337593543950336n),
        Cl.int(0),
        Cl.uint(3000),
      ],
      deployer
    );

    // 2. Mint tokens to wallet1
    simnet.callPublicFn(
      token0,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );
    simnet.callPublicFn(
      token1,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );

    // 3. Add Liquidity
    const result = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "add-liquidity",
      [
        Cl.uint(1000),
        Cl.uint(1000),
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
      ],
      wallet1
    );

    expect(result.result).toBeOk(Cl.uint(1)); // First position ID
  });

  it("gets reserves correctly", () => {
    // Initialize first
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
        Cl.uint(79228162514264337593543950336n),
        Cl.int(0),
        Cl.uint(3000),
      ],
      deployer
    );

    // Mint to wallet1 first
    simnet.callPublicFn(
      token0,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );
    simnet.callPublicFn(
      token1,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );

    // Add liquidity to increase reserves
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "add-liquidity",
      [
        Cl.uint(5000),
        Cl.uint(3000),
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
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
