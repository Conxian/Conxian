import { describe, it, expect, beforeAll } from 'vitest';
import { Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';
import { deployer, user1 } from '../test-utils';

describe('Bond Factory Tests', () => {
    let simnet: Simnet;
    const collateralToken = 'ST000000000000000000002AMW42H';

    beforeAll(async () => {
        simnet = (global as any).simnet;
        await simnet.mineBlock([
            Tx.contractDeploy('bond-factory', `(define-public (create-bond (issuer principal) (principal-amount uint) (coupon-rate uint) (issue-block uint) (maturity-blocks uint) (collateral-amount uint) (collateral-token principal) (is-callable bool) (call-premium uint) (name (string-ascii 20)) (symbol (string-ascii 10)) (decimals uint) (face-value uint)) (ok .bond-0))`, deployer)
        ]);
    });

    it('creates a bond with valid parameters', async () => {
        const result = await simnet.callPublicFn(
            'bond-factory',
            'create-bond',
            [
                Cl.principal(user1), // issuer
                Cl.uint(1000), // principal-amount
                Cl.uint(5), // coupon-rate
                Cl.uint(100), // issue-block
                Cl.uint(200), // maturity-blocks
                Cl.uint(1500), // collateral-amount
                Cl.principal(collateralToken), // collateral-token
                Cl.bool(true), // is-callable
                Cl.uint(10), // call-premium
                Cl.stringAscii('Test Bond'), // name
                Cl.stringAscii('TBOND'), // symbol
                Cl.uint(6), // decimals
                Cl.uint(1000), // face-value
            ],
            deployer
        );
        expect(result.result).toBeOk(Cl.contractPrincipal(deployer, 'bond-0'));
    });
});
