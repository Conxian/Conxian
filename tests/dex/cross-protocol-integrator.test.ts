import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { Simnet, Tx } from '@stacks/clarinet-sdk';

// NOTE: These tests assume simnet helpers are available in the test environment

describe('Cross Protocol Integrator Tests', () => {
    let simnet: Simnet;

    beforeAll(async () => {
        simnet = (global as any).simnet;
    });
  const deployer = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
  const user = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
  const mockTokenA = `${deployer}.mock-token-a`;
  const mockYieldOptimizer = `${deployer}.mock-yield-optimizer`;
  const mockCircuitBreaker = `${deployer}.mock-circuit-breaker`;
  const mockRbac = `${deployer}.mock-rbac`;

  beforeEach(async () => {
    // Deploy mock contracts
    await simnet.mineBlock([
        Tx.contractDeploy('mock-token-a', `(define-fungible-token mock-token-a) (define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buffer 32)))) (begin (ft-transfer? mock-token-a amount sender recipient) (ok true)))`, deployer),
        Tx.contractDeploy('mock-yield-optimizer', `(define-public (find-best-strategy (a principal) (b principal)) (ok (some tx-sender)))`, deployer),
        Tx.contractDeploy('mock-circuit-breaker', `(define-data-var circuit-open bool false) (define-public (set-circuit-open (status bool)) (ok (var-set circuit-open status))) (define-read-only (is-circuit-open) (ok (var-get circuit-open)))`, deployer),
        Tx.contractDeploy('mock-rbac', `(define-data-var owner principal tx-sender) (define-read-only (has-role (role (string-ascii 32))) (ok (is-eq role "contract-owner")))`, deployer),
    ]);

    // Initialize cross-protocol-integrator
    simnet.callPublicFn('cross-protocol-integrator', 'set-rbac-contract', [Cl.principal(mockRbac)], deployer);
    simnet.callPublicFn('cross-protocol-integrator', 'set-yield-optimizer-contract', [Cl.principal(mockYieldOptimizer)], deployer);
    simnet.callPublicFn('cross-protocol-integrator', 'set-circuit-breaker', [Cl.principal(mockCircuitBreaker)], deployer);
  });

  it('registers a strategy', () => {
    const block = simnet.mineBlock([
      {
        contract: 'cross-protocol-integrator',
        fun: 'register-strategy',
        args: [Cl.principal(user), Cl.principal(mockTokenA), Cl.uint(1)],
        sender: deployer,
      },
    ]);
    expect(block.receipts[0].result).toBeOk(Cl.uint(1));
  });

  it('deposits and withdraws', () => {
    simnet.callPublicFn('cross-protocol-integrator', 'register-strategy', [Cl.principal(user), Cl.principal(mockTokenA), Cl.uint(1)], deployer);

    const depositBlock = simnet.mineBlock([
      {
        contract: 'cross-protocol-integrator',
        fun: 'deposit',
        args: [Cl.uint(1), Cl.principal(mockTokenA), Cl.uint(1000)],
        sender: user,
      },
    ]);
    expect(depositBlock.receipts[0].result).toBeOk(Cl.bool(true));

    const withdrawBlock = simnet.mineBlock([
        {
            contract: 'cross-protocol-integrator',
            fun: 'withdraw',
            args: [Cl.uint(1), Cl.principal(mockTokenA), Cl.uint(500)],
            sender: user,
        },
    ]);
    expect(withdrawBlock.receipts[0].result).toBeOk(Cl.bool(true));
    });
});
