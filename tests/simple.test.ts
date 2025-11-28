import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { Simnet, Tx } from '@stacks/clarinet-sdk';

describe('Simple Contract Tests', () => {
    let simnet: Simnet;
    const deployer = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';

    beforeAll(async () => {
        simnet = (global as any).simnet;
    });

    it('deploys a simple contract', async () => {
        const block = await simnet.mineBlock([
            Tx.contractDeploy('simple-contract', '(define-public (hello) (ok "hello"))', deployer),
        ]);
        expect(block.receipts[0].result).toBeOk(Cl.stringAscii("hello"));
    });
});
