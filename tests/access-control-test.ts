import { describe, expect, it, beforeEach } from 'vitest';
import { Cl, ResponseOkCV, ResponseErrorCV, ClarityType, boolCV } from '@stacks/transactions';

// Mock the simnet object for testing
const simnet = {
  deployer: 'ST1PQHQKV0RJXZ9VCCXQW16S4MKQ9H51G6FWNJ0G',
  accounts: {
    get: (name: string) => {
      const accounts: Record<string, string> = {
        'wallet_1': 'ST2NEB84ASENDXKYGJPQW86YXQCEFEX2ZQPG87ND',
        'wallet_2': 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC',
        'wallet_3': 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG'
      };
      return accounts[name];
    }
  },
  getDeployedContractIds: () => ({
    accessControl: 'ST1PQHQKV0RJXZ9VCCXQW16S4MKQ9H51G6FWNJ0G.access-control'
  }),
  mineEmptyBlock: (_blocks: number) => {},
  callReadOnlyFn: async (_contract: string, _method: string, _args: any[], _caller: string) => {
    return { type: ClarityType.ResponseOk, value: boolCV(true) } as ResponseOkCV;
  },
  callPublicFn: async (_contract: string, _method: string, _args: any[], _caller: string) => {
    return { type: ClarityType.ResponseOk, value: boolCV(true) } as ResponseOkCV;
  }
} as any;

describe('Access Control Tests', () => {
  const { accessControl } = simnet.getDeployedContractIds();
  const admin = simnet.deployer;
  const user1 = simnet.accounts.get('wallet_1')!;
  const user2 = simnet.accounts.get('wallet_2')!;
  const user3 = simnet.accounts.get('wallet_3')!;
  
  // Role constants from the contract
  const ROLE_ADMIN = '0x41444d494e';
  const ROLE_OPERATOR = '0x4f50455241544f52';
  const ROLE_EMERGENCY = '0x454d455247454e4359';
  
  beforeEach(() => {
    // Reset the simnet before each test
    simnet.mineEmptyBlock(0);
  });

  describe('Role Management', () => {
    it('should allow admin to grant roles', async () => {
      // Admin grants operator role to user1
      const grant = await simnet.callPublicFn(
        'access-control',
        'grant-role',
        [Cl.principal(user1), Cl.bufferFromHex(ROLE_OPERATOR)],
        admin
      ) as ResponseOkCV;
      expect(grant.value).toEqual(Cl.bool(true));
      
      // Verify user1 has operator role
      const hasRole = await simnet.callReadOnlyFn(
        'access-control',
        'has-role',
        [Cl.principal(user1), Cl.bufferFromHex(ROLE_OPERATOR)],
        admin
      ) as ResponseOkCV;
      expect(hasRole.value).toEqual(Cl.bool(true));
    });
    
    it('should prevent non-admin from granting roles', async () => {
      // user1 tries to grant operator role to user2
      const grant = await simnet.callPublicFn(
        'access-control',
        'grant-role',
        [Cl.principal(user2), Cl.bufferFromHex(ROLE_OPERATOR)],
        user1
      ) as ResponseErrorCV;
      expect(grant.value).toEqual(Cl.uint(1001)); // ERR_NOT_ADMIN
    });
    
    it('should allow admin to revoke roles', async () => {
      // First grant the role
      await simnet.callPublicFn(
        'access-control',
        'grant-role',
        [Cl.principal(user1), Cl.bufferFromHex(ROLE_OPERATOR)],
        admin
      );
      
      // Then revoke it
      const result = await simnet.callPublicFn(
        'access-control',
        'revoke-role',
        [Cl.principal(user1), Cl.bufferFromHex(ROLE_OPERATOR)],
        admin
      ) as ResponseOkCV;
      expect(result.value).toEqual(Cl.bool(true));
      
      // Verify role was revoked
      const hasRole = await simnet.callReadOnlyFn(
        'access-control',
        'has-role',
        [Cl.principal(user1), Cl.bufferFromHex(ROLE_OPERATOR)],
        admin
      ) as ResponseOkCV;
      expect(hasRole.value).toEqual(Cl.bool(false));
    });
  });

  describe('Emergency Controls', () => {
    it('should allow emergency admin to pause the contract', () => {
      // Grant emergency role to user1
      simnet.callPublicFn(
        'access-control',
        'grant-role',
        [Cl.principal(user1), Cl.buffFromHex(ROLE_EMERGENCY)],
        admin
      );
      
      // Pause the contract
      const pause = simnet.callPublicFn(
        'access-control',
        'pause',
        [],
        user1
      );
      expect(pause).toBeOk(Cl.bool(true));
      
      // Verify contract is paused
      const isPaused = simnet.callReadOnlyFn(
        'access-control',
        'paused',
        [],
        admin
      );
      expect(isPaused).toBeOk(Cl.bool(true));
    });
    
    it('should prevent non-emergency admin from pausing', () => {
      const pause = simnet.callPublicFn(
        'access-control',
        'pause',
        [],
        user1
      );
      expect(pause).toBeErr(Cl.uint(1003)); // ERR_NOT_EMERGENCY_ADMIN
    });
  });

  describe('Multi-sig Operations', () => {
    it('should allow creating and approving proposals', () => {
      // Grant operator role to user1 and user2
      simnet.callPublicFn(
        'access-control',
        'grant-role',
        [Cl.principal(user1), Cl.buffFromHex(ROLE_OPERATOR)],
        admin
      );
      
      simnet.callPublicFn(
        'access-control',
        'grant-role',
        [Cl.principal(user2), Cl.buffFromHex(ROLE_OPERATOR)],
        admin
      );
      
      // Create a proposal
      const propose = simnet.callPublicFn(
        'access-control',
        'propose',
        [
          Cl.principal(admin), // target
          Cl.uint(0),          // value
          Cl.buffer(Buffer.from('test')), // data
          Cl.stringUtf8('Test proposal')  // description
        ],
        user1
      );
      expect(propose).toBeOk(Cl.uint(1));
      
      // Approve the proposal
      const approve = simnet.callPublicFn(
        'access-control',
        'approve',
        [Cl.uint(1)],
        user2
      );
      expect(approve).toBeOk(Cl.bool(true));
      
      // Execute the proposal
      const execute = simnet.callPublicFn(
        'access-control',
        'execute-proposal',
        [Cl.uint(1)],
        user1
      );
      expect(execute).toBeOk(Cl.bool(true));
    });
    
    it('should enforce approval threshold', () => {
      // Similar to above but with insufficient approvals
      simnet.callPublicFn(
        'access-control',
        'propose',
        [
          Cl.principal(admin),
          Cl.uint(0),
          Cl.buffer(Buffer.from('test')),
          Cl.stringUtf8('Test proposal')
        ],
        user1
      );
      
      // Try to execute without enough approvals
      const execute = simnet.callPublicFn(
        'access-control',
        'execute-proposal',
        [Cl.uint(1)],
        user1
      );
      expect(execute).toBeErr(Cl.uint(1007)); // ERR_NOT_ENOUGH_APPROVALS
    });
  });
});

// Run the tests
run();
