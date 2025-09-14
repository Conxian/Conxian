import { describe, it, expect, beforeEach } from 'vitest';
import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';

describe('sBTC Bitcoin Bridge Integration Tests', () => {
  let accounts: Map<string, Account>;
  let chain: Chain;
  
  beforeEach(() => {
    const clarinet = new Clarinet();
    accounts = clarinet.accounts;
    chain = clarinet.chain;
  });

  describe('Peg-in Operations', () => {
    it('should mint sBTC after successful peg-in verification', () => {
      const recipient = accounts.get('wallet_1')!;
      const bitcoinTx = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      
      const block = chain.mineBlock([
        Tx.contractCall(
          'sbtc-integration',
          'peg-in',
          [
            types.buff(bitcoinTx),
            types.uint(100000000), // 1 BTC
            types.principal(recipient.address)
          ],
          recipient.address
        )
      ]);
      
      expect(block.receipts.length).toBe(1);
      expect(block.receipts[0].result).toBeOk();
    });

    it('should reject peg-in with insufficient confirmations', () => {
      const recipient = accounts.get('wallet_1')!;
      const bitcoinTx = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      
      // Force insufficient confirmations by manipulating block height
      chain.mineEmptyBlock(5);
      
      const block = chain.mineBlock([
        Tx.contractCall(
          'sbtc-integration',
          'peg-in',
          [
            types.buff(bitcoinTx),
            types.uint(100000000), // 1 BTC
            types.principal(recipient.address)
          ],
          recipient.address
        )
      ]);
      
      expect(block.receipts.length).toBe(1);
      expect(block.receipts[0].result).toBeErr(types.uint(2009)); // ERR_INSUFFICIENT_CONFIRMATIONS
    });
  });

  describe('Peg-out Operations', () => {
    it('should burn sBTC and initiate peg-out', () => {
      const user = accounts.get('wallet_1')!;
      const bitcoinAddress = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
      
      // Setup: Fund user with sBTC
      chain.mineBlock([
        Tx.contractCall(
          'sbtc-token',
          'mint',
          [types.uint(50000000), types.principal(user.address)],
          accounts.get('deployer')!.address
        )
      ]);
      
      const block = chain.mineBlock([
        Tx.contractCall(
          'sbtc-integration',
          'peg-out',
          [
            types.uint(50000000), // 0.5 BTC
            types.utf8(bitcoinAddress)
          ],
          user.address
        )
      ]);
      
      expect(block.receipts.length).toBe(1);
      expect(block.receipts[0].result).toBeOk();
    });

    it('should reject peg-out with insufficient balance', () => {
      const user = accounts.get('wallet_1')!;
      const bitcoinAddress = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
      
      const block = chain.mineBlock([
        Tx.contractCall(
          'sbtc-integration',
          'peg-out',
          [
            types.uint(100000000), // 1 BTC
            types.utf8(bitcoinAddress)
          ],
          user.address
        )
      ]);
      
      expect(block.receipts.length).toBe(1);
      expect(block.receipts[0].result).toBeErr(); // Expect transfer error
    });
  });

  describe('Security Tests', () => {
    it('should prevent double-spend of bitcoin transactions', () => {
      const recipient = accounts.get('wallet_1')!;
      const bitcoinTx = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      
      // First peg-in should succeed
      chain.mineBlock([
        Tx.contractCall(
          'sbtc-integration',
          'peg-in',
          [
            types.buff(bitcoinTx),
            types.uint(100000000),
            types.principal(recipient.address)
          ],
          recipient.address
        )
      ]);
      
      // Second attempt with same TX should fail
      const block = chain.mineBlock([
        Tx.contractCall(
          'sbtc-integration',
          'peg-in',
          [
            types.buff(bitcoinTx),
            types.uint(100000000),
            types.principal(recipient.address)
          ],
          recipient.address
        )
      ]);
      
      expect(block.receipts.length).toBe(1);
      expect(block.receipts[0].result).toBeErr(); // Expect double-spend error
    });
  });
});
