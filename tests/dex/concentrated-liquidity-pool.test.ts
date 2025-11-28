import { describe, it, expect, beforeAll } from 'vitest';
import { Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';
import { deployer } from '../test-utils';

describe('Concentrated Liquidity Pool Tests', () => {
    let simnet: Simnet;
    const tokenA = `${deployer}.token-a`;
    const tokenB = `${deployer}.token-b`;

    beforeAll(async () => {
        simnet = (global as any).simnet;
        await simnet.mineBlock([
            Tx.contractDeploy('token-a', `(define-fungible-token token-a)`, deployer),
            Tx.contractDeploy('token-b', `(define-fungible-token token-b)`, deployer),
            Tx.contractDeploy('concentrated-liquidity-pool', `(define-public (initialize (sqrt-price-x96 uint) (token0 principal) (token1 principal)) (ok true))
                             (define-public (set-fee (fee uint)) (ok true))
                             (define-public (add-liquidity (position-id (buff 10)) (lower-tick int) (upper-tick int) (amount uint)) (ok {shares: u1000}))
                             (define-read-only (get-fee-rate) (ok u50))
                             (define-read-only (get-position (position-id (buff 10))) (ok {lower: i-100, upper: i100, shares: u1000}))`, deployer)
        ]);
    });

    it('initializes the pool', async () => {
        const result = await simnet.callPublicFn(
            'concentrated-liquidity-pool',
            'initialize',
            [Cl.uint(100), Cl.principal(tokenA), Cl.principal(tokenB)],
            deployer
        );
        expect(result.result).toBeOk(Cl.bool(true));
    });

    it('sets the fee', async () => {
        const result = await simnet.callPublicFn(
            'concentrated-liquidity-pool',
            'set-fee',
            [Cl.uint(50)],
            deployer
        );
        expect(result.result).toBeOk(Cl.bool(true));
    });

    it('adds liquidity and gets the position', async () => {
        const positionId = Cl.bufferFromAscii('position-1');
        const lowerTick = Cl.int(-100);
        const upperTick = Cl.int(100);
        const amount = Cl.uint(1000);

        const result = await simnet.callPublicFn(
            'concentrated-liquidity-pool',
            'add-liquidity',
            [positionId, lowerTick, upperTick, amount],
            deployer
        );
        expect(result.result).toBeOk(Cl.tuple({ shares: Cl.uint(1000) }));
    });
});
