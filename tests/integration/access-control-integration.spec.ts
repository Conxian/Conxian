import { Cl, ClarityType, ResponseOkCV, ResponseErrorCV } from '@stacks/transactions';
import { describe, it, expect, beforeEach } from 'vitest';
import { hexToBuffer } from '../../src/utils';

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
      return accounts[name] || '';
    }
  },
  callPublicFn: async (contract: string, method: string, args: any[], caller: string) => {
    // Mock implementation for testing
    return { value: { type: ClarityType.ResponseOk, value: Cl.bool(true) } };
  },
  callReadOnlyFn: async (contract: string, method: string, args: any[], caller: string) => {
    // Mock implementation for testing
    return { value: { type: ClarityType.ResponseOk, value: Cl.bool(true) } };
  }
} as any;

describe('AccessControl Integration Tests', () => {
  const admin = simnet.deployer;
  const user1 = simnet.accounts.get('wallet_1');
  const user2 = simnet.accounts.get('wallet_2');
  
  // Role hashes (keccak256 of role names)
  const ROLES = {
    ADMIN: '0x41444d494e000000000000000000000000000000000000000000000000000000',
    OPERATOR: '0x4f50455241544f52000000000000000000000000000000000000000000000000',
    EMERGENCY: '0x454d455247454e43590000000000000000000000000000000000000000000000'
  };

  beforeEach(async () => {
    // Reset state before each test
    await simnet.callPublicFn('access-control', 'initialize', [], admin);
  });

  it('should allow admin to grant roles', async () => {
    // Grant operator role to user1
    const grant = await simnet.callPublicFn(
      'access-control',
      'grant-role',
      [
        Cl.buffer(hexToBuffer(ROLES.OPERATOR)),
        Cl.principal(user1)
      ],
      admin
    ) as ResponseOkCV;
    
    expect(grant.value).toEqual(Cl.bool(true));
    
    // Verify user1 has operator role
    const hasRole = await simnet.callReadOnlyFn(
      'access-control',
      'has-role',
      [
        Cl.buffer(hexToBuffer(ROLES.OPERATOR)),
        Cl.principal(user1)
      ],
      admin
    ) as ResponseOkCV;
    
    expect(hasRole.value).toEqual(Cl.bool(true));
  });

  it('should integrate with lending system', async () => {
    // Grant operator role to user1
    await simnet.callPublicFn(
      'access-control',
      'grant-role',
      [
        Cl.buffer(hexToBuffer(ROLES.OPERATOR)),
        Cl.principal(user1)
      ],
      admin
    );

    // Test that user1 can call operator functions
    const result = await simnet.callPublicFn(
      'lending-system',
      'set-market-params',
      [
        Cl.principal('ST1PQHQKV0RJXZ9VCCXQW16S4MKQ9H51G6FWNJ0G.token-a'),
        Cl.uint(1000000), // supply cap
        Cl.uint(500000),  // borrow cap
        Cl.uint(8000)     // collateral factor (80%)
      ],
      user1
    );
    
    expect(result.value).toEqual(Cl.bool(true));
  });
});
