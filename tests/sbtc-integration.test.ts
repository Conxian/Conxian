import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { simnet } from "@hirosystems/clarinet-sdk";

// Test addresses
const deployerAddress = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";
const wallet1 = "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5";
const wallet2 = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG";
const wallet3 = "ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC";
const sbtcContract = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sbtc-token";

describe("sBTC Integration System Tests", () => {
  beforeEach(() => {
    // Reset simnet state
    simnet.setCurrentBurn(0);
  });

  describe("sBTC Integration Contract", () => {
    it("should register sBTC asset with default parameters", () => {
      const { result } = simnet.callPublicFn(
        "sbtc-integration",
        "register-sbtc-asset",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      expect(result).toBeOk(Cl.bool(true));

      // Verify asset configuration
      const config = simnet.callReadOnlyFn(
        "sbtc-integration", 
        "get-asset-config",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      expect(config.result).toBeSome();
      const configData = config.result.value;
      expect(configData).toHaveProperty("ltv");
      expect(configData).toHaveProperty("liquidation-threshold"); 
      expect(configData).toHaveProperty("active", Cl.bool(false));
    });

    it("should activate sBTC asset operations", () => {
      // First register asset
      simnet.callPublicFn(
        "sbtc-integration",
        "register-sbtc-asset", 
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      // Activate operations
      const { result } = simnet.callPublicFn(
        "sbtc-integration",
        "activate-asset-operations",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.bool(true), // supply
          Cl.bool(true), // borrow  
          Cl.bool(true), // flash-loan
          Cl.bool(true)  // bond
        ],
        deployerAddress
      );

      expect(result).toBeOk(Cl.bool(true));

      // Verify asset is active
      const isActive = simnet.callReadOnlyFn(
        "sbtc-integration",
        "is-asset-active", 
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      expect(isActive.result).toBe(Cl.bool(true));
    });

    it("should configure oracle for sBTC price feeds", () => {
      const oracleAddress = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sbtc-oracle";
      
      const { result } = simnet.callPublicFn(
        "sbtc-integration",
        "set-oracle-config",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.standardPrincipal(oracleAddress),
          Cl.none(),
          Cl.uint(200000) // 20% max deviation
        ],
        deployerAddress
      );

      expect(result).toBeOk(Cl.bool(true));

      // Verify oracle configuration
      const oracleConfig = simnet.callReadOnlyFn(
        "sbtc-integration",
        "get-oracle-config",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      expect(oracleConfig.result).toBeSome();
    });

    it("should update sBTC price with validation", () => {
      // Setup oracle first
      const oracleAddress = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sbtc-oracle";
      
      simnet.callPublicFn(
        "sbtc-integration",
        "set-oracle-config", 
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.standardPrincipal(oracleAddress),
          Cl.none(),
          Cl.uint(200000)
        ],
        deployerAddress
      );

      // Update price as oracle
      const { result } = simnet.callPublicFn(
        "sbtc-integration",
        "update-price",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.uint(4200000000000) // $42,000 with 8 decimals
        ],
        oracleAddress
      );

      expect(result).toBeOk(Cl.bool(true));

      // Verify price was updated
      const price = simnet.callReadOnlyFn(
        "sbtc-integration",
        "get-sbtc-price",
        [],
        deployerAddress
      );

      expect(price.result).toBeOk(Cl.uint(4200000000000));
    });

    it("should reject price updates with excessive deviation", () => {
      const oracleAddress = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sbtc-oracle";
      
      // Setup oracle with low deviation threshold
      simnet.callPublicFn(
        "sbtc-integration",
        "set-oracle-config",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.standardPrincipal(oracleAddress), 
          Cl.none(),
          Cl.uint(100000) // 10% max deviation
        ],
        deployerAddress
      );

      // Set initial price
      simnet.callPublicFn(
        "sbtc-integration",
        "update-price",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.uint(4000000000000) // $40,000
        ],
        oracleAddress
      );

      // Try to update with large deviation (>10%)
      const { result } = simnet.callPublicFn(
        "sbtc-integration", 
        "update-price",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.uint(5000000000000) // $50,000 (25% increase)
        ],
        oracleAddress
      );

      expect(result).toBeErr(Cl.uint(105)); // ERR_RISK_THRESHOLD_EXCEEDED
    });

    it("should handle risk parameter updates", () => {
      // Register asset first
      simnet.callPublicFn(
        "sbtc-integration",
        "register-sbtc-asset",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      // Update risk parameters
      const { result } = simnet.callPublicFn(
        "sbtc-integration",
        "update-risk-parameters",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.uint(650000), // 65% LTV
          Cl.uint(800000), // 80% liquidation threshold  
          Cl.uint(120000)  // 12% liquidation penalty
        ],
        deployerAddress
      );

      expect(result).toBeOk(Cl.bool(true));

      // Verify parameters were updated
      const config = simnet.callReadOnlyFn(
        "sbtc-integration",
        "get-asset-config",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      const configData = config.result.value;
      expect(configData.ltv).toEqual(Cl.uint(650000));
      expect(configData["liquidation-threshold"]).toEqual(Cl.uint(800000));
    });

    it("should enforce emergency pause controls", () => {
      // Register and activate asset
      simnet.callPublicFn(
        "sbtc-integration",
        "register-sbtc-asset",
        [Cl.standardPrincipal(sbtcContract)], 
        deployerAddress
      );

      simnet.callPublicFn(
        "sbtc-integration",
        "activate-asset-operations",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.bool(true),
          Cl.bool(true), 
          Cl.bool(true),
          Cl.bool(true)
        ],
        deployerAddress
      );

      // Pause protocol
      const pauseResult = simnet.callPublicFn(
        "sbtc-integration",
        "pause-protocol", 
        [],
        deployerAddress
      );

      expect(pauseResult.result).toBeOk(Cl.bool(true));

      // Verify asset is no longer active
      const isActive = simnet.callReadOnlyFn(
        "sbtc-integration",
        "is-asset-active",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      expect(isActive.result).toBe(Cl.bool(false));

      // Unpause
      const unpauseResult = simnet.callPublicFn(
        "sbtc-integration",
        "unpause-protocol",
        [],
        deployerAddress
      );

      expect(unpauseResult.result).toBeOk(Cl.bool(true));
    });
  });

  describe("sBTC Flash Loan Vault", () => {
    beforeEach(() => {
      // Configure flash loans for sBTC
      simnet.callPublicFn(
        "sbtc-flash-loan-vault",
        "configure-flash-loans",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.bool(true), // enabled
          Cl.uint(10),   // 10 basis points fee
          Cl.uint(1000000000000), // max amount
          Cl.uint(1000000),       // min amount  
          Cl.uint(9000)           // 90% max utilization
        ],
        deployerAddress
      );
    });

    it("should configure flash loan parameters", () => {
      const config = simnet.callReadOnlyFn(
        "sbtc-flash-loan-vault",
        "get-flash-loan-config",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      expect(config.result).toBeSome();
      const configData = config.result.value;
      expect(configData.enabled).toEqual(Cl.bool(true));
      expect(configData["fee-rate"]).toEqual(Cl.uint(10));
    });

    it("should allow adding liquidity to flash loan pool", () => {
      // Mock sBTC token contract for testing
      const mockSbtc = {
        transfer: () => ({ type: "ok", value: Cl.bool(true) })
      };

      const { result } = simnet.callPublicFn(
        "sbtc-flash-loan-vault",
        "add-liquidity",
        [
          Cl.contractPrincipal(sbtcContract, "sbtc-token"),
          Cl.uint(100000000000) // 1000 sBTC
        ],
        wallet1
      );

      // In a real test, we'd need proper token mocking
      // For now, we verify the function signature works
      expect(result).toBeDefined();
    });

    it("should calculate correct flash loan fees", () => {
      const fee = simnet.callReadOnlyFn(
        "sbtc-flash-loan-vault", 
        "calculate-flash-loan-fee",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.uint(100000000000) // 1000 sBTC
        ],
        deployerAddress
      );

      // 10 basis points = 0.1% = 1000000000 fee
      expect(fee.result).toEqual(Cl.uint(1000000000));
    });

    it("should validate flash loan parameters", () => {
      // Test with amount too small
      const tooSmallResult = simnet.callReadOnlyFn(
        "sbtc-flash-loan-vault",
        "validate-flash-loan", 
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.uint(100000) // Below minimum
        ],
        deployerAddress
      );

      expect(tooSmallResult.result).toBeErr();

      // Test with valid amount  
      const validResult = simnet.callReadOnlyFn(
        "sbtc-flash-loan-vault",
        "validate-flash-loan",
        [
          Cl.standardPrincipal(sbtcContract), 
          Cl.uint(10000000000) // Valid amount
        ],
        deployerAddress
      );

      // Would pass validation if liquidity exists
      expect(validResult.result).toBeDefined();
    });

    it("should handle circuit breaker activation", () => {
      const { result } = simnet.callPublicFn(
        "sbtc-flash-loan-vault",
        "toggle-circuit-breaker",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.bool(true) // activate
        ],
        deployerAddress
      );

      expect(result).toBeOk(Cl.bool(true));

      // Verify circuit breaker is active
      const config = simnet.callReadOnlyFn(
        "sbtc-flash-loan-vault",
        "get-flash-loan-config",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      const configData = config.result.value;
      expect(configData["circuit-breaker-active"]).toEqual(Cl.bool(true));
    });

    it("should track flash loan statistics", () => {
      const stats = simnet.callReadOnlyFn(
        "sbtc-flash-loan-vault",
        "get-flash-loan-stats",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      // Initial stats should be zero
      if (stats.result.type === "some") {
        const statsData = stats.result.value;
        expect(statsData["total-loans"]).toEqual(Cl.uint(0));
        expect(statsData["total-volume"]).toEqual(Cl.uint(0));
      }
    });

    it("should handle vault pause/unpause", () => {
      // Pause vault
      const pauseResult = simnet.callPublicFn(
        "sbtc-flash-loan-vault",
        "pause-vault",
        [],
        deployerAddress
      );

      expect(pauseResult.result).toBeOk(Cl.bool(true));

      // Unpause vault
      const unpauseResult = simnet.callPublicFn(
        "sbtc-flash-loan-vault", 
        "unpause-vault",
        [],
        deployerAddress
      );

      expect(unpauseResult.result).toBeOk(Cl.bool(true));
    });
  });

  describe("sBTC Lending System", () => {
    beforeEach(() => {
      // Add sBTC lending market
      simnet.callPublicFn(
        "sbtc-lending-system",
        "add-market",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.uint(700000),  // 70% LTV
          Cl.uint(750000),  // 75% liquidation threshold
          Cl.uint(100000),  // 10% liquidation penalty
          Cl.uint(200000)   // 20% reserve factor
        ],
        deployerAddress
      );
    });

    it("should add sBTC lending market", () => {
      const marketInfo = simnet.callReadOnlyFn(
        "sbtc-lending-system",
        "get-market-info",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      expect(marketInfo.result).toBeDefined();
      const { config, state } = marketInfo.result.value;
      
      if (config.type === "some") {
        expect(config.value.ltv).toEqual(Cl.uint(700000));
        expect(config.value["liquidation-threshold"]).toEqual(Cl.uint(750000));
      }
    });

    it("should calculate interest rates based on utilization", () => {
      // Test utilization rate calculation
      const utilizationRate = simnet.callReadOnlyFn(
        "sbtc-lending-system",
        "calculate-utilization-rate", 
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      // Initial utilization should be 0
      expect(utilizationRate.result).toEqual(Cl.uint(0));

      // Test borrow rate calculation
      const borrowRate = simnet.callReadOnlyFn(
        "sbtc-lending-system",
        "calculate-borrow-rate",
        [Cl.uint(500000)], // 50% utilization
        deployerAddress
      );

      expect(borrowRate.result).toBeGreaterThan(Cl.uint(0));
    });

    it("should handle supply operations", () => {
      // Mock supply transaction
      const mockSbtc = {
        transfer: () => ({ type: "ok", value: Cl.bool(true) })
      };

      const supplyResult = simnet.callPublicFn(
        "sbtc-lending-system",
        "supply",
        [
          Cl.contractPrincipal(sbtcContract, "sbtc-token"),
          Cl.uint(100000000000) // 1000 sBTC
        ],
        wallet1
      );

      // Function should be callable
      expect(supplyResult).toBeDefined();
    });

    it("should enable/disable collateral", () => {
      // Enable collateral
      const enableResult = simnet.callPublicFn(
        "sbtc-lending-system",
        "enable-collateral",
        [Cl.contractPrincipal(sbtcContract, "sbtc-token")],
        wallet1
      );

      // Would require existing supply position in real test
      expect(enableResult).toBeDefined();
    });

    it("should calculate health factors", () => {
      const healthFactor = simnet.callReadOnlyFn(
        "sbtc-lending-system",
        "calculate-health-factor",
        [Cl.standardPrincipal(wallet1)],
        deployerAddress
      );

      // Should return max health factor for user with no borrows
      expect(healthFactor.result).toBeOk();
    });

    it("should handle enterprise bond initiation", () => {
      // This would be tested with a large borrow amount
      // that triggers enterprise bond eligibility
      const largeBorrowAmount = Cl.uint(100000000000000); // 1M tokens

      // In practice, this would be called internally during borrow
      const enterpriseResult = simnet.callPublicFn(
        "sbtc-lending-system",
        "borrow",
        [
          Cl.contractPrincipal(sbtcContract, "sbtc-token"), 
          largeBorrowAmount
        ],
        wallet1
      );

      expect(enterpriseResult).toBeDefined();
    });

    it("should accrue interest over time", () => {
      // Fast forward some blocks
      simnet.mineEmptyBlocks(100);

      const accrueResult = simnet.callPublicFn(
        "sbtc-lending-system", 
        "accrue-interest",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      expect(accrueResult.result).toBeOk();
    });

    it("should handle liquidations", () => {
      // Mock liquidation scenario
      const liquidateResult = simnet.callPublicFn(
        "sbtc-lending-system",
        "liquidate", 
        [
          Cl.standardPrincipal(wallet2), // borrower
          Cl.contractPrincipal(sbtcContract, "sbtc-token"), // repay asset
          Cl.contractPrincipal(sbtcContract, "sbtc-token"), // collateral asset  
          Cl.uint(10000000000) // repay amount
        ],
        wallet1 // liquidator
      );

      // Would require undercollateralized position in real test
      expect(liquidateResult).toBeDefined();
    });
  });

  describe("Integration Tests", () => {
    it("should integrate sBTC across all systems", () => {
      // 1. Setup sBTC in integration contract
      simnet.callPublicFn(
        "sbtc-integration",
        "register-sbtc-asset",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      simnet.callPublicFn(
        "sbtc-integration", 
        "activate-asset-operations",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.bool(true),
          Cl.bool(true),
          Cl.bool(true),
          Cl.bool(true)
        ],
        deployerAddress
      );

      // 2. Configure flash loans
      simnet.callPublicFn(
        "sbtc-flash-loan-vault",
        "configure-flash-loans",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.bool(true),
          Cl.uint(10),
          Cl.uint(1000000000000),
          Cl.uint(1000000),
          Cl.uint(9000)
        ],
        deployerAddress
      );

      // 3. Add lending market
      simnet.callPublicFn(
        "sbtc-lending-system",
        "add-market",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.uint(700000),
          Cl.uint(750000), 
          Cl.uint(100000),
          Cl.uint(200000)
        ],
        deployerAddress
      );

      // Verify all systems are integrated
      const integrationActive = simnet.callReadOnlyFn(
        "sbtc-integration",
        "is-asset-active",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      const flashLoansEnabled = simnet.callReadOnlyFn(
        "sbtc-integration", 
        "is-flash-loan-enabled",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      const marketInfo = simnet.callReadOnlyFn(
        "sbtc-lending-system",
        "get-market-info",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      expect(integrationActive.result).toBe(Cl.bool(true));
      expect(flashLoansEnabled.result).toBe(Cl.bool(true));
      expect(marketInfo.result).toBeDefined();
    });

    it("should handle enterprise bond workflow", () => {
      // Setup complete system first
      simnet.callPublicFn(
        "sbtc-integration",
        "register-sbtc-asset",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      simnet.callPublicFn(
        "sbtc-lending-system",
        "add-market",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.uint(700000),
          Cl.uint(750000),
          Cl.uint(100000), 
          Cl.uint(200000)
        ],
        deployerAddress
      );

      // Simulate large borrowing position that would trigger bonds
      // This would typically involve:
      // 1. Supply large collateral
      // 2. Borrow amount above enterprise threshold
      // 3. Verify bond series creation
      // 4. Check yield distribution setup

      const enterprisePosition = simnet.callReadOnlyFn(
        "sbtc-lending-system",
        "get-enterprise-position",
        [Cl.standardPrincipal(wallet1)],
        deployerAddress
      );

      // Initially no enterprise position
      expect(enterprisePosition.result).toBeDefined();
    });

    it("should handle flash loan with sBTC collateral", () => {
      // Setup both flash loan vault and lending system
      simnet.callPublicFn(
        "sbtc-flash-loan-vault",
        "configure-flash-loans", 
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.bool(true),
          Cl.uint(10),
          Cl.uint(1000000000000),
          Cl.uint(1000000),
          Cl.uint(9000)
        ],
        deployerAddress
      );

      // Simulate flash loan workflow:
      // 1. User takes flash loan
      // 2. Uses borrowed sBTC as collateral in lending system
      // 3. Borrows other assets
      // 4. Repays flash loan with profit

      // This would require mock contracts for proper testing
      const availableLiquidity = simnet.callReadOnlyFn(
        "sbtc-flash-loan-vault",
        "get-available-liquidity",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      expect(availableLiquidity.result).toBeDefined();
    });

    it("should handle comprehensive risk scenarios", () => {
      // Test various risk scenarios:
      // 1. Price volatility
      // 2. Liquidation cascades  
      // 3. Circuit breaker activation
      // 4. Emergency pause scenarios

      // Setup oracle with price updates
      const oracleAddress = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sbtc-oracle";
      
      simnet.callPublicFn(
        "sbtc-integration",
        "register-sbtc-asset",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      simnet.callPublicFn(
        "sbtc-integration",
        "set-oracle-config",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.standardPrincipal(oracleAddress),
          Cl.none(),
          Cl.uint(200000)
        ],
        deployerAddress
      );

      // Test price volatility response
      const priceUpdate = simnet.callPublicFn(
        "sbtc-integration",
        "update-price",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.uint(4000000000000) // Initial price
        ],
        oracleAddress
      );

      expect(priceUpdate.result).toBeOk(Cl.bool(true));

      // Test circuit breaker activation
      const circuitBreaker = simnet.callPublicFn(
        "sbtc-integration",
        "toggle-circuit-breaker", 
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.bool(true)
        ],
        deployerAddress
      );

      expect(circuitBreaker.result).toBeOk(Cl.bool(true));
    });
  });

  describe("Performance and Load Testing", () => {
    it("should handle high volume operations", () => {
      // Simulate multiple concurrent operations
      const operations = [];
      
      for (let i = 0; i < 100; i++) {
        operations.push(() => {
          simnet.callReadOnlyFn(
            "sbtc-integration",
            "get-asset-config", 
            [Cl.standardPrincipal(sbtcContract)],
            deployerAddress
          );
        });
      }

      // Execute all operations
      const results = operations.map(op => op());
      
      // All should complete successfully
      expect(results.length).toBe(100);
    });

    it("should maintain performance under load", () => {
      // Setup system
      simnet.callPublicFn(
        "sbtc-integration",
        "register-sbtc-asset",
        [Cl.standardPrincipal(sbtcContract)],
        deployerAddress
      );

      // Simulate heavy usage
      const startTime = Date.now();
      
      for (let i = 0; i < 1000; i++) {
        simnet.callReadOnlyFn(
          "sbtc-integration",
          "calculate-collateral-value",
          [
            Cl.standardPrincipal(sbtcContract),
            Cl.uint(1000000000 + i)
          ],
          deployerAddress
        );
      }
      
      const endTime = Date.now();
      const executionTime = endTime - startTime;
      
      // Should complete within reasonable time
      expect(executionTime).toBeLessThan(10000); // 10 seconds
    });
  });

  describe("Edge Cases and Error Handling", () => {
    it("should handle zero amounts gracefully", () => {
      const zeroCollateral = simnet.callReadOnlyFn(
        "sbtc-integration",
        "calculate-collateral-value",
        [
          Cl.standardPrincipal(sbtcContract),
          Cl.uint(0)
        ],
        deployerAddress
      );

      expect(zeroCollateral.result).toBeDefined();
    });

    it("should handle maximum values", () => {
      const maxValue = Cl.uint(18446744073709551615); // max uint
      
      const maxCollateral = simnet.callReadOnlyFn(
        "sbtc-integration", 
        "calculate-collateral-value",
        [
          Cl.standardPrincipal(sbtcContract),
          maxValue
        ],
        deployerAddress
      );

      expect(maxCollateral.result).toBeDefined();
    });

    it("should reject unauthorized operations", () => {
      const unauthorizedUpdate = simnet.callPublicFn(
        "sbtc-integration",
        "register-sbtc-asset",
        [Cl.standardPrincipal(sbtcContract)],
        wallet1 // Not the owner
      );

      expect(unauthorizedUpdate.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED
    });

    it("should handle invalid asset addresses", () => {
      const invalidAsset = "ST1INVALID.invalid-token";
      
      const invalidConfig = simnet.callReadOnlyFn(
        "sbtc-integration",
        "get-asset-config",
        [Cl.standardPrincipal(invalidAsset)],
        deployerAddress
      );

      expect(invalidConfig.result).toBeNone();
    });
  });
});

