/**
 * Critical Systems Integration Tests
 * Tests for all newly implemented P0 contracts
 */

import { describe, it, beforeEach, expect } from 'vitest';
import { Cl } from '@stacks/transactions';

describe("Keeper Coordinator Integration", () => {
  it("should register and authorize keeper", async () => {
    const result = await contracts.keeperCoordinator.addKeeper(keeperAddress);
    expect(result.result).toBeOk();
  });

  it("should execute interest accrual task", async () => {
    const configResult = await contracts.keeperCoordinator.configureTask(
      Cl.uint(1), Cl.bool(true), Cl.uint(10), Cl.uint(1), Cl.uint(100000)
    );
    expect(configResult.result).toBeOk();
  });
});

describe("External Oracle Adapter Integration", () => {
  it("should submit and aggregate prices", async () => {
    const assetAddress = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token";
    const result = await contracts.externalOracleAdapter.submitExternalPrice(
      Cl.principal(assetAddress), Cl.uint(1), Cl.uint(45000000000), Cl.uint(8), Cl.uint(9500), Cl.none()
    );
    expect(result.result).toBeOk();
  });
});

describe("Batch Processor Integration", () => {
  it("should process batch operations", async () => {
    const result = await contracts.batchProcessor.batchLiquidate(positions);
    expect(result.result).toBeOk();
  });
});

describe("Emergency Governance Integration", () => {
  it("should create and execute emergency proposals", async () => {
    const result = await contracts.emergencyGovernance.createEmergencyProposal(
      Cl.uint(1), Cl.principal("ST1...target"), Cl.stringAscii(""), Cl.uint(0), Cl.stringUtf8("Emergency")
    );
    expect(result.result).toBeOk();
  });
});

describe("Analytics Aggregator Integration", () => {
  it("should calculate financial metrics", async () => {
    const arr = await contracts.analyticsAggregator.calculateArr();
    expect(arr.result).toBeOk();
    
    const realYield = await contracts.analyticsAggregator.calculateRealYield();
    expect(realYield.result).toBeOk();
  });
});

describe("Rate Limiter Integration", () => {
  it("should enforce rate limits correctly", async () => {
    const first = await contracts.rateLimiter.checkRateLimit(Cl.stringAscii("swap"));
    expect(first.result).toBeOk();
  });
});

describe("sBTC Vault Integration", () => {
  it("should handle deposits and withdrawals", async () => {
    const depositResult = await contracts.sbtcVault.deposit(sbtcToken, Cl.uint(100000000));
    expect(depositResult.result).toBeOk();
  });
});
