import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Funding Calculator', () => {
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

  describe('admin parameter configuration', () => {
    it('allows owner to set funding parameters within bounds', () => {
      const res = simnet.callPublicFn('funding-calculator', 'set-funding-parameters', [
        Cl.uint(144),   // 1-day interval
        Cl.uint(100),   // 1% max rate
        Cl.uint(500),   // 5% sensitivity
      ], deployer);

      expect(res.result).toBeOk(Cl.bool(true));
    });

    it('rejects invalid interval', () => {
      const res = simnet.callPublicFn('funding-calculator', 'set-funding-parameters', [
        Cl.uint(0),   // invalid
        Cl.uint(100),
        Cl.uint(500),
      ], deployer);

      // (err u5009) for invalid interval
      expect(res.result).toBeErr(Cl.uint(5009));
    });
  });

  describe('read-only views', () => {
    it('returns error when no funding history exists', () => {
      const cxd = Cl.contractPrincipal(deployer, 'cxd-token');
      const res = simnet.callReadOnlyFn('funding-calculator', 'get-current-funding-rate', [
        cxd,
      ], wallet1);

      // When no history is present, contract returns (err u5008)
      expect(res.result).toBeErr(Cl.uint(5008));
    });
  });
});
