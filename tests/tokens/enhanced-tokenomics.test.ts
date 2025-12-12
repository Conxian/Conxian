import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;
let wallet2: string;

describe('Enhanced Tokenomics System', () => {
  beforeAll(async () => {
    // Initialize Clarinet simnet directly for this test suite
    simnet = await initSimnet('Clarinet.toml', false, {
      trackCosts: false,
      trackCoverage: false,
    });
  });

  beforeEach(async () => {
    // Reset session before each test to ensure isolation
    await simnet.initSession(process.cwd(), 'Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1') || 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
    wallet2 = accounts.get('wallet_2') || 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
  });

  describe('CXD Token (Revenue Token)', () => {
    it('should have correct initial metadata', () => {
      const nameResult = simnet.callReadOnlyFn('cxd-token', 'get-name', [], deployer);
      expect(nameResult.result).toBeOk(Cl.stringAscii('Conxian Revenue Token'));

      const symbolResult = simnet.callReadOnlyFn('cxd-token', 'get-symbol', [], deployer);
      expect(symbolResult.result).toBeOk(Cl.stringAscii('CXD'));

      const decimalsResult = simnet.callReadOnlyFn('cxd-token', 'get-decimals', [], deployer);
      expect(decimalsResult.result).toBeOk(Cl.uint(6));
    });

    it('should start with zero total supply', () => {
      const totalSupplyResult = simnet.callReadOnlyFn('cxd-token', 'get-total-supply', [], deployer);
      expect(totalSupplyResult.result).toBeOk(Cl.uint(0));
    });

    it('should allow owner to set minter', () => {
      const receipt = simnet.callPublicFn('cxd-token', 'set-minter', [
        Cl.principal(wallet1),
        Cl.bool(true),
      ], deployer);
      expect(receipt.result).toBeOk(Cl.bool(true));
    });

    it('should not allow non-owner to set minter', () => {
      const receipt = simnet.callPublicFn('cxd-token', 'set-minter', [
        Cl.principal(wallet2),
        Cl.bool(true),
      ], wallet1);
      expect(receipt.result).toBeErr(Cl.uint(1001)); // ERR_UNAUTHORIZED
    });

    it('should allow owner or minter to mint tokens', () => {
      // First set wallet1 as minter
      simnet.callPublicFn('cxd-token', 'set-minter', [
        Cl.principal(wallet1),
        Cl.bool(true),
      ], deployer);

      const mintAmount = 1_000_000_000; // 1000 tokens with 6 decimals
      const receipt = simnet.callPublicFn('cxd-token', 'mint', [
        Cl.principal(wallet2),
        Cl.uint(mintAmount),
      ], wallet1);
      expect(receipt.result).toBeOk(Cl.bool(true));

      const balanceResult = simnet.callReadOnlyFn('cxd-token', 'get-balance', [
        Cl.principal(wallet2),
      ], deployer);
      expect(balanceResult.result).toBeOk(Cl.uint(mintAmount));
    });

    it('should support token transfers and update balances', () => {
      // Setup: mint tokens to wallet1
      simnet.callPublicFn('cxd-token', 'set-minter', [
        Cl.principal(deployer),
        Cl.bool(true),
      ], deployer);
      const mintAmount = 1_000_000_000;
      simnet.callPublicFn('cxd-token', 'mint', [
        Cl.principal(wallet1),
        Cl.uint(mintAmount),
      ], deployer);

      // Transfer tokens
      const transferAmount = 500_000_000;
      const receipt = simnet.callPublicFn('cxd-token', 'transfer', [
        Cl.uint(transferAmount),
        Cl.principal(wallet1),
        Cl.principal(wallet2),
        Cl.none(),
      ], wallet1);
      expect(receipt.result).toBeOk(Cl.bool(true));

      const wallet1Balance = simnet.callReadOnlyFn('cxd-token', 'get-balance', [
        Cl.principal(wallet1),
      ], deployer);
      expect(wallet1Balance.result).toBeOk(Cl.uint(mintAmount - transferAmount));

      const wallet2Balance = simnet.callReadOnlyFn('cxd-token', 'get-balance', [
        Cl.standardPrincipal(wallet2),
      ], deployer);
      expect(wallet2Balance.result).toBeOk(Cl.uint(transferAmount));
    });
  });

  describe('CXVG Token (Voting / Governance Token)', () => {
    it('should have correct initial metadata', () => {
      const nameResult = simnet.callReadOnlyFn('cxvg-token', 'get-name', [], deployer);
      expect(nameResult.result).toBeOk(Cl.stringAscii('Conxian Voting Token'));

      const symbolResult = simnet.callReadOnlyFn('cxvg-token', 'get-symbol', [], deployer);
      expect(symbolResult.result).toBeOk(Cl.stringAscii('CXVG'));
    });

    it('should allow owner to configure system integration', () => {
      const receipt = simnet.callPublicFn('cxvg-token', 'set-token-uri', [
        Cl.some(Cl.stringUtf8('ipfs://cxvg-metadata')),
      ], deployer);
      expect(receipt.result).toBeOk(Cl.bool(true));
    });

    it('should support minting and transfers', () => {
      simnet.callPublicFn('cxvg-token', 'mint', [
        Cl.uint(2_000_000_000),
        Cl.principal(wallet1),
      ], deployer);

      const transferAmount = 1_000_000_000;
      const transferReceipt = simnet.callPublicFn('cxvg-token', 'transfer', [
        Cl.uint(transferAmount),
        Cl.principal(wallet1),
        Cl.principal(wallet2),
        Cl.none(),
      ], wallet1);
      expect(transferReceipt.result).toBeOk(Cl.bool(true));
    });
  });

  describe('CXLP Token (Liquidity Provider Token)', () => {
    it('should have correct initial metadata', () => {
      const nameResult = simnet.callReadOnlyFn('cxlp-token', 'get-name', [], deployer);
      expect(nameResult.result).toBeOk(Cl.stringAscii('Conxian LP Token'));

      const symbolResult = simnet.callReadOnlyFn('cxlp-token', 'get-symbol', [], deployer);
      expect(symbolResult.result).toBeOk(Cl.stringAscii('CXLP'));
    });

    it('should support migration configuration', () => {
      const receipt = simnet.callPublicFn('cxlp-token', 'configure-migration', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(0),
        Cl.uint(1440),
      ], deployer);
      expect(receipt.result).toBeOk(Cl.bool(true));
    });

    it('should allow setting liquidity parameters', () => {
      const receipt = simnet.callPublicFn('cxlp-token', 'set-liquidity-params', [
        Cl.uint(100_000_000_000),
        Cl.uint(1_000_000_000),
        Cl.uint(100),
        Cl.uint(50_000_000_000),
        Cl.uint(525_600),
        Cl.uint(11_000),
      ], deployer);
      expect(receipt.result).toBeOk(Cl.bool(true));
    });
  });

  describe('CXTR Token (Treasury / Creator Token)', () => {
    it('should have correct initial metadata', () => {
      const nameResult = simnet.callReadOnlyFn('cxtr-token', 'get-name', [], deployer);
      expect(nameResult.result).toBeOk(Cl.stringAscii('Conxian Treasury Token'));

      const symbolResult = simnet.callReadOnlyFn('cxtr-token', 'get-symbol', [], deployer);
      expect(symbolResult.result).toBeOk(Cl.stringAscii('CXTR'));
    });

    it('should support contributor rewards', () => {
      const receipt = simnet.callPublicFn('cxtr-token', 'mint-merit-reward', [
        Cl.principal(wallet1),
        Cl.uint(500_000_000),
        Cl.uint(1_000),
      ], deployer);
      expect(receipt.result).toBeOk();
    });
  });
});
