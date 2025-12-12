import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Dimensional DeFi System', () => {
  beforeAll(async () => {
    // Initialize Clarinet simnet directly for this test suite
    simnet = await initSimnet('Clarinet.toml', false, {
      trackCosts: false,
      trackCoverage: false,
    });
  });

  beforeEach(async () => {
    // Reset session before each test to ensure isolation
    await simnet.initSession(process.cwd(), 'Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1') || 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
  });

  describe('dim-registry', () => {
    it('should allow deployer to register a new dimension', () => {
      const receipt = simnet.callPublicFn('dim-registry', 'register-dimension', [
        Cl.uint(1),
        Cl.uint(100),
      ], deployer);
      expect(receipt.result).toBeOk(Cl.uint(1));
    });

    it('should not allow non-deployer to register a new dimension', () => {
      const receipt = simnet.callPublicFn('dim-registry', 'register-dimension', [
        Cl.uint(2),
        Cl.uint(100),
      ], wallet1);
      expect(receipt.result).toBeErr(Cl.uint(800)); // ERR_UNAUTHORIZED
    });

    it('should not allow registering the same dimension twice', () => {
      simnet.callPublicFn('dim-registry', 'register-dimension', [
        Cl.uint(3),
        Cl.uint(100),
      ], deployer);
      const receipt = simnet.callPublicFn('dim-registry', 'register-dimension', [
        Cl.uint(3),
        Cl.uint(100),
      ], deployer);
      expect(receipt.result).toBeErr(Cl.uint(809)); // ERR_DIMENSION_EXISTS
    });

    it('should allow deployer to update weight', () => {
      simnet.callPublicFn('dim-registry', 'register-dimension', [
        Cl.uint(4),
        Cl.uint(100),
      ], deployer);
      const receipt = simnet.callPublicFn('dim-registry', 'update-dimension-weight', [
        Cl.uint(4),
        Cl.uint(200),
      ], deployer);
      expect(receipt.result).toBeOk(Cl.bool(true));
    });

    it('should not allow non-oracle principal to update weight', () => {
      // oracle-principal defaults to deployer, so wallet1 should be unauthorized
      simnet.callPublicFn('dim-registry', 'register-dimension', [
        Cl.uint(5),
        Cl.uint(100),
      ], deployer);
      const receipt = simnet.callPublicFn('dim-registry', 'update-dimension-weight', [
        Cl.uint(5),
        Cl.uint(200),
      ], wallet1);
      expect(receipt.result).toBeErr(Cl.uint(800)); // ERR_UNAUTHORIZED
    });

    it('should return the correct dimension weight by id', () => {
      simnet.callPublicFn('dim-registry', 'register-dimension', [
        Cl.uint(6),
        Cl.uint(150),
      ], deployer);
      const dim = simnet.callReadOnlyFn('dim-registry', 'get-dimension-weight', [
        Cl.uint(6),
      ], deployer);
      expect(dim.result).toBeOk(Cl.uint(150));
    });
  });
});
