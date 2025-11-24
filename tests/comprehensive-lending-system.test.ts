import { Cl, ClarityValue, ResponseOkCV, cvToValue } from '@stacks/transactions';
import { describe, expect, it, beforeAll } from 'vitest';
import { Simnet } from '@stacks/clarinet-sdk';
import {
  deployer,
  user1,
  user2,
  setupRoles,
  mintTokens,
  expectErr,
  expectOk,
  expectOkWithResult,
  expectErrWithCode,
  ERR_NOT_AUTHORIZED,
  ERR_INVALID_ASSET,
  ERR_ZERO_AMOUNT
} from './test-utils';

const simnet: Simnet = (global as any).simnet;

const unwrapOk = <T = unknown>(response: any): T =>
  cvToValue((response.result as ResponseOkCV<ClarityValue>).value) as T;

// Contract addresses
const LENDING_CONTRACT = `${deployer}.comprehensive-lending-system`;
const TOKEN_A_CONTRACT = `${deployer}.token-a`;
const TOKEN_B_CONTRACT = `${deployer}.token-b`;
const ORACLE_CONTRACT = `${deployer}.oracle-adapter`;

describe('Comprehensive Lending System', () => {
  const INITIAL_MINT = 1_000_000_000;

  beforeAll(async () => {
    // Setup roles
    await setupRoles(simnet);

    // Mint initial tokens for users
    await mintTokens(simnet, user1, INITIAL_MINT);
    await mintTokens(simnet, user2, INITIAL_MINT);

    // Set initial prices in the oracle
    await simnet.callPublicFn(ORACLE_CONTRACT, 'set-price', [Cl.contractPrincipal(deployer, 'token-a'), Cl.uint(100000000)], deployer); // $1.00
    await simnet.callPublicFn(ORACLE_CONTRACT, 'set-price', [Cl.contractPrincipal(deployer, 'token-b'), Cl.uint(50000000)], deployer); // $0.50

    // Add assets to the lending pool
    await simnet.callPublicFn(LENDING_CONTRACT, 'add-asset', [Cl.contractPrincipal(deployer, 'token-a')], deployer);
    await simnet.callPublicFn(LENDING_CONTRACT, 'add-asset', [Cl.contractPrincipal(deployer, 'token-b')], deployer);
    describe('Supply and Withdraw', () => {
    const SUPPLY_AMOUNT = 100_000;

    it('should allow a user to supply a supported asset', async () => {
      const result = await simnet.callPublicFn(
        LENDING_CONTRACT,
        'supply',
        [Cl.contractPrincipal(deployer, 'token-a'), Cl.uint(SUPPLY_AMOUNT)],
        user1
      );
      expectOk(result);

      const balance = await simnet.callReadOnlyFn(
        LENDING_CONTRACT,
        'get-user-supply-balance',
        [Cl.principal(user1), Cl.contractPrincipal(deployer, 'token-a')],
        user1
      );
      expectOkWithResult(balance, SUPPLY_AMOUNT);
    
  describe('Borrowing and Repayment', () => {
    const COLLATERAL_AMOUNT = 200_000;
    const BORROW_AMOUNT = 50_000;

    beforeAll(async () => {
      // User1 supplies collateral
      await simnet.callPublicFn(
        LENDING_CONTRACT,
        'supply',
        [Cl.contractPrincipal(deployer, 'token-a'), Cl.uint(COLLATERAL_AMOUNT)],
        user1
      );
    
  describe('Liquidation', () => {
    const COLLATERAL_AMOUNT = 100_000;
    const BORROW_AMOUNT = 50_000;

    beforeAll(async () => {
      // User2 supplies collateral and borrows
      await simnet.callPublicFn(LENDING_CONTRACT, 'supply', [Cl.contractPrincipal(deployer, 'token-a'), Cl.uint(COLLATERAL_AMOUNT)], user2);
      await simnet.callPublicFn(LENDING_CONTRACT, 'borrow', [Cl.contractPrincipal(deployer, 'token-b'), Cl.uint(BORROW_AMOUNT)], user2);

      // Price of collateral (token-a) drops, making the loan undercollateralized
      await simnet.callPublicFn(ORACLE_CONTRACT, 'set-price', [Cl.contractPrincipal(deployer, 'token-a'), Cl.uint(50000000)], deployer); // Price drops to $0.50
    });

    it('should allow a liquidator to liquidate an undercollateralized loan', async () => {
      // User1 (liquidator) approves the contract to spend their tokens to repay the loan
      await simnet.callPublicFn(TOKEN_B_CONTRACT, 'approve', [Cl.principal(LENDING_CONTRACT), Cl.uint(BORROW_AMOUNT)], user1);

      const result = await simnet.callPublicFn(
        LENDING_CONTRACT,
        'liquidate-loan',
        [Cl.principal(user2), Cl.contractPrincipal(deployer, 'token-a'), Cl.contractPrincipal(deployer, 'token-b'), Cl.uint(BORROW_AMOUNT)],
        user1
      );
      expectOk(result);

      const borrowBalance = await simnet.callReadOnlyFn(
        LENDING_CONTRACT,
        'get-user-borrow-balance',
        [Cl.principal(user2), Cl.contractPrincipal(deployer, 'token-b')],
        user1
      );
      expectOkWithResult(borrowBalance, 0);
    });

    it('should prevent liquidation of a healthy loan', async () => {
        // Price of collateral (token-a) recovers
        await simnet.callPublicFn(ORACLE_CONTRACT, 'set-price', [Cl.contractPrincipal(deployer, 'token-a'), Cl.uint(100000000)], deployer); // Price recovers to $1.00
        
        const result = await simnet.callPublicFn(
            LENDING_CONTRACT,
            'liquidate-loan',
            [Cl.principal(user2), Cl.contractPrincipal(deployer, 'token-a'), Cl.contractPrincipal(deployer, 'token-b'), Cl.uint(BORROW_AMOUNT)],
            user1
        );
        expectErr(result); // Should be ERR_HEALTH_CHECK_FAILED
    });
  });

    it('should allow a user to borrow against their collateral', async () => {
      const result = await simnet.callPublicFn(
        LENDING_CONTRACT,
        'borrow',
        [Cl.contractPrincipal(deployer, 'token-b'), Cl.uint(BORROW_AMOUNT)],
        user1
      );
      expectOk(result);

      const borrowBalance = await simnet.callReadOnlyFn(
        LENDING_CONTRACT,
        'get-user-borrow-balance',
        [Cl.principal(user1), Cl.contractPrincipal(deployer, 'token-b')],
        user1
      );
      expectOkWithResult(borrowBalance, BORROW_AMOUNT);
    });

    it('should prevent borrowing without sufficient collateral', async () => {
      const largeBorrowAmount = 300_000; // Exceeds collateral value
      const result = await simnet.callPublicFn(
        LENDING_CONTRACT,
        'borrow',
        [Cl.contractPrincipal(deployer, 'token-b'), Cl.uint(largeBorrowAmount)],
        user1
      );
      expectErr(result); // Should be ERR_INSUFFICIENT_COLLATERAL
    });

    it('should allow a user to repay their loan', async () => {
      // First, approve the contract to spend the user's tokens for repayment
      await simnet.callPublicFn(
        TOKEN_B_CONTRACT,
        'approve',
        [Cl.principal(LENDING_CONTRACT), Cl.uint(BORROW_AMOUNT)],
        user1
      );
        
      const result = await simnet.callPublicFn(
        LENDING_CONTRACT,
        'repay',
        [Cl.contractPrincipal(deployer, 'token-b'), Cl.uint(BORROW_AMOUNT)],
        user1
      );
      expectOk(result);

      const borrowBalance = await simnet.callReadOnlyFn(
        LENDING_CONTRACT,
        'get-user-borrow-balance',
        [Cl.principal(user1), Cl.contractPrincipal(deployer, 'token-b')],
        user1
      );
      expectOkWithResult(borrowBalance, 0);
    });
  });

    it('should prevent a user from supplying an unsupported asset', async () => {
        const result = await simnet.callPublicFn(
            LENDING_CONTRACT,
            'supply',
            [Cl.contractPrincipal(deployer, 'unsupported-token'), Cl.uint(SUPPLY_AMOUNT)],
            user1
        );
        expectErrWithCode(result, ERR_INVALID_ASSET);
    });

    it('should prevent a user from supplying a zero amount', async () => {
        const result = await simnet.callPublicFn(
            LENDING_CONTRACT,
            'supply',
            [Cl.contractPrincipal(deployer, 'token-a'), Cl.uint(0)],
            user1
        );
        expectErrWithCode(result, ERR_ZERO_AMOUNT);
    });

    it('should allow a user to withdraw a supplied asset', async () => {
        const result = await simnet.callPublicFn(
            LENDING_CONTRACT,
            'withdraw',
            [Cl.contractPrincipal(deployer, 'token-a'), Cl.uint(SUPPLY_AMOUNT)],
            user1
        );
        expectOk(result);

        const balance = await simnet.callReadOnlyFn(
            LENDING_CONTRACT,
            'get-user-supply-balance',
            [Cl.principal(user1), Cl.contractPrincipal(deployer, 'token-a')],
            user1
        );
        expectOkWithResult(balance, 0);
    });

    it('should prevent a user from withdrawing more than they supplied', async () => {
        const result = await simnet.callPublicFn(
            LENDING_CONTRACT,
            'withdraw',
            [Cl.contractPrincipal(deployer, 'token-a'), Cl.uint(SUPPLY_AMOUNT + 1)],
            user1
        );
        expectErr(result); // Should be ERR_INSUFFICIENT_BALANCE, assuming it's defined
    });
  });
  });
});
