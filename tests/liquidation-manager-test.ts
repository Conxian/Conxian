import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

// Contract names
const CONTRACTS = {
  LIQUIDATION_MANAGER: 'loan-liquidation-manager',
  LENDING_SYSTEM: 'comprehensive-lending-system',
  TOKEN_A: 'token-a',
  TOKEN_B: 'token-b',
  ORACLE: 'oracle'
};

// Standard error codes from error-codes.md
const ERRORS = {
  UNAUTHORIZED: 1002,
  ASSET_NOT_WHITELISTED: 1008,
  INSUFFICIENT_COLLATERAL: 1009,
  POSITION_NOT_UNDERWATER: 1004,
  SLIPPAGE_TOO_HIGH: 1005,
  INVALID_AMOUNT: 1003,
  LIQUIDATION_PAUSED: 1001,
  PRICE_STALE: 4000
};

// Helper functions
const setupTestEnvironment = (chain: Chain, accounts: Map<string, Account>) => {
  const deployer = accounts.get('deployer')!;
  const liquidator = accounts.get('wallet_1')!;
  const borrower = accounts.get('wallet_2')!;
  
  // Initialize contracts and set up test environment
  const setupBlock = chain.mineBlock([
    // Set up lending system
    Tx.contractCall(
      CONTRACTS.LIQUIDATION_MANAGER,
      'set-lending-system-contract',
      [types.principal(`${deployer.address}.${CONTRACTS.LENDING_SYSTEM}`)],
      deployer.address
    ),
    
    // Whitelist assets
    Tx.contractCall(
      CONTRACTS.LIQUIDATION_MANAGER,
      'whitelist-asset',
      [types.principal(`${deployer.address}.${CONTRACTS.TOKEN_A}`), types.bool(true)],
      deployer.address
    ),
    
    Tx.contractCall(
      CONTRACTS.LIQUIDATION_MANAGER,
      'whitelist-asset',
      [types.principal(`${deployer.address}.${CONTRACTS.TOKEN_B}`), types.bool(true)],
      deployer.address
    ),
    
    // Set up test position (simplified for example)
    // In a real test, you'd need to set up actual lending positions
    // with proper collateral and debt
  ]);
  
  return { deployer, liquidator, borrower, setupBlock };
};

// Test Suite 1: Contract Initialization and Admin Functions
Clarinet.test({
  name: 'Liquidation Manager - Contract Initialization',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const { deployer, liquidator } = setupTestEnvironment(chain, accounts);
    
    // Test admin-only functions
    const setLendingSystemCall = Tx.contractCall(
      CONTRACTS.LIQUIDATION_MANAGER,
      'set-lending-system-contract',
      [types.principal(`${deployer.address}.${CONTRACTS.LENDING_SYSTEM}`)],
      deployer.address
    );
    
    // Should fail if not called by admin
    const notAdminResult = chain.mineBlock([
      setLendingSystemCall.clone().sender(liquidator.address)
    ]);
    notAdminResult.receipts[0].result.expectErr().expectUint(ERRORS.UNAUTHORIZED);
    
    // Should succeed when called by admin
    const adminResult = chain.mineBlock([setLendingSystemCall]);
    adminResult.receipts[0].result.expectOk().expectBool(true);
    
    // Test pausing functionality
    const pauseResult = chain.mineBlock([
      Tx.contractCall(
        CONTRACTS.LIQUIDATION_MANAGER,
        'set-liquidation-paused',
        [types.bool(true)],
        deployer.address
      )
    ]);
    pauseResult.receipts[0].result.expectOk().expectBool(true);
  }
});

// Test Suite 2: Liquidation Scenarios
Clarinet.test({
  name: 'Liquidation Manager - Standard Liquidation',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const { deployer, liquidator, borrower } = setupTestEnvironment(chain, accounts);
    
    // Set up test position with collateral and debt
    // This is simplified - in a real test you'd need to set up actual positions
    // with proper collateralization ratios
    
    // Test liquidation of undercollateralized position
    const liquidationTx = Tx.contractCall(
      CONTRACTS.LIQUIDATION_MANAGER,
      'liquidate-position',
      [
        types.principal(borrower.address),
        types.contractPrincipal(deployer.address, CONTRACTS.TOKEN_A),
        types.contractPrincipal(deployer.address, CONTRACTS.TOKEN_B),
        types.uint(1000000), // debt amount (with decimals)
        types.uint(2000000)  // max collateral to seize (with decimals)
      ],
      liquidator.address
    );
    
    const result = chain.mineBlock([liquidationTx]);
    result.receipts[0].result.expectOk();
    
    // Verify events were emitted
    const events = result.receipts[0].events;
    assertEquals(events.length > 0, true, 'Should emit events');
    
    // Check state changes
    // In a real test, you'd verify:
    // - Debt was repaid
    // - Collateral was seized
    // - Position was updated
    // - System state was updated
  }
});

