import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const user1 = accounts.get("wallet_1")!;
const user2 = accounts.get("wallet_2")!;

describe("Gamification Manager Tests", () => {
  beforeEach(() => {
    // Reset state before each test
  });

  describe("Epoch Initialization", () => {
    it("should initialize a new epoch", () => {
      const epoch = 1;
      const startBlock = simnet.blockHeight;
      const endBlock = startBlock + 518400; // 30 days
      const cxlpPool = 45833;
      const cxvgPool = 45833;

      const { result } = simnet.callPublicFn(
        "gamification-manager",
        "initialize-epoch",
        [
          Cl.uint(epoch),
          Cl.uint(startBlock),
          Cl.uint(endBlock),
          Cl.uint(cxlpPool),
          Cl.uint(cxvgPool),
        ],
        deployer
      );

      expect(result).toBeOk(Cl.bool(true));
    });

    it("should not allow duplicate epoch initialization", () => {
      const epoch = 1;
      const startBlock = simnet.blockHeight;
      const endBlock = startBlock + 518400;

      // Initialize first time
      simnet.callPublicFn(
        "gamification-manager",
        "initialize-epoch",
        [
          Cl.uint(epoch),
          Cl.uint(startBlock),
          Cl.uint(endBlock),
          Cl.uint(45833),
          Cl.uint(45833),
        ],
        deployer
      );

      // Try to initialize again
      const { result } = simnet.callPublicFn(
        "gamification-manager",
        "initialize-epoch",
        [
          Cl.uint(epoch),
          Cl.uint(startBlock),
          Cl.uint(endBlock),
          Cl.uint(45833),
          Cl.uint(45833),
        ],
        deployer
      );

      expect(result).toBeErr(Cl.uint(1001)); // ERR_INVALID_EPOCH
    });

    it("should only allow owner to initialize epoch", () => {
      const { result } = simnet.callPublicFn(
        "gamification-manager",
        "initialize-epoch",
        [
          Cl.uint(1),
          Cl.uint(simnet.blockHeight),
          Cl.uint(simnet.blockHeight + 518400),
          Cl.uint(45833),
          Cl.uint(45833),
        ],
        user1
      );

      expect(result).toBeErr(Cl.uint(1000)); // ERR_UNAUTHORIZED
    });
  });

  describe("Epoch Finalization", () => {
    it("should finalize an epoch with total points", () => {
      const epoch = 1;
      
      // First initialize the epoch
      simnet.callPublicFn(
        "gamification-manager",
        "initialize-epoch",
        [
          Cl.uint(epoch),
          Cl.uint(simnet.blockHeight),
          Cl.uint(simnet.blockHeight + 518400),
          Cl.uint(45833),
          Cl.uint(45833),
        ],
        deployer
      );

      // Set points oracle
      simnet.callPublicFn(
        "gamification-manager",
        "set-points-oracle",
        [Cl.principal(deployer)],
        deployer
      );

      // Finalize epoch
      const { result } = simnet.callPublicFn(
        "gamification-manager",
        "finalize-epoch",
        [
          Cl.uint(epoch),
          Cl.uint(1000000), // total liquidity points
          Cl.uint(500000),  // total governance points
        ],
        deployer
      );

      expect(result).toBeOk(Cl.bool(true));
    });

    it("should calculate correct conversion rates", () => {
      const epoch = 1;
      const cxlpPool = 45833;
      const cxvgPool = 45833;
      const totalLiquidityPoints = 1000000;
      const totalGovernancePoints = 500000;

      // Initialize and finalize
      simnet.callPublicFn(
        "gamification-manager",
        "initialize-epoch",
        [
          Cl.uint(epoch),
          Cl.uint(simnet.blockHeight),
          Cl.uint(simnet.blockHeight + 518400),
          Cl.uint(cxlpPool),
          Cl.uint(cxvgPool),
        ],
        deployer
      );

      simnet.callPublicFn(
        "gamification-manager",
        "set-points-oracle",
        [Cl.principal(deployer)],
        deployer
      );

      simnet.callPublicFn(
        "gamification-manager",
        "finalize-epoch",
        [
          Cl.uint(epoch),
          Cl.uint(totalLiquidityPoints),
          Cl.uint(totalGovernancePoints),
        ],
        deployer
      );

      // Check conversion rates
      const { result } = simnet.callReadOnlyFn(
        "gamification-manager",
        "get-conversion-rates",
        [Cl.uint(epoch)],
        deployer
      );

      expect(result).toBeSome();
    });
  });

  describe("Reward Claims", () => {
    it("should allow users to claim rewards with valid proof", () => {
      const epoch = 1;
      const liquidityPoints = 10000;
      const governancePoints = 5000;
      const proof = []; // Empty proof for testing

      // Setup epoch
      simnet.callPublicFn(
        "gamification-manager",
        "initialize-epoch",
        [
          Cl.uint(epoch),
          Cl.uint(simnet.blockHeight),
          Cl.uint(simnet.blockHeight + 518400),
          Cl.uint(45833),
          Cl.uint(45833),
        ],
        deployer
      );

      simnet.callPublicFn(
        "gamification-manager",
        "set-points-oracle",
        [Cl.principal(deployer)],
        deployer
      );

      simnet.callPublicFn(
        "gamification-manager",
        "finalize-epoch",
        [
          Cl.uint(epoch),
          Cl.uint(1000000),
          Cl.uint(500000),
        ],
        deployer
      );

      // Note: This will fail without proper Merkle proof implementation
      // This is a placeholder test structure
    });

    it("should not allow double claiming", () => {
      // Test that users cannot claim twice for the same epoch
    });

    it("should not allow claims outside claim window", () => {
      // Test that claims fail after claim window closes
    });
  });

  describe("Admin Functions", () => {
    it("should allow owner to set points oracle", () => {
      const { result } = simnet.callPublicFn(
        "gamification-manager",
        "set-points-oracle",
        [Cl.principal(user1)],
        deployer
      );

      expect(result).toBeOk(Cl.bool(true));
    });

    it("should allow owner to set token contracts", () => {
      const { result } = simnet.callPublicFn(
        "gamification-manager",
        "set-token-contracts",
        [Cl.principal(user1), Cl.principal(user2)],
        deployer
      );

      expect(result).toBeOk(Cl.bool(true));
    });

    it("should not allow non-owner to set contracts", () => {
      const { result } = simnet.callPublicFn(
        "gamification-manager",
        "set-points-oracle",
        [Cl.principal(user2)],
        user1
      );

      expect(result).toBeErr(Cl.uint(1000)); // ERR_UNAUTHORIZED
    });
  });
});