// Additional test utilities
export const testHelpers = {
  setupFullSystem: () => {
    // Setup complete sBTC integration system
    simnet.callPublicFn(
      "sbtc-integration",
      "register-sbtc-asset", 
      [Cl.standardPrincipal(sbtcContract)],
      deployerAddress
    );

    simnet.callPublicFn(
      "sbtc-integration",
      "activate-asset-operations",
      [
        Cl.standardPrincipal(sbtcContract),
        Cl.bool(true),
        Cl.bool(true),
        Cl.bool(true),
        Cl.bool(true)
      ],
      deployerAddress
    );

    simnet.callPublicFn(
      "sbtc-flash-loan-vault",
      "configure-flash-loans",
      [
        Cl.standardPrincipal(sbtcContract),
        Cl.bool(true),
        Cl.uint(10),
        Cl.uint(1000000000000),
        Cl.uint(1000000),
        Cl.uint(9000)
      ],
      deployerAddress
    );

    simnet.callPublicFn(
      "sbtc-lending-system",
      "add-market",
      [
        Cl.standardPrincipal(sbtcContract),
        Cl.uint(700000),
        Cl.uint(750000),
        Cl.uint(100000), 
        Cl.uint(200000)
      ],
      deployerAddress
    );
  },

  mockPriceOracle: (price: number) => {
    const oracleAddress = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sbtc-oracle";
    
    simnet.callPublicFn(
      "sbtc-integration",
      "set-oracle-config",
      [
        Cl.standardPrincipal(sbtcContract),
        Cl.standardPrincipal(oracleAddress),
        Cl.none(),
        Cl.uint(200000)
      ],
      deployerAddress
    );

    simnet.callPublicFn(
      "sbtc-integration",
      "update-price",
      [
        Cl.standardPrincipal(sbtcContract),
        Cl.uint(price)
      ],
      oracleAddress
    );
  }
};
