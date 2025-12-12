import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;
let token0: string;
let token1: string;

describe('Concentrated Liquidity Pool', () => {
    beforeAll(async () => {
        simnet = await initSimnet('Clarinet.toml');
    });

    beforeEach(async () => {
      await simnet.initSession(process.cwd(), "Clarinet.toml");
      const accounts = simnet.getAccounts();
      deployer = accounts.get("deployer")!;
      wallet1 = accounts.get("wallet_1")!;
      token0 = `${deployer}.mock-token`;
      token1 = `${deployer}.mock-usda-token`;
    });

    it("should initialize correctly", () => {
      const receipt = simnet.callPublicFn(
        "concentrated-liquidity-pool",
        "initialize",
        [
          Cl.contractPrincipal(deployer, "mock-token"),
          Cl.contractPrincipal(deployer, "mock-usda-token"),
          Cl.uint(79228162514264337593543950336n), // Q96 = 1.0
          Cl.int(0),
          Cl.uint(3000), // 0.3%
        ],
        deployer
      );
      expect(receipt.result).toBeOk(Cl.bool(true));
    });

    it("should mint a position", () => {
      // 1. Initialize
      simnet.callPublicFn(
        "concentrated-liquidity-pool",
        "initialize",
        [
          Cl.contractPrincipal(deployer, "mock-token"),
          Cl.contractPrincipal(deployer, "mock-usda-token"),
          Cl.uint(79228162514264337593543950336n),
          Cl.int(0),
          Cl.uint(3000),
        ],
        deployer
      );

      // 2. Mint tokens to wallet1 so they can add liquidity
      simnet.callPublicFn(
        "mock-token",
        "mint",
        [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
        deployer
      );
      simnet.callPublicFn(
        "mock-usda-token",
        "mint",
        [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
        deployer
      );

      // 3. Mint Position
      const receipt = simnet.callPublicFn(
        "concentrated-liquidity-pool",
        "mint",
        [
          Cl.standardPrincipal(wallet1),
          Cl.int(-887272),
          Cl.int(887272),
          Cl.uint(1000000),
          Cl.contractPrincipal(deployer, "mock-token"),
          Cl.contractPrincipal(deployer, "mock-usda-token"),
        ],
        wallet1
      );

      expect(receipt.result).toBeOk(Cl.uint(1)); // Position ID 1
    });

    it("should swap correctly", () => {
      // Setup
      simnet.callPublicFn(
        "concentrated-liquidity-pool",
        "initialize",
        [
          Cl.contractPrincipal(deployer, "mock-token"),
          Cl.contractPrincipal(deployer, "mock-usda-token"),
          Cl.uint(79228162514264337593543950336n),
          Cl.int(0),
          Cl.uint(3000),
        ],
        deployer
      );

      // LP Provider
      simnet.callPublicFn(
        "mock-token",
        "mint",
        [Cl.uint(10000000000), Cl.standardPrincipal(deployer)],
        deployer
      );
      simnet.callPublicFn(
        "mock-usda-token",
        "mint",
        [Cl.uint(10000000000), Cl.standardPrincipal(deployer)],
        deployer
      );

      simnet.callPublicFn(
        "concentrated-liquidity-pool",
        "mint",
        [
          Cl.standardPrincipal(deployer),
          Cl.int(-887272),
          Cl.int(887272),
          Cl.uint(1000000000), // 1000 tokens liquidity
          Cl.contractPrincipal(deployer, "mock-token"),
          Cl.contractPrincipal(deployer, "mock-usda-token"),
        ],
        deployer
      );

      // Trader
      simnet.callPublicFn(
        "mock-token",
        "mint",
        [Cl.uint(1000000), Cl.standardPrincipal(wallet1)],
        deployer
      );

      // Swap
      const receipt = simnet.callPublicFn(
        "concentrated-liquidity-pool",
        "swap",
        [
          Cl.uint(100000),
          Cl.contractPrincipal(deployer, "mock-token"),
          Cl.contractPrincipal(deployer, "mock-usda-token"),
        ],
        wallet1
      );

      // Under the simplified constant-price CLP math, amount-out should be
      // slightly less than amount-in due to fees, but still close.
      expect(receipt.result).toBeOk(expect.anything());
      const amountOut = (receipt.result as any).value.value;
      expect(Number(amountOut)).toBeLessThan(100000);
      expect(Number(amountOut)).toBeGreaterThan(99000);
    });
});
