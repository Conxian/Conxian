import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@0.31.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.125.0/testing/asserts.ts';
import { setupTestEnv } from './test-setup.ts';

// Core Dimensional Engine Tests
Clarinet.test({
  name: 'Dimensional Core: Open and manage positions',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const { dimensionalCore, mockToken, wallet1 } = setupTestEnv(chain, accounts);
    
    // Fund wallet1 with mock tokens
    const mintAmount = 1000_000000; // 1000 tokens with 6 decimals
    chain.mineBlock([
      Tx.contractCall(
        mockToken,
        'mint',
        [types.principal(wallet1.address), types.uint(mintAmount)],
        wallet1.address
      )
    ]);
    
    // Deposit funds into the dimensional engine
    chain.mineBlock([
      Tx.contractCall(
        dimensionalCore,
        'deposit-funds',
        [types.uint(mintAmount), types.principal(mockToken)],
        wallet1.address
      )
    ]);

    // Create a new position
    const openPosition = chain.mineBlock([
      Tx.contractCall(
        dimensionalCore,
        'create-position',
        [
          types.principal(wallet1.address),
          types.uint(100000000),      // collateral-amount
          types.uint(1000),           // leverage
          types.ascii("long"),        // pos-type
          types.principal(mockToken), // token
          types.uint(100),            // slippage-tolerance
          types.ascii("hourly")       // funding-int
        ],
        wallet1.address
      )
    ]);
    
    // Verify position was created
    assertEquals(openPosition.receipts[0].result, '(ok u1)');
    
    // Check position details
    const positionId = 1;
    const position = chain.callReadOnlyFn(
      dimensionalCore,
      'get-position',
      [types.principal(wallet1.address), types.uint(positionId)],
      wallet1.address
    );
    
    assertEquals(position.result.expectSome().collateral, types.uint(100_0000));
    assertEquals(position.result.expectSome().size, types.int(1000_0000)); // 100 * 10x
  }
});

// Risk Management Tests
Clarinet.test({
  name: 'Risk Engine: Position health and liquidation',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const { 
      dimensionalCore, 
      riskOracle, 
      liquidationEngine, 
      mockToken, 
      wallet1, 
      wallet2 
    } = setupTestEnv(chain, accounts);
    
    // Setup initial position (similar to previous test)
    const mintAmount = 1000_0000;
    chain.mineBlock([
      Tx.contractCall(mockToken, 'mint', [types.principal(wallet1.address), types.uint(mintAmount)], wallet1.address),
      Tx.contractCall(mockToken, 'approve', [types.principal(dimensionalCore), types.uint(mintAmount)], wallet1.address),
      Tx.contractCall(
        dimensionalCore,
        'open-position',
        [types.uint(100_0000), types.uint(1000), types.bool(true), types.uint(9900), types.principal(mockToken)],
        wallet1.address
      )
    ]);
    
    // Check initial health
    const initialHealth = chain.callReadOnlyFn(
      riskOracle,
      'get-position-health',
      [types.principal(wallet1.address), types.uint(1)],
      wallet1.address
    );
    
    // Should be healthy initially
    const health = initialHealth.result.expectTuple();
    assertEquals(health['is-liquidatable'], types.bool(false));
    
    // Simulate price drop to trigger liquidation
    chain.mineBlock([
      Tx.contractCall(
        'dimensional-engine',
        'set-price',
        [types.principal(mockToken), types.uint(900000)], // 10% price drop
        'deployer'
      )
    ]);
    
    // Attempt liquidation
    const liquidate = chain.mineBlock([
      Tx.contractCall(
        liquidationEngine,
        'liquidate-position',
        [types.principal(wallet1.address), types.uint(1)],
        wallet2.address
      )
    ]);
    
    // Verify liquidation was successful
    liquidate.receipts[0].result.expectOk().expectBool(true);
    
    // Check position is now liquidated
    const position = chain.callReadOnlyFn(
      dimensionalCore,
      'get-position',
      [types.principal(wallet1.address), types.uint(1)],
      wallet1.address
    );
    
    assertEquals(position.result.expectSome()['is-liquidated'], types.bool(true));
  }
});

// Lending Module Tests
Clarinet.test({
  name: 'Lending: Supply, borrow, and repay',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const { lendingVault, mockToken, wallet1 } = setupTestEnv(chain, accounts);
    
    // Fund wallet1
    const supplyAmount = 1000_0000; // 1000 tokens
    chain.mineBlock([
      Tx.contractCall(mockToken, 'mint', [types.principal(wallet1.address), types.uint(supplyAmount)], wallet1.address),
      Tx.contractCall(mockToken, 'approve', [types.principal(lendingVault), types.uint(supplyAmount)], wallet1.address)
    ]);
    
    // Supply to vault
    const supply = chain.mineBlock([
      Tx.contractCall(
        lendingVault,
        'supply',
        [types.uint(500_0000), types.principal(wallet1.address)],
        wallet1.address
      )
    ]);
    
    supply.receipts[0].result.expectOk().expectBool(true);
    
    // Check supply balance
    const balance = chain.callReadOnlyFn(
      lendingVault,
      'get-supply-balance',
      [types.principal(wallet1.address)],
      wallet1.address
    );
    
    balance.result.expectOk().expectUint(500_0000);
    
    // Borrow against collateral (50% of collateral value at 75% LTV)
    const borrow = chain.mineBlock([
      Tx.contractCall(
        lendingVault,
        'borrow',
        [types.uint(187_5000), types.principal(wallet1.address)], // 500 * 0.75 * 0.5
        wallet1.address
      )
    ]);
    
    borrow.receipts[0].result.expectOk().expectBool(true);
    
    // Check borrow balance
    const borrowBalance = chain.callReadOnlyFn(
      lendingVault,
      'get-borrow-balance',
      [types.principal(wallet1.address)],
      wallet1.address
    );
    
    borrowBalance.result.expectOk().expectUint(187_5000);
  }
});

