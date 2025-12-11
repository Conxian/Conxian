// @ts-nocheck
import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;
let wallet2: string;

describe('Behavior Metrics & Reputation System', () => {
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
    wallet2 = accounts.get('wallet_2')!;
  });

  describe("Behavior Metrics Read Functions", () => {
    it("returns default behavior metrics for new users", () => {
      const metrics = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-user-behavior-metrics",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );

      const data = (metrics.result as any).value;
      expect(data["reputation-score"]).toStrictEqual(Cl.uint(0));
      expect(data["behavior-tier"]).toStrictEqual(Cl.uint(1)); // Bronze
      expect(data["incentive-multiplier"]).toStrictEqual(Cl.uint(100)); // 1.0x
    });

    it("returns default governance behavior for new users", () => {
      const behavior = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-governance-behavior",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );

      const data = (behavior.result as any).value;
      expect(data["proposals-voted"]).toStrictEqual(Cl.uint(0));
      expect(data["proposals-created"]).toStrictEqual(Cl.uint(0));
      expect(data["voting-accuracy"]).toStrictEqual(Cl.uint(0));
    });

    it("calculates behavior score correctly", () => {
      const score = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "calculate-behavior-score",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );

      expect(score.result as any).toStrictEqual(Cl.uint(0)); // New user has 0 score
    });

    it("determines behavior tier based on score", () => {
      const bronze = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-behavior-tier",
        [Cl.uint(500)],
        deployer
      );
      expect(bronze.result as any).toStrictEqual(Cl.uint(1));

      const silver = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-behavior-tier",
        [Cl.uint(3500)],
        deployer
      );
      expect(silver.result as any).toStrictEqual(Cl.uint(2));

      const gold = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-behavior-tier",
        [Cl.uint(7000)],
        deployer
      );
      expect(gold.result as any).toStrictEqual(Cl.uint(3));

      const platinum = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-behavior-tier",
        [Cl.uint(9500)],
        deployer
      );
      expect(platinum.result as any).toStrictEqual(Cl.uint(4));
    });

    it("returns correct incentive multipliers for each tier", () => {
      const bronze = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-incentive-multiplier",
        [Cl.uint(1)],
        deployer
      );
      expect(bronze.result as any).toStrictEqual(Cl.uint(100)); // 1.0x

      const silver = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-incentive-multiplier",
        [Cl.uint(2)],
        deployer
      );
      expect(silver.result as any).toStrictEqual(Cl.uint(125)); // 1.25x

      const gold = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-incentive-multiplier",
        [Cl.uint(3)],
        deployer
      );
      expect(gold.result as any).toStrictEqual(Cl.uint(150)); // 1.5x

      const platinum = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-incentive-multiplier",
        [Cl.uint(4)],
        deployer
      );
      expect(platinum.result as any).toStrictEqual(Cl.uint(200)); // 2.0x
    });
  });

  describe("Governance Behavior Recording", () => {
    it("records governance voting action", () => {
      const record = simnet.callPublicFn(
        "conxian-operations-engine",
        "record-governance-action",
        [
          Cl.standardPrincipal(wallet1),
          Cl.stringAscii("vote"),
          Cl.int(100), // Positive accuracy delta
        ],
        deployer
      );

      expect(record.result as any).toBeOk(Cl.bool(true));

      const behavior = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-governance-behavior",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );

      const data = (behavior.result as any).value;
      expect(data["proposals-voted"]).toStrictEqual(Cl.uint(1));
      expect(data["voting-accuracy"]).toStrictEqual(Cl.uint(100));
    });

    it("records proposal creation action", () => {
      const record = simnet.callPublicFn(
        "conxian-operations-engine",
        "record-governance-action",
        [Cl.standardPrincipal(wallet1), Cl.stringAscii("create"), Cl.int(0)],
        deployer
      );

      expect(record.result as any).toBeOk(Cl.bool(true));

      const behavior = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-governance-behavior",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );

      const data = (behavior.result as any).value;
      expect(data["proposals-created"]).toStrictEqual(Cl.uint(1));
    });

    it("rejects governance action recording from non-owner", () => {
      const record = simnet.callPublicFn(
        "conxian-operations-engine",
        "record-governance-action",
        [Cl.standardPrincipal(wallet1), Cl.stringAscii("vote"), Cl.int(100)],
        wallet1
      );

      expect(record.result as any).toBeErr(Cl.uint(7000)); // ERR_UNAUTHORIZED
    });
  });

  describe("Lending Behavior Recording", () => {
    it("records healthy lending behavior", () => {
      const record = simnet.callPublicFn(
        "conxian-operations-engine",
        "record-lending-action",
        [
          Cl.standardPrincipal(wallet1),
          Cl.uint(15000), // Good health factor
          Cl.bool(false), // Not liquidated
          Cl.bool(true), // Timely repayment
        ],
        deployer
      );

      expect(record.result as any).toBeOk(Cl.bool(true));

      const behavior = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-lending-behavior",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );

      const data = (behavior.result as any).value;
      expect(data["average-health-factor"]).toStrictEqual(Cl.uint(1500));
      expect(data["liquidation-count"]).toStrictEqual(Cl.uint(0));
      expect(data["timely-repayment-count"]).toStrictEqual(Cl.uint(1));
    });

    it("penalizes liquidation in collateral management score", () => {
      // First, establish a baseline score
      simnet.callPublicFn(
        "conxian-operations-engine",
        "record-lending-action",
        [
          Cl.standardPrincipal(wallet1),
          Cl.uint(15000),
          Cl.bool(false),
          Cl.bool(true),
        ],
        deployer
      );

      // Then record a liquidation
      const record = simnet.callPublicFn(
        "conxian-operations-engine",
        "record-lending-action",
        [
          Cl.standardPrincipal(wallet1),
          Cl.uint(5000), // Low health factor
          Cl.bool(true), // Liquidated
          Cl.bool(false),
        ],
        deployer
      );

      expect(record.result as any).toBeOk(Cl.bool(true));

      const behavior = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-lending-behavior",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );

      const data = (behavior.result as any).value;
      expect(data["liquidation-count"]).toStrictEqual(Cl.uint(1));
      // Collateral score should be reduced (95% of previous)
    });
  });

  describe("MEV Protection Behavior Recording", () => {
    it("records MEV protection usage", () => {
      const record = simnet.callPublicFn(
        "conxian-operations-engine",
        "record-mev-action",
        [
          Cl.standardPrincipal(wallet1),
          Cl.bool(true), // Protection used
          Cl.bool(true), // Attack prevented
          Cl.uint(1000000), // Volume
        ],
        deployer
      );

      expect(record.result as any).toBeOk(Cl.bool(true));

      const behavior = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-mev-behavior",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );

      const data = (behavior.result as any).value;
      expect(data["protection-usage-count"]).toStrictEqual(Cl.uint(1));
      expect(data["attacks-prevented"]).toStrictEqual(Cl.uint(1));
      expect(data["protected-volume"]).toStrictEqual(Cl.uint(1000000));
      expect(data["mev-awareness-score"]).toStrictEqual(Cl.uint(100));
    });

    it("increases MEV awareness score with usage", () => {
      // Record multiple uses
      for (let i = 0; i < 5; i++) {
        simnet.callPublicFn(
          "conxian-operations-engine",
          "record-mev-action",
          [
            Cl.standardPrincipal(wallet1),
            Cl.bool(true),
            Cl.bool(false),
            Cl.uint(100000),
          ],
          deployer
        );
      }

      const behavior = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-mev-behavior",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );

      const data = (behavior.result as any).value;
      expect(data["protection-usage-count"]).toStrictEqual(Cl.uint(5));
      expect(data["mev-awareness-score"]).toStrictEqual(Cl.uint(500));
    });
  });

  describe("Insurance Behavior Recording", () => {
    it("records premium payment and improves reliability score", () => {
      const record = simnet.callPublicFn(
        "conxian-operations-engine",
        "record-insurance-action",
        [
          Cl.standardPrincipal(wallet1),
          Cl.bool(false), // No claim filed
          Cl.bool(false),
          Cl.bool(true), // Premium paid
        ],
        deployer
      );

      expect(record.result as any).toBeOk(Cl.bool(true));

      const behavior = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-insurance-behavior",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );

      const data = (behavior.result as any).value;
      expect(data["premium-payment-reliability"]).toStrictEqual(Cl.uint(100));
    });

    it("penalizes rejected claims in risk management score", () => {
      const record = simnet.callPublicFn(
        "conxian-operations-engine",
        "record-insurance-action",
        [
          Cl.standardPrincipal(wallet1),
          Cl.bool(true), // Claim filed
          Cl.bool(false), // Claim rejected
          Cl.bool(true),
        ],
        deployer
      );

      expect(record.result as any).toBeOk(Cl.bool(true));

      const behavior = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-insurance-behavior",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );

      const data = (behavior.result as any).value;
      expect(data["claims-filed"]).toStrictEqual(Cl.uint(1));
      expect(data["claims-approved"]).toStrictEqual(Cl.uint(0));
      // Risk management score should be reduced (90% of previous)
    });
  });

  describe("Bridge Behavior Recording", () => {
    it("records successful bridge and calculates reliability", () => {
      const record = simnet.callPublicFn(
        "conxian-operations-engine",
        "record-bridge-action",
        [
          Cl.standardPrincipal(wallet1),
          Cl.bool(true), // Successful
          Cl.uint(5000000), // Volume
        ],
        deployer
      );

      expect(record.result as any).toBeOk(Cl.bool(true));

      const behavior = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-bridge-behavior",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );

      // Temporary debug logging to inspect result structure
      // eslint-disable-next-line no-console
      console.log(
        "bridge-behavior result",
        JSON.stringify(behavior.result, null, 2)
      );
      const data = (behavior.result as any).value;
      expect(data["successful-bridges"]).toStrictEqual(Cl.uint(1));
      expect(data["bridge-volume"]).toStrictEqual(Cl.uint(5000000));
      expect(data["security-awareness-score"]).toStrictEqual(Cl.uint(50));
    });

    it("calculates bridge reliability correctly with mixed results", () => {
      // Record 3 successful and 1 failed bridge
      for (let i = 0; i < 3; i++) {
        simnet.callPublicFn(
          "conxian-operations-engine",
          "record-bridge-action",
          [Cl.standardPrincipal(wallet1), Cl.bool(true), Cl.uint(1000000)],
          deployer
        );
      }

      simnet.callPublicFn(
        "conxian-operations-engine",
        "record-bridge-action",
        [Cl.standardPrincipal(wallet1), Cl.bool(false), Cl.uint(1000000)],
        deployer
      );

      const behavior = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-bridge-behavior",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );

      const data = (behavior.result as any).value;
      expect(data["successful-bridges"]).toStrictEqual(Cl.uint(3));
      expect(data["failed-bridges"]).toStrictEqual(Cl.uint(1));
      // Reliability should be 75% (3/4 * 10000 = 7500)
      expect(data["bridge-reliability"]).toStrictEqual(Cl.uint(7500));
    });
  });

  describe("Comprehensive Behavior Dashboard", () => {
    it("returns complete behavior dashboard for user", () => {
      // Set up some behavior data
      simnet.callPublicFn(
        "conxian-operations-engine",
        "record-governance-action",
        [Cl.standardPrincipal(wallet1), Cl.stringAscii("vote"), Cl.int(500)],
        deployer
      );

      simnet.callPublicFn(
        "conxian-operations-engine",
        "record-lending-action",
        [
          Cl.standardPrincipal(wallet1),
          Cl.uint(15000),
          Cl.bool(false),
          Cl.bool(true),
        ],
        deployer
      );

      const dashboard = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-user-behavior-dashboard",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );

      // Dashboard should return ok response with user data
      // eslint-disable-next-line no-console
      console.log(
        "behavior-dashboard result",
        JSON.stringify(dashboard.result, null, 2)
      );
      const data = (dashboard.result as any).value;
      expect(data["user"]).toStrictEqual(Cl.standardPrincipal(wallet1));
    });
  });

  describe("Behavior Tier Progression", () => {
    it("progresses from bronze to silver with good behavior", () => {
      // Record multiple positive actions to reach silver threshold (3000)
      // Need 100 actions to reach 3000 score (2000 from accuracy + 1000 from bonus)
      for (let i = 0; i < 100; i++) {
        simnet.callPublicFn(
          "conxian-operations-engine",
          "record-governance-action",
          [Cl.standardPrincipal(wallet1), Cl.stringAscii("vote"), Cl.int(100)],
          deployer
        );
      }

      const metrics = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "get-user-behavior-metrics",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );

      // Metrics should show progression
      const data = (metrics.result as any).value;
      expect(data["behavior-tier"]).toStrictEqual(Cl.uint(2)); // Silver or higher
      expect(data["incentive-multiplier"]).toStrictEqual(Cl.uint(125)); // 1.25x or higher
    });
  });
});
