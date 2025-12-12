
import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Concentrated Liquidity Pool', () => {
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
  });

  const token0 = 'mock-token';
  const token1 = 'mock-usda-token';

  it('should initialize correctly', () => {
    const receipt = simnet.callPublicFn('concentrated-liquidity-pool', 'initialize', [
      Cl.contractPrincipal(deployer, token0),
      Cl.contractPrincipal(deployer, token1),
      Cl.uint(79228162514264337593543950336n), // Q96 (price = 1.0)
      Cl.int(0), // Tick 0
      Cl.uint(3000), // 0.3% fee
    ], deployer);
    expect(receipt.result).toBeOk(Cl.bool(true));
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

    expect(receipt.result).toBeOk(Cl.uint(1)); // Position ID 1

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
    console.log("CLP swap receipt (pool.test.ts):", receipt.result);

    expect(receipt.result).toBeOk(expect.anything()); // Should return amount out

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

    // 2. Burn
    const receipt = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "remove-liquidity",
      [
        Cl.uint(500000), // Remove half
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
      ],
      wallet1
    );

    expect(receipt.result).toBeOk(expect.anything());

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

    const receipt = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "remove-liquidity",
      [
        Cl.uint(0),
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
      ],
      wallet1
    );

    expect(receipt.result).toBeErr(expect.anything());
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
      "remove-liquidity",
      [
        Cl.uint(2000000), // More than total liquidity
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
      ],
      wallet1
    );

    expect(receipt.result).toBeErr(expect.anything());

    // Liquidity should remain unchanged
    const after = simnet.getDataVar("concentrated-liquidity-pool", "liquidity");
    expect(after).toEqual(before);
  });
});