// Enterprise Lending Tests
Clarinet.test({
  name: 'Enterprise: Register and access credit facility',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const { enterpriseModule, mockToken, wallet1 } = setupTestEnv(chain, accounts);
    
    // Register enterprise
    const register = chain.mineBlock([
      Tx.contractCall(
        enterpriseModule,
        'register-enterprise',
        [
          types.principal(wallet1.address),
          types.utf8('Test Enterprise LLC'),
          types.uint(2), // Risk tier 2
          types.buff(new Uint8Array(1024)) // Mock KYC proof
        ],
        wallet1.address
      )
    ]);
    
    const enterpriseId = register.receipts[0].result.expectOk().expectUint(1);
    
    // Propose terms
    const terms = JSON.stringify({
      amount: '1000000',
      currency: 'USD',
      term: '365 days',
      interest: '5%',
      collateral: ['BTC', 'ETH']
    });
    
    const propose = chain.mineBlock([
      Tx.contractCall(
        enterpriseModule,
        'propose-terms',
        [
          types.uint(enterpriseId),
          types.utf8(terms),
          types.uint(chain.blockHeight + 10), // Effective in 10 blocks
          types.none() // No expiration
        ],
        wallet1.address
      )
    ]);
    
    const proposal = propose.receipts[0].result.expectOk().expectTuple();
    assertEquals(proposal['enterprise-id'], types.uint(enterpriseId));
    
    // Sign terms (simplified - in reality would need proper signature)
    const sign = chain.mineBlock([
      Tx.contractCall(
        enterpriseModule,
        'sign-terms',
        [
          types.uint(enterpriseId),
          proposal['version'],
          types.buff(new Uint8Array(65)) // Mock signature
        ],
        wallet1.address
      )
    ]);
    
    sign.receipts[0].result.expectOk().expectBool(true);
    
    // Verify enterprise status
    const enterprise = chain.callReadOnlyFn(
      enterpriseModule,
      'get-enterprise',
      [types.uint(enterpriseId)],
      wallet1.address
    );
    
    assertEquals(enterprise.result.expectSome()['kyc-verified'], types.bool(true));
    assertEquals(enterprise.result.expectSome()['risk-tier'], types.uint(2));
  }
});

// Integration Test: Full Flow
Clarinet.test({
  name: 'Integration: Full trading and lending flow',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const { 
      dimensionalCore, 
      lendingVault, 
      mockToken, 
      wallet1, 
      wallet2 
    } = setupTestEnv(chain, accounts);
    
    // 1. Fund wallets
    const amount = 10_000_0000; // 10,000 tokens
    chain.mineBlock([
      Tx.contractCall(mockToken, 'mint', [types.principal(wallet1.address), types.uint(amount)], wallet1.address),
      Tx.contractCall(mockToken, 'mint', [types.principal(wallet2.address), types.uint(amount)], wallet1.address),
      // Approvals
      Tx.contractCall(mockToken, 'approve', [types.principal(dimensionalCore), types.uint(amount)], wallet1.address),
      Tx.contractCall(mockToken, 'approve', [types.principal(lendingVault), types.uint(amount)], wallet1.address),
      Tx.contractCall(mockToken, 'approve', [types.principal(dimensionalCore), types.uint(amount)], wallet2.address)
    ]);
    
    // 2. Wallet1 supplies to lending vault
    chain.mineBlock([
      Tx.contractCall(
        lendingVault,
        'supply',
        [types.uint(5000_0000), types.principal(wallet1.address)],
        wallet1.address
      )
    ]);
    
    // 3. Wallet2 opens a leveraged position
    chain.mineBlock([
      Tx.contractCall(
        dimensionalCore,
        'open-position',
        [
          types.uint(1000_0000),  // 1000 tokens collateral
          types.uint(1500),       // 15x leverage
          types.bool(true),       // long
          types.uint(9800),       // 2% slippage
          types.principal(mockToken)
        ],
        wallet2.address
      )
    ]);
    
    // 4. Price increases by 5%
    chain.mineBlock([
      Tx.contractCall(
        'dimensional-engine',
        'set-price',
        [types.principal(mockToken), types.uint(1050000)],
        'deployer'
      )
    ]);
    
    // 5. Wallet2 takes profit
    const closePosition = chain.mineBlock([
      Tx.contractCall(
        dimensionalCore,
        'close-position',
        [types.principal(wallet2.address), types.uint(1), types.uint(0)], // position-owner, position-id, slippage
        wallet2.address
      )
    ]);
    
    // Verify the position is closed
    closePosition.receipts[0].result.expectOk().expectBool(true);
    
    // 6. Wallet1 withdraws from lending vault
    const withdraw = chain.mineBlock([
      Tx.contractCall(
        lendingVault,
        'withdraw',
        [types.uint(5000_0000), types.principal(wallet1.address)],
        wallet1.address
      )
    ]);
    
    withdraw.receipts[0].result.expectOk().expectUint(5000_0000);
  }
});
