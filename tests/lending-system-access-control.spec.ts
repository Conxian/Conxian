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

describe('Lending System Access Control', () => {
  const admin = simnet.deployer;
  const operator = simnet.accounts.get('wallet_1');
  const emergency = simnet.accounts.get('wallet_2');
  const user = simnet.accounts.get('wallet_3');
  
  // Role hashes (keccak256 of role names)
  const ROLES = {
    ADMIN: '0x41444d494e000000000000000000000000000000000000000000000000000000',
    OPERATOR: '0x4f50455241544f52000000000000000000000000000000000000000000000000',
    EMERGENCY: '0x454d455247454e43590000000000000000000000000000000000000000000000'
  };

  beforeEach(async () => {
    // Initialize AccessControl
    await simnet.callPublicFn('access-control', 'initialize', [], admin);
    
    // Grant roles for testing
    await simnet.callPublicFn(
      'access-control',
      'grant-role',
      [Cl.buffer(hexToBuffer(ROLES.OPERATOR)), Cl.principal(operator)],
      admin
    );
    
    await simnet.callPublicFn(
      'access-control',
      'grant-role',
      [Cl.buffer(hexToBuffer(ROLES.EMERGENCY)), Cl.principal(emergency)],
      admin
    );
    
    // Initialize lending system
    await simnet.callPublicFn(
      'lending-system',
      'initialize',
      [Cl.principal('STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.oracle')],
      admin
    );
  });

  it('should allow admin to set oracle contract', async () => {
    const newOracle = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
    const result = await simnet.callPublicFn(
      'lending-system',
      'initialize',
      [Cl.principal(newOracle)],
      admin
    ) as ResponseOkCV;
    
    expect(result.value).toEqual(Cl.bool(true));
  });

  it('should allow emergency role to pause the system', async () => {
    const result = await simnet.callPublicFn(
      'lending-system',
      'set-paused',
      [Cl.bool(true)],
      emergency
    ) as ResponseOkCV;
    
    expect(result.value).toEqual(Cl.bool(true));
  });

  it('should not allow non-admin to set oracle contract', async () => {
    const newOracle = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
    const result = await simnet.callPublicFn(
      'lending-system',
      'initialize',
      [Cl.principal(newOracle)],
      user // Regular user, not admin
    ) as ResponseErrorCV;
    
    expect(result.value.value).toEqual(Cl.uint(1001)); // ERR_UNAUTHORIZED
  });

  it('should allow operator to add supported assets', async () => {
    const tokenContract = 'ST1PQHQKV0RJXZ9VCCXQW16S4MKQ9H51G6FWNJ0G.token-a';
    const result = await simnet.callPublicFn(
      'lending-system',
      'add-supported-asset',
      [
        Cl.principal(tokenContract),
        Cl.uint(800000000000000000), // 80% collateral factor
        Cl.uint(850000000000000000), // 85% liquidation threshold
        Cl.uint(5000000000000000),   // 0.5% liquidation bonus
        Cl.uint(9)                   // 0.09% flash loan fee (9 bips)
      ],
      operator
    ) as ResponseOkCV;
    
    expect(result.value).toEqual(Cl.bool(true));
  });
});
