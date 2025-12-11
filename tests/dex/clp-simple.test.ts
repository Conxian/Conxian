
import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('CLP Simple', () => {
    beforeAll(async () => {
        simnet = await initSimnet('Clarinet.toml', false, {
            trackCosts: false,
            trackCoverage: false,
        });
    });

    beforeEach(async () => {
        await simnet.initSession(process.cwd(), 'Clarinet.toml');
        const accounts = simnet.getAccounts();
        deployer = accounts.get('deployer')!;
        wallet1 = accounts.get('wallet_1')!;
    });

    it('initializes', () => {
        const receipt = simnet.callPublicFn('concentrated-liquidity-pool', 'initialize', [
            Cl.contractPrincipal(deployer, 'mock-token'),
            Cl.contractPrincipal(deployer, 'mock-usda-token'),
            Cl.uint(79228162514264337593543950336n),
            Cl.int(0),
            Cl.uint(3000),
        ], deployer);
        expect(receipt.result).toBeOk(Cl.bool(true));
    });
});
