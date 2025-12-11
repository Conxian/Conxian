import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

// Core sanity and guard-rail tests for the comprehensive-lending-system.
describe('Comprehensive Lending System', () => {
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

  describe('zero-amount guard rails', () => {
    it('rejects zero-amount supply', () => {
      const res = simnet.callPublicFn('comprehensive-lending-system', 'supply', [
        // Asset trait parameter is not used for zero-amount guard; we can pass any SIP-010 contract
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(0),
      ], wallet1);

      // ERR_ZERO_AMOUNT = (err u1004)
      expect(res.result).toBeErr(Cl.uint(1004));
    });

    it('rejects zero-amount withdraw', () => {
      const res = simnet.callPublicFn('comprehensive-lending-system', 'withdraw', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(0),
      ], wallet1);
      expect(res.result).toBeErr(Cl.uint(1004));
    });

    it('rejects zero-amount borrow', () => {
      const res = simnet.callPublicFn('comprehensive-lending-system', 'borrow', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(0),
      ], wallet1);
      expect(res.result).toBeErr(Cl.uint(1004));
    });

    it('rejects zero-amount repay', () => {
      const res = simnet.callPublicFn('comprehensive-lending-system', 'repay', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(0),
      ], wallet1);
      expect(res.result).toBeErr(Cl.uint(1004));
    });
  });

  describe("read-only views on empty state", () => {
    it("returns zero supply balance for new users", () => {
      const bal = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-user-supply-balance",
        [
          Cl.standardPrincipal(wallet1),
          Cl.contractPrincipal(deployer, "cxd-token"),
        ],
        wallet1
      );

      expect(bal.result).toBeOk(Cl.uint(0));
    });

    it("returns zero borrow balance for new users", () => {
      const bal = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-user-borrow-balance",
        [
          Cl.standardPrincipal(wallet1),
          Cl.contractPrincipal(deployer, "cxd-token"),
        ],
        wallet1
      );

      expect(bal.result).toBeOk(Cl.uint(0));
    });

    it("returns a healthy default health factor", () => {
      const hf = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-health-factor",
        [Cl.standardPrincipal(wallet1)],
        wallet1
      );

      // With no positions, the health factor should be a high default.
      expect(hf.result).toBeOk(Cl.uint(20000));
    });
  });

  describe("circuit breaker integration", () => {
    it("halts supply when circuit is open", () => {
      const asset = Cl.contractPrincipal(deployer, "cxd-token");

      const opened = simnet.callPublicFn(
        "circuit-breaker",
        "open-circuit",
        [],
        deployer
      );
      expect(opened.result).toBeOk(Cl.bool(true));

      const res = simnet.callPublicFn(
        "comprehensive-lending-system",
        "supply",
        [asset, Cl.uint(100)],
        wallet1
      );

      // ERR_CIRCUIT_BREAKER_OPEN = (err u1006)
      expect(res.result).toBeErr(Cl.uint(1006));
    });
  });

  describe("health factor model", () => {
    it("returns u20000 when user has no borrow", () => {
      const hf = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-health-factor",
        [Cl.standardPrincipal(wallet1)],
        wallet1
      );

      expect(hf.result).toBeOk(Cl.uint(20000));
    });

    it("reports user as healthy by default when there is no borrow", () => {
      const healthy = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "is-user-healthy",
        [Cl.standardPrincipal(wallet1)],
        wallet1
      );

      expect(healthy.result).toBeOk(Cl.bool(true));
    });

    it("only the contract owner can set the minimum health factor", () => {
      const unauthorized = simnet.callPublicFn(
        "comprehensive-lending-system",
        "set-min-health-factor",
        [Cl.uint(15000)],
        wallet1
      );

      // ERR_UNAUTHORIZED = (err u1000)
      expect(unauthorized.result).toBeErr(Cl.uint(1000));
    });
  });

  describe("full lifecycle: supply, borrow, repay, withdraw", () => {
    it("executes a full lifecycle with zero interest and preserves balances", () => {
      const asset = Cl.contractPrincipal(deployer, "cxd-token");
      const lendingContract = Cl.contractPrincipal(
        deployer,
        "comprehensive-lending-system"
      );

      const initialMintAmount = 10_000n;

      const setMinter = simnet.callPublicFn(
        "cxd-token",
        "set-minter",
        [Cl.principal(deployer), Cl.bool(true)],
        deployer
      );
      expect(setMinter.result).toBeOk(Cl.bool(true));

      const mint = simnet.callPublicFn(
        "cxd-token",
        "mint",
        [Cl.standardPrincipal(wallet1), Cl.uint(initialMintAmount)],
        deployer
      );
      expect(mint.result).toBeOk(Cl.bool(true));

      const startUserBal = simnet.callReadOnlyFn(
        "cxd-token",
        "get-balance",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );
      expect(startUserBal.result).toBeOk(Cl.uint(initialMintAmount));

      const setLs = simnet.callPublicFn(
        "interest-rate-model",
        "set-lending-system-contract",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );
      expect(setLs.result).toBeOk(Cl.bool(true));

      const initMarket = simnet.callPublicFn(
        "interest-rate-model",
        "initialize-market",
        [asset],
        wallet1
      );
      expect(initMarket.result).toBeOk(Cl.bool(true));

      const setModel = simnet.callPublicFn(
        "interest-rate-model",
        "set-interest-rate-model",
        [
          asset,
          Cl.uint(0),
          Cl.uint(0),
          Cl.uint(0),
          Cl.uint(1_000_000_000_000_000_000n),
        ],
        deployer
      );
      expect(setModel.result).toBeOk(Cl.bool(true));

      const supplyAmount = 1_000n;
      const supply = simnet.callPublicFn(
        "comprehensive-lending-system",
        "supply",
        [asset, Cl.uint(supplyAmount)],
        wallet1
      );
      expect(supply.result).toBeOk(Cl.bool(true));

      const userSupply = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-user-supply-balance",
        [Cl.standardPrincipal(wallet1), asset],
        wallet1
      );
      expect(userSupply.result).toBeOk(Cl.uint(supplyAmount));

      const afterSupplyUserBal = simnet.callReadOnlyFn(
        "cxd-token",
        "get-balance",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );
      expect(afterSupplyUserBal.result).toBeOk(
        Cl.uint(initialMintAmount - supplyAmount)
      );

      const contractBalAfterSupply = simnet.callReadOnlyFn(
        "cxd-token",
        "get-balance",
        [lendingContract],
        deployer
      );
      expect(contractBalAfterSupply.result).toBeOk(Cl.uint(supplyAmount));

      const borrowAmount = 200n;
      const borrow = simnet.callPublicFn(
        "comprehensive-lending-system",
        "borrow",
        [asset, Cl.uint(borrowAmount)],
        wallet1
      );
      expect(borrow.result).toBeOk(Cl.bool(true));

      const userBorrow = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-user-borrow-balance",
        [Cl.standardPrincipal(wallet1), asset],
        wallet1
      );
      expect(userBorrow.result).toBeOk(Cl.uint(borrowAmount));

      const afterBorrowUserBal = simnet.callReadOnlyFn(
        "cxd-token",
        "get-balance",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );
      expect(afterBorrowUserBal.result).toBeOk(
        Cl.uint(initialMintAmount - supplyAmount + borrowAmount)
      );

      const contractBalAfterBorrow = simnet.callReadOnlyFn(
        "cxd-token",
        "get-balance",
        [lendingContract],
        deployer
      );
      expect(contractBalAfterBorrow.result).toBeOk(
        Cl.uint(supplyAmount - borrowAmount)
      );

      const repay = simnet.callPublicFn(
        "comprehensive-lending-system",
        "repay",
        [asset, Cl.uint(borrowAmount)],
        wallet1
      );
      expect(repay.result).toBeOk(Cl.bool(true));

      const userBorrowAfterRepay = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-user-borrow-balance",
        [Cl.standardPrincipal(wallet1), asset],
        wallet1
      );
      expect(userBorrowAfterRepay.result).toBeOk(Cl.uint(0));

      const afterRepayUserBal = simnet.callReadOnlyFn(
        "cxd-token",
        "get-balance",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );
      expect(afterRepayUserBal.result).toBeOk(
        Cl.uint(initialMintAmount - supplyAmount)
      );

      const contractBalAfterRepay = simnet.callReadOnlyFn(
        "cxd-token",
        "get-balance",
        [lendingContract],
        deployer
      );
      expect(contractBalAfterRepay.result).toBeOk(Cl.uint(supplyAmount));

      const withdraw = simnet.callPublicFn(
        "comprehensive-lending-system",
        "withdraw",
        [asset, Cl.uint(supplyAmount)],
        wallet1
      );
      expect(withdraw.result).toBeOk(Cl.bool(true));

      const finalSupply = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-user-supply-balance",
        [Cl.standardPrincipal(wallet1), asset],
        wallet1
      );
      expect(finalSupply.result).toBeOk(Cl.uint(0));

      const finalBorrow = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-user-borrow-balance",
        [Cl.standardPrincipal(wallet1), asset],
        wallet1
      );
      expect(finalBorrow.result).toBeOk(Cl.uint(0));

      const finalUserBal = simnet.callReadOnlyFn(
        "cxd-token",
        "get-balance",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );
      expect(finalUserBal.result).toBeOk(Cl.uint(initialMintAmount));

      const finalContractBal = simnet.callReadOnlyFn(
        "cxd-token",
        "get-balance",
        [lendingContract],
        deployer
      );
      expect(finalContractBal.result).toBeOk(Cl.uint(0));
    });
  });

  describe("checked operations guard rails", () => {
    it("prevents uncollateralized borrow via borrow-checked", () => {
      const asset = Cl.contractPrincipal(deployer, "cxd-token");

      const res = simnet.callPublicFn(
        "comprehensive-lending-system",
        "borrow-checked",
        [asset, Cl.uint(100)],
        wallet1
      );

      // ERR_HEALTH_CHECK_FAILED = (err u1005)
      expect(res.result).toBeErr(Cl.uint(1005));

      const supplyBal = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-user-supply-balance",
        [Cl.standardPrincipal(wallet1), asset],
        wallet1
      );
      expect(supplyBal.result).toBeOk(Cl.uint(0));

      const borrowBal = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-user-borrow-balance",
        [Cl.standardPrincipal(wallet1), asset],
        wallet1
      );
      expect(borrowBal.result).toBeOk(Cl.uint(0));
    });

    it("rejects withdrawals that would violate the health factor via withdraw-checked", () => {
      const asset = Cl.contractPrincipal(deployer, "cxd-token");
      const lendingContract = Cl.contractPrincipal(
        deployer,
        "comprehensive-lending-system"
      );

      const initialMintAmount = 10_000n;
      const supplyAmount = 1_000n;
      const borrowAmount = 600n;

      const setMinter = simnet.callPublicFn(
        "cxd-token",
        "set-minter",
        [Cl.principal(deployer), Cl.bool(true)],
        deployer
      );
      expect(setMinter.result).toBeOk(Cl.bool(true));

      const mint = simnet.callPublicFn(
        "cxd-token",
        "mint",
        [Cl.standardPrincipal(wallet1), Cl.uint(initialMintAmount)],
        deployer
      );
      expect(mint.result).toBeOk(Cl.bool(true));

      const setLs = simnet.callPublicFn(
        "interest-rate-model",
        "set-lending-system-contract",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );
      expect(setLs.result).toBeOk(Cl.bool(true));

      const initMarket = simnet.callPublicFn(
        "interest-rate-model",
        "initialize-market",
        [asset],
        wallet1
      );
      expect(initMarket.result).toBeOk(Cl.bool(true));

      const setModel = simnet.callPublicFn(
        "interest-rate-model",
        "set-interest-rate-model",
        [
          asset,
          Cl.uint(0),
          Cl.uint(0),
          Cl.uint(0),
          Cl.uint(1_000_000_000_000_000_000n),
        ],
        deployer
      );
      expect(setModel.result).toBeOk(Cl.bool(true));

      const supply = simnet.callPublicFn(
        "comprehensive-lending-system",
        "supply",
        [asset, Cl.uint(supplyAmount)],
        wallet1
      );
      expect(supply.result).toBeOk(Cl.bool(true));

      const borrow = simnet.callPublicFn(
        "comprehensive-lending-system",
        "borrow",
        [asset, Cl.uint(borrowAmount)],
        wallet1
      );
      expect(borrow.result).toBeOk(Cl.bool(true));

      const beforeSupply = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-user-supply-balance",
        [Cl.standardPrincipal(wallet1), asset],
        wallet1
      );
      expect(beforeSupply.result).toBeOk(Cl.uint(supplyAmount));

      const beforeBorrow = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-user-borrow-balance",
        [Cl.standardPrincipal(wallet1), asset],
        wallet1
      );
      expect(beforeBorrow.result).toBeOk(Cl.uint(borrowAmount));

      const withdrawAttempt = simnet.callPublicFn(
        "comprehensive-lending-system",
        "withdraw-checked",
        [asset, Cl.uint(borrowAmount)],
        wallet1
      );
      // With supply=1000 and borrow=600, withdrawing 600 would drop HF below min.
      expect(withdrawAttempt.result).toBeErr(Cl.uint(1005));

      const afterSupply = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-user-supply-balance",
        [Cl.standardPrincipal(wallet1), asset],
        wallet1
      );
      expect(afterSupply.result).toBeOk(Cl.uint(supplyAmount));

      const afterBorrow = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-user-borrow-balance",
        [Cl.standardPrincipal(wallet1), asset],
        wallet1
      );
      expect(afterBorrow.result).toBeOk(Cl.uint(borrowAmount));

      const contractBal = simnet.callReadOnlyFn(
        "cxd-token",
        "get-balance",
        [lendingContract],
        deployer
      );
      expect(contractBal.result).toBeOk(Cl.uint(supplyAmount - borrowAmount));
    });

    it("caps repay amount to outstanding debt when user overpays", () => {
      const asset = Cl.contractPrincipal(deployer, "cxd-token");
      const lendingContract = Cl.contractPrincipal(
        deployer,
        "comprehensive-lending-system"
      );

      const initialMintAmount = 10_000n;
      const supplyAmount = 1_000n;
      const borrowAmount = 200n;
      const overRepayAmount = 1_000n;

      const setMinter = simnet.callPublicFn(
        "cxd-token",
        "set-minter",
        [Cl.principal(deployer), Cl.bool(true)],
        deployer
      );
      expect(setMinter.result).toBeOk(Cl.bool(true));

      const mint = simnet.callPublicFn(
        "cxd-token",
        "mint",
        [Cl.standardPrincipal(wallet1), Cl.uint(initialMintAmount)],
        deployer
      );
      expect(mint.result).toBeOk(Cl.bool(true));

      const setLs = simnet.callPublicFn(
        "interest-rate-model",
        "set-lending-system-contract",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );
      expect(setLs.result).toBeOk(Cl.bool(true));

      const initMarket = simnet.callPublicFn(
        "interest-rate-model",
        "initialize-market",
        [asset],
        wallet1
      );
      expect(initMarket.result).toBeOk(Cl.bool(true));

      const setModel = simnet.callPublicFn(
        "interest-rate-model",
        "set-interest-rate-model",
        [
          asset,
          Cl.uint(0),
          Cl.uint(0),
          Cl.uint(0),
          Cl.uint(1_000_000_000_000_000_000n),
        ],
        deployer
      );
      expect(setModel.result).toBeOk(Cl.bool(true));

      const supply = simnet.callPublicFn(
        "comprehensive-lending-system",
        "supply",
        [asset, Cl.uint(supplyAmount)],
        wallet1
      );
      expect(supply.result).toBeOk(Cl.bool(true));

      const borrow = simnet.callPublicFn(
        "comprehensive-lending-system",
        "borrow",
        [asset, Cl.uint(borrowAmount)],
        wallet1
      );
      expect(borrow.result).toBeOk(Cl.bool(true));

      const overRepay = simnet.callPublicFn(
        "comprehensive-lending-system",
        "repay",
        [asset, Cl.uint(overRepayAmount)],
        wallet1
      );
      expect(overRepay.result).toBeOk(Cl.bool(true));

      const finalBorrow = simnet.callReadOnlyFn(
        "comprehensive-lending-system",
        "get-user-borrow-balance",
        [Cl.standardPrincipal(wallet1), asset],
        wallet1
      );
      expect(finalBorrow.result).toBeOk(Cl.uint(0));

      const finalUserBal = simnet.callReadOnlyFn(
        "cxd-token",
        "get-balance",
        [Cl.standardPrincipal(wallet1)],
        deployer
      );
      expect(finalUserBal.result).toBeOk(
        Cl.uint(initialMintAmount - supplyAmount)
      );

      const finalContractBal = simnet.callReadOnlyFn(
        "cxd-token",
        "get-balance",
        [lendingContract],
        deployer
      );
      expect(finalContractBal.result).toBeOk(Cl.uint(supplyAmount));
    });
  });
});
