import { Cl, ClarityType, ResponseOkCV, ResponseErrorCV } from '@stacks/transactions';
import { describe, it, expect, beforeEach } from 'vitest';
import { hexToBuffer } from '../src/utils';

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

describe('DEX Factory Access Control Tests', () => {
  const admin = simnet.deployer;
  const dexAdmin = simnet.accounts.get('wallet_1');
  const feeManager = simnet.accounts.get('wallet_2');
  const poolManager = simnet.accounts.get('wallet_3');
  const user = 'ST2PHCPANVT8DVPSF5BHMCER5PRA4V7JTTX0NMPAM';
  
  // Role hashes (keccak256 of role names)
  const ROLES = {
    DEX_ADMIN: '0x4445585f41444d494e0000000000000000000000000000000000000000000000',
    FEE_MANAGER: '0x4645455f4d414e41474552000000000000000000000000000000000000000000',
    POOL_MANAGER: '0x504f4f4c5f4d414e414745520000000000000000000000000000000000000000'
  };

  const TOKEN_A = 'ST1PQHQKV0RJXZ9VCCXQW16S4MKQ9H51G6FWNJ0G.token-a';
  const TOKEN_B = 'ST1PQHQKV0RJXZ9VCCXQW16S4MKQ9H51G6FWNJ0G.token-b';

  beforeEach(async () => {
    // Initialize AccessControl
    await simnet.callPublicFn('access-control', 'initialize', [], admin);
    
    // Grant roles for testing
    await simnet.callPublicFn(
      'access-control',
      'grant-role',
      [Cl.buffer(hexToBuffer(ROLES.DEX_ADMIN)), Cl.principal(dexAdmin)],
      admin
    );
    
    await simnet.callPublicFn(
      'access-control',
      'grant-role',
      [Cl.buffer(hexToBuffer(ROLES.FEE_MANAGER)), Cl.principal(feeManager)],
      admin
    );
    
    await simnet.callPublicFn(
      'access-control',
      'grant-role',
      [Cl.buffer(hexToBuffer(ROLES.POOL_MANAGER)), Cl.principal(poolManager)],
      admin
    );
    
    // Initialize DEX factory
    await simnet.callPublicFn(
      'dex-factory',
      'initialize',
      [],
      admin
    );
  });

  it('should allow pool manager to create pools', async () => {
    const result = await simnet.callPublicFn(
      'dex-factory',
      'create-pool',
      [
        Cl.uint(1), // POOL_TYPE_CONSTANT_PRODUCT
        Cl.principal(TOKEN_A),
        Cl.principal(TOKEN_B),
        Cl.uint(30), // 0.3% fee
        Cl.uint(2 ** 96), // sqrtPriceUpper
        Cl.uint(1),        // sqrtPriceLower
        Cl.uint(10)        // tickSpacing
      ],
      poolManager
    ) as ResponseOkCV;
    
    expect(result.value.type).toEqual(Cl.ClarityType.ResponseOk);
  });

  it('should allow fee manager to update fees', async () => {
    const newFee = 50; // 0.5%
    const result = await simnet.callPublicFn(
      'dex-factory',
      'set-fee',
      [Cl.uint(newFee)],
      feeManager
    ) as ResponseOkCV;
    
    expect(result.value).toEqual(Cl.bool(true));
  });

  it('should allow DEX admin to update protocol fees', async () => {
    const newProtocolFee = 10; // 0.1%
    const result = await simnet.callPublicFn(
      'dex-factory',
      'set-protocol-fee',
      [Cl.uint(newProtocolFee)],
      dexAdmin
    ) as ResponseOkCV;
    
    expect(result.value).toEqual(Cl.bool(true));
  });

  it('should not allow regular users to create pools', async () => {
    const result = await simnet.callPublicFn(
      'dex-factory',
      'create-pool',
      [
        Cl.uint(1), // POOL_TYPE_CONSTANT_PRODUCT
        Cl.principal(TOKEN_A),
        Cl.principal(TOKEN_B),
        Cl.uint(30), // 0.3% fee
        Cl.uint(2 ** 96), // sqrtPriceUpper
        Cl.uint(1),        // sqrtPriceLower
        Cl.uint(10)        // tickSpacing
      ],
      user // Regular user without roles
    ) as ResponseErrorCV;
    
    expect(result.value.value).toEqual(Cl.uint(1001)); // ERR_UNAUTHORIZED
  });

  it('should not allow non-admins to update fees', async () => {
    const newFee = 50; // 0.5%
    const result = await simnet.callPublicFn(
      'dex-factory',
      'set-fee',
      [Cl.uint(newFee)],
      user // Regular user without FEE_MANAGER role
    ) as ResponseErrorCV;
    
    expect(result.value.value).toEqual(Cl.uint(1001)); // ERR_UNAUTHORIZED
  });
});
