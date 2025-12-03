import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

// Core sanity and guard-rail tests for the comprehensive-lending-system.
describe('Comprehensive Lending System', () => {
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

  describe('zero-amount guard rails', () => {
    it('rejects zero-amount supply', () => {
      const res = simnet.callPublicFn('comprehensive-lending-system', 'supply', [
        // Asset trait parameter is not used for zero-amount guard; we can pass any SIP-010 contract
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(0),
      ], wallet1);

      // ERR_ZERO_AMOUNT = (err u1004)
      expect(res.result).toBeErr(Cl.uint(1004));
    });

    it('rejects zero-amount withdraw', () => {
      const res = simnet.callPublicFn('comprehensive-lending-system', 'withdraw', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(0),
      ], wallet1);
      expect(res.result).toBeErr(Cl.uint(1004));
    });

    it('rejects zero-amount borrow', () => {
      const res = simnet.callPublicFn('comprehensive-lending-system', 'borrow', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(0),
      ], wallet1);
      expect(res.result).toBeErr(Cl.uint(1004));
    });

    it('rejects zero-amount repay', () => {
      const res = simnet.callPublicFn('comprehensive-lending-system', 'repay', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(0),
      ], wallet1);
      expect(res.result).toBeErr(Cl.uint(1004));
    });
  });

  describe('read-only views on empty state', () => {
    it('returns zero supply balance for new users', () => {
      const bal = simnet.callReadOnlyFn('comprehensive-lending-system', 'get-user-supply-balance', [
        Cl.standardPrincipal(wallet1),
        Cl.contractPrincipal(deployer, 'cxd-token'),
      ], wallet1);

      expect(bal.result).toBeOk(Cl.uint(0));
    });

    it('returns zero borrow balance for new users', () => {
      const bal = simnet.callReadOnlyFn('comprehensive-lending-system', 'get-user-borrow-balance', [
        Cl.standardPrincipal(wallet1),
        Cl.contractPrincipal(deployer, 'cxd-token'),
      ], wallet1);

      expect(bal.result).toBeOk(Cl.uint(0));
    });

    it('returns a healthy default health factor', () => {
      const hf = simnet.callReadOnlyFn('comprehensive-lending-system', 'get-health-factor', [
        Cl.standardPrincipal(wallet1),
      ], wallet1);

      // Stub implementation returns u20000
      expect(hf.result).toBeOk(Cl.uint(20000));
    });
  });
});
