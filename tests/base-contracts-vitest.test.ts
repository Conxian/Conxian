import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { setupSimnet, TEST_ACCOUNTS, CONTRACTS, ERROR_CODES } from './utils/test-helpers';

describe('Base Contracts', () => {
  let simnet = setupSimnet();

  describe('Ownable', () => {
    it('has correct initial owner', async () => {
      const result = await simnet.readOnlyFn(CONTRACTS.ownable, 'get-owner', [], TEST_ACCOUNTS.deployer);
      expect(result).toBeOk(Cl.principal(TEST_ACCOUNTS.deployer));
    });

    it('transfers ownership correctly', async () => {
      // Transfer ownership to wallet1
      const block = await simnet.mineBlock([
        simnet.callPublicFn(CONTRACTS.ownable, 'transfer-ownership', [Cl.principal(TEST_ACCOUNTS.wallet_1)], TEST_ACCOUNTS.deployer),
      ]);
      
      expect(block.receipts[0].result).toBeOk(Cl.bool(true));
      
      // Claim ownership
      const claimBlock = await simnet.mineBlock([
        simnet.callPublicFn(CONTRACTS.ownable, 'claim-ownership', [], TEST_ACCOUNTS.wallet_1),
      ]);
      
      expect(claimBlock.receipts[0].result).toBeOk(Cl.bool(true));
      
      // Verify new owner
      const result = await simnet.readOnlyFn(CONTRACTS.ownable, 'get-owner', [], TEST_ACCOUNTS.wallet_1);
      expect(result).toBeOk(Cl.principal(TEST_ACCOUNTS.wallet_1));
    });

    it('prevents unauthorized ownership transfer', async () => {
      // wallet1 tries to transfer ownership (not the owner)
      const block = await simnet.mineBlock([
        simnet.callPublicFn(CONTRACTS.ownable, 'transfer-ownership', [Cl.principal(TEST_ACCOUNTS.wallet_2)], TEST_ACCOUNTS.wallet_1),
      ]);
      
      expect(block.receipts[0].result).toBeErr(Cl.uint(ERROR_CODES.ERR_NOT_OWNER));
    });
  });

  describe('Pausable', () => {
    it('pauses and unpauses correctly', async () => {
      // Pause the contract
      const pauseBlock = await simnet.mineBlock([
        simnet.callPublicFn(CONTRACTS.pausable, 'pause', [], TEST_ACCOUNTS.deployer),
      ]);
      expect(pauseBlock.receipts[0].result).toBeOk(Cl.bool(true));
      
      // Check if paused
      const result = await simnet.readOnlyFn(CONTRACTS.pausable, 'is-paused', [], TEST_ACCOUNTS.deployer);
      expect(result).toBeOk(Cl.bool(true));
      
      // Unpause
      const unpauseBlock = await simnet.mineBlock([
        simnet.callPublicFn(CONTRACTS.pausable, 'unpause', [], TEST_ACCOUNTS.deployer),
      ]);
      expect(unpauseBlock.receipts[0].result).toBeOk(Cl.bool(true));
      
      // Verify unpaused
      const unpausedResult = await simnet.readOnlyFn(CONTRACTS.pausable, 'is-paused', [], TEST_ACCOUNTS.deployer);
      expect(unpausedResult).toBeOk(Cl.bool(false));
    });
  });

  describe('Roles', () => {
    const ROLE_ADMIN = 1;
    
    it('manages roles correctly', async () => {
      // Grant admin role to wallet1
      const grantBlock = await simnet.mineBlock([
        simnet.callPublicFn(CONTRACTS.roles, 'grant-role', [Cl.principal(TEST_ACCOUNTS.wallet_1), Cl.uint(ROLE_ADMIN)], TEST_ACCOUNTS.deployer),
      ]);
      expect(grantBlock.receipts[0].result).toBeOk(Cl.bool(true));
      
      // Check role
      const result = await simnet.readOnlyFn(CONTRACTS.roles, 'has-role', [Cl.principal(TEST_ACCOUNTS.wallet_1), Cl.uint(ROLE_ADMIN)], TEST_ACCOUNTS.deployer);
      expect(result).toBeOk(Cl.bool(true));
      
      // Revoke role
      const revokeBlock = await simnet.mineBlock([
        simnet.callPublicFn(CONTRACTS.roles, 'revoke-role', [Cl.principal(TEST_ACCOUNTS.wallet_1), Cl.uint(ROLE_ADMIN)], TEST_ACCOUNTS.deployer),
      ]);
      expect(revokeBlock.receipts[0].result).toBeOk(Cl.bool(true));
      
      // Verify role revoked
      const revokedResult = await simnet.readOnlyFn(CONTRACTS.roles, 'has-role', [Cl.principal(TEST_ACCOUNTS.wallet_1), Cl.uint(ROLE_ADMIN)], TEST_ACCOUNTS.deployer);
      expect(revokedResult).toBeOk(Cl.bool(false));
    });
  });
});
