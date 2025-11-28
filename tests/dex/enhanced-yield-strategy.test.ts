import { describe, it, expect, beforeAll } from 'vitest';
import { Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';
import { deployer, user1 } from '../test-utils';

describe('Enhanced Yield Strategy', () => {
  let simnet: Simnet;

  beforeAll(async () => {
    simnet = (global as any).simnet;
    await simnet.deploy({
        contractName: 'test-token',
        contractSource: `(define-fungible-token test-token)
                         (define-public (mint (amount uint) (recipient principal)) (ft-mint? test-token amount recipient))
                         (define-public (approve (spender principal) (amount uint)) (ok true))`,
        sender: deployer
    });
    await simnet.deploy({
        contractName: 'enhanced-yield-strategy',
        contractSource: `(define-public (deposit (token <sip-010-ft-trait>) (amount uint)) (ok amount))
                         (define-public (withdraw (token <sip-010-ft-trait>) (amount uint)) (ok amount))
                         (define-public (harvest) (ok true))
                         (define-public (pause) (ok true))
                         (define-public (set-performance-fee (fee uint)) (ok true))
                         (define-read-only (get-tvl) (ok u1000))`,
        sender: deployer
    });
  });

  it.skip('should have tests', () => {});
});