// Test Suite 3: Error Conditions
Clarinet.test({
  name: 'Liquidation Manager - Error Handling',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const { deployer, liquidator, borrower } = setupTestEnvironment(chain, accounts);
    
    // Test 1: Non-whitelisted asset
    const nonWhitelistedAsset = 'non-whitelisted-token';
    const whitelistResult = chain.mineBlock([
      Tx.contractCall(
        CONTRACTS.LIQUIDATION_MANAGER,
        'liquidate-position',
        [
          types.principal(borrower.address),
          types.principal(`${deployer.address}.${nonWhitelistedAsset}`),
          types.principal(`${deployer.address}.${CONTRACTS.TOKEN_B}`),
          types.uint(1000),
          types.uint(2000)
        ],
        liquidator.address
      )
    ]);
    whitelistResult.receipts[0].result.expectErr().expectUint(ERRORS.ASSET_NOT_WHITELISTED);
    
    // Test 2: Insufficient collateral
    // This would require setting up a position with insufficient collateral first
    
    // Test 3: Position not underwater
    const notUnderwaterResult = chain.mineBlock([
      Tx.contractCall(
        CONTRACTS.LIQUIDATION_MANAGER,
        'liquidate-position',
        [
          types.principal(borrower.address),
          types.principal(`${deployer.address}.${CONTRACTS.TOKEN_A}`),
          types.principal(`${deployer.address}.${CONTRACTS.TOKEN_B}`),
          types.uint(1000),
          types.uint(2000)
        ],
        liquidator.address
      )
    ]);
    notUnderwaterResult.receipts[0].result.expectErr().expectUint(ERRORS.POSITION_NOT_UNDERWATER);
  }
});

// Test Suite 4: Edge Cases
Clarinet.test({
  name: 'Liquidation Manager - Edge Cases',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const { deployer, liquidator, borrower } = setupTestEnvironment(chain, accounts);
    
    // Test 1: Zero amount
    const zeroAmountResult = chain.mineBlock([
      Tx.contractCall(
        CONTRACTS.LIQUIDATION_MANAGER,
        'liquidate-position',
        [
          types.principal(borrower.address),
          types.principal(`${deployer.address}.${CONTRACTS.TOKEN_A}`),
          types.principal(`${deployer.address}.${CONTRACTS.TOKEN_B}`),
          types.uint(0),  // Zero amount
          types.uint(2000)
        ],
        liquidator.address
      )
    ]);
    zeroAmountResult.receipts[0].result.expectErr().expectUint(ERRORS.INVALID_AMOUNT);
    
    // Test 2: Maximum uint values
    // This would test for potential overflow scenarios
    
    // Test 3: Partial liquidation
    // Test that partial liquidation works correctly
  }
});

// Test Suite 5: Emergency Functions
Clarinet.test({
  name: 'Liquidation Manager - Emergency Functions',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const { deployer, liquidator, borrower } = setupTestEnvironment(chain, accounts);
    
    // Test that only admin can call emergency functions
    const emergencyCall = Tx.contractCall(
      CONTRACTS.LIQUIDATION_MANAGER,
      'emergency-liquidate',
      [
        types.principal(borrower.address),
        types.principal(`${deployer.address}.${CONTRACTS.TOKEN_A}`),
        types.principal(`${deployer.address}.${CONTRACTS.TOKEN_B}`)
      ],
      liquidator.address  // Not admin, should fail
    );
    
    const nonAdminResult = chain.mineBlock([emergencyCall]);
    nonAdminResult.receipts[0].result.expectErr().expectUint(ERRORS.UNAUTHORIZED);
    
    // Test successful emergency liquidation by admin
    const adminEmergencyCall = emergencyCall.clone().sender(deployer.address);
    const adminResult = chain.mineBlock([adminEmergencyCall]);
    // In a real test, you'd expect this to succeed for an admin
    // adminResult.receipts[0].result.expectOk();
  }
});
