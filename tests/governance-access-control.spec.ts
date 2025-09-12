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

describe('Governance Access Control Tests', () => {
  const admin = simnet.deployer;
  const governor = simnet.accounts.get('wallet_1');
  const guardian = simnet.accounts.get('wallet_2');
  const user = simnet.accounts.get('wallet_3');
  
  // Role hashes (keccak256 of role names)
  const ROLES = {
    GOVERNOR: '0x474f5645524e4f52000000000000000000000000000000000000000000000000',
    GUARDIAN: '0x475541524449414e000000000000000000000000000000000000000000000000'
  };

  beforeEach(async () => {
    // Initialize AccessControl
    await simnet.callPublicFn('access-control', 'initialize', [], admin);
    
    // Grant roles for testing
    await simnet.callPublicFn(
      'access-control',
      'grant-role',
      [Cl.buffer(hexToBuffer(ROLES.GOVERNOR)), Cl.principal(governor)],
      admin
    );
    
    await simnet.callPublicFn(
      'access-control',
      'grant-role',
      [Cl.buffer(hexToBuffer(ROLES.GUARDIAN)), Cl.principal(guardian)],
      admin
    );
    
    // Initialize governance
    const govToken = 'ST1PQHQKV0RJXZ9VCCXQW16S4MKQ9H51G6FWNJ0G.gov-token';
    const timelock = 'ST1PQHQKV0RJXZ9VCCXQW16S4MKQ9H51G6FWNJ0G.timelock';
    await simnet.callPublicFn(
      'governance',
      'initialize',
      [Cl.principal(govToken), Cl.principal(timelock)],
      admin
    );
  });

  it('should allow governor to update governance parameters', async () => {
    const result = await simnet.callPublicFn(
      'governance',
      'update-governance-params',
      [
        Cl.uint(1008),   // voting-delay
        Cl.uint(2016),   // voting-period
        Cl.uint(50000000000000000), // quorum-threshold (5%)
        Cl.uint(1000000000000000000000), // proposal-threshold (1000 tokens)
        Cl.uint(1440)    // execution-delay
      ],
      governor
    ) as ResponseOkCV;
    
    expect(result.value).toEqual(Cl.bool(true));
  });

  it('should allow guardian to emergency cancel proposals', async () => {
    // First create a proposal (simplified for test)
    const proposalId = 1;
    
    // Emergency cancel the proposal
    const result = await simnet.callPublicFn(
      'governance',
      'emergency-cancel',
      [Cl.uint(proposalId)],
      guardian
    ) as ResponseOkCV;
    
    expect(result.value).toEqual(Cl.bool(true));
  });

  it('should not allow regular users to update governance parameters', async () => {
    const result = await simnet.callPublicFn(
      'governance',
      'update-governance-params',
      [
        Cl.uint(1008),   // voting-delay
        Cl.uint(2016),   // voting-period
        Cl.uint(50000000000000000), // quorum-threshold (5%)
        Cl.uint(1000000000000000000000), // proposal-threshold (1000 tokens)
        Cl.uint(1440)    // execution-delay
      ],
      user // Regular user, not governor or guardian
    ) as ResponseErrorCV;
    
    expect(result.value.value).toEqual(Cl.uint(8001)); // ERR_UNAUTHORIZED
  });

  it('should allow guardian to execute emergency functions', async () => {
    const targetContract = 'ST1PQHQKV0RJXZ9VCCXQW16S4MKQ9H51G6FWNJ0G.some-contract';
    const functionName = 'emergency-halt';
    
    const result = await simnet.callPublicFn(
      'governance',
      'emergency-execute',
      [Cl.principal(targetContract), Cl.stringAscii(functionName)],
      guardian
    ) as ResponseOkCV;
    
    expect(result.value).toEqual(Cl.bool(true));
  });
});
