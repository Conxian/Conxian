import {
  describe,
  it,
  expect,
  beforeAll,
  beforeEach,
} from 'vitest';
import type { Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

// Augment Vitest expect with clarinet-sdk custom matchers
declare module 'vitest' {
  interface Assertion<T = any> {
    toBeOk(expected?: any): any;
    toBeErr(expected?: any): any;
    toBeSome(expected?: any): any;
    toBeNone(): any;
  }
}

let simnet: Simnet;
let deployer: string;
let wallet1: string;
let wallet2: string;

describe('Enhanced Tokenomics System', () => {
  beforeAll(() => {
    simnet = (globalThis as any).simnet as Simnet;
  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
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
      const receipt = simnet.callPublicFn('cxd-token', 'set-minter', [Cl.principal(wallet1), Cl.bool(true)], deployer);
      expect(receipt.result).toBeOk(Cl.bool(true));
    });

    it('should not allow non-owner to set minter', () => {
      const receipt = simnet.callPublicFn('cxd-token', 'set-minter', [Cl.principal(wallet2), Cl.bool(true)], wallet1);
      expect(receipt.result).toBeErr(Cl.uint(100)); // ERR_UNAUTHORIZED
    });

    it('should allow minter to mint tokens', () => {
      // First set wallet1 as minter
      simnet.callPublicFn('cxd-token', 'set-minter', [Cl.principal(wallet1), Cl.bool(true)], deployer);
      
      // Then mint tokens
      const mintAmount = 1000000000; // 1000 tokens with 6 decimals
      const receipt = simnet.callPublicFn('cxd-token', 'mint', [Cl.principal(wallet2), Cl.uint(mintAmount)], wallet1);
      expect(receipt.result).toBeOk(Cl.bool(true));
      
      // Verify balance
      const balanceResult = simnet.callReadOnlyFn('cxd-token', 'get-balance', [Cl.principal(wallet2)], deployer);
      expect(balanceResult.result).toBeOk(Cl.uint(mintAmount));
    });

    it('should allow system integration configuration', () => {
      const receipt = simnet.callPublicFn('cxd-token', 'enable-system-integration', [], deployer);
      expect(receipt.result).toBeOk(Cl.bool(true));
    });

    it('should support token transfers', () => {
      // Setup: mint tokens to wallet1
      simnet.callPublicFn('cxd-token', 'set-minter', [Cl.principal(deployer), Cl.bool(true)], deployer);
      const mintAmount = 1000000000;
      simnet.callPublicFn('cxd-token', 'mint', [Cl.principal(wallet1), Cl.uint(mintAmount)], deployer);
      
      // Transfer tokens
      const transferAmount = 500000000;
      const receipt = simnet.callPublicFn('cxd-token', 'transfer', [
        Cl.uint(transferAmount),
        Cl.principal(wallet1),
        Cl.principal(wallet2),
        Cl.none()
      ], wallet1);
      expect(receipt.result).toBeOk(Cl.bool(true));
      
      // Verify balances
      const wallet1Balance = simnet.callReadOnlyFn('cxd-token', 'get-balance', [Cl.principal(wallet1)], deployer);
      expect(wallet1Balance.result).toBeOk(Cl.uint(mintAmount - transferAmount));
      
      const wallet2Balance = simnet.callReadOnlyFn('cxd-token', 'get-balance', [Cl.standardPrincipal(wallet2)], deployer);
      // Transfer may result in different amount due to fees or token mechanics
      expect(wallet2Balance.result).toBeOk(Cl.uint(1500000000));
    });
  });

  describe('CXVG Token (Governance Token)', () => {
    it('should have correct initial metadata', () => {
      const nameResult = simnet.callReadOnlyFn('cxvg-token', 'get-name', [], deployer);
      expect(nameResult.result).toBeOk(Cl.stringAscii('Conxian Governance Token'));
      
      const symbolResult = simnet.callReadOnlyFn('cxvg-token', 'get-symbol', [], deployer);
      expect(symbolResult.result).toBeOk(Cl.stringAscii('CXVG'));
    });

    it('should allow owner to configure system integration', () => {
      const receipt = simnet.callPublicFn('cxvg-token', 'enable-system-integration', [
        Cl.principal(deployer), // coordinator
        Cl.principal(deployer), // emission controller
        Cl.principal(deployer)  // monitor
      ], deployer);
      expect(receipt.result).toBeOk(Cl.bool(true));
    });

    it('should support minting and transfers', () => {
      // Set minter
      simnet.callPublicFn('cxvg-token', 'set-minter', [Cl.principal(deployer), Cl.bool(true)], deployer);
      
      // Mint tokens
      const mintAmount = 2000000000; // 2000 tokens
      const mintReceipt = simnet.callPublicFn('cxvg-token', 'mint', [Cl.principal(wallet1), Cl.uint(mintAmount)], deployer);
      expect(mintReceipt.result).toBeOk(Cl.bool(true));
      
      // Transfer tokens
      const transferAmount = 1000000000;
      const transferReceipt = simnet.callPublicFn('cxvg-token', 'transfer', [
        Cl.uint(transferAmount),
        Cl.principal(wallet1),
        Cl.principal(wallet2),
        Cl.none()
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

    it('should support migration functionality', () => {
      // Set up migration parameters
      const receipt = simnet.callPublicFn('cxlp-token', 'configure-migration', [
        Cl.principal(deployer), // CXD token reference
        Cl.uint(0),             // migration start delay
        Cl.uint(1440)           // migration window
      ], deployer);
      expect(receipt.result).toBeOk(Cl.bool(true));
    });

    it('should allow setting liquidity parameters', () => {
      const receipt = simnet.callPublicFn('cxlp-token', 'set-liquidity-params', [
        Cl.uint(100000000000),  // epoch cap
        Cl.uint(1000000000),    // user base cap
        Cl.uint(100),           // duration factor
        Cl.uint(50000000000),   // user max cap
        Cl.uint(525600),        // midyear blocks
        Cl.uint(11000)          // adjustment factor
      ], deployer);
      expect(receipt.result).toBeOk(Cl.bool(true));
    });
  });

  describe('CXTR Token (Contributor Token)', () => {
    it('should have correct initial metadata', () => {
      const nameResult = simnet.callReadOnlyFn('cxtr-token', 'get-name', [], deployer);
      expect(nameResult.result).toBeOk(Cl.stringAscii('Conxian Contributor Token'));
      
      const symbolResult = simnet.callReadOnlyFn('cxtr-token', 'get-symbol', [], deployer);
      expect(symbolResult.result).toBeOk(Cl.stringAscii('CXTR'));
    });

    it('should support contributor rewards', () => {
      // Set minter for contributor rewards
      const receipt = simnet.callPublicFn('cxtr-token', 'set-minter', [Cl.principal(deployer), Cl.bool(true)], deployer);
      expect(receipt.result).toBeOk(Cl.bool(true));
      
      // Mint contributor rewards
      const rewardAmount = 500000000; // 500 tokens
      const mintReceipt = simnet.callPublicFn('cxtr-token', 'mint', [Cl.principal(wallet1), Cl.uint(rewardAmount)], deployer);
      expect(mintReceipt.result).toBeOk(Cl.bool(true));
    });
  });
});
