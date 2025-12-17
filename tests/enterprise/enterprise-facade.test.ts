
import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Enterprise Facade', () => {
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
    wallet1 = accounts.get('wallet_1') || 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
  });

  const token0 = 'mock-token';
  const token1 = 'mock-usda-token';

  it('should register a new institutional account', () => {
    const receipt = simnet.callPublicFn('enterprise-facade', 'register-account', [
      Cl.standardPrincipal(wallet1),
      Cl.uint(1),
      Cl.uint(1000000000), // Daily limit
    ], deployer);

    expect(receipt.result).toBeOk(Cl.bool(true));
  });

  it('should submit a TWAP order', () => {
    // 1. Register Account
    simnet.callPublicFn('enterprise-facade', 'register-account', [
      Cl.standardPrincipal(wallet1),
      Cl.uint(1),
      Cl.uint(1000000000), // Daily limit
    ], deployer);

    // 2. Submit TWAP
    const receipt = simnet.callPublicFn('enterprise-facade', 'submit-twap-order', [
      Cl.contractPrincipal(deployer, token0),
      Cl.contractPrincipal(deployer, token1),
      Cl.uint(100000), // Total
      Cl.uint(10),     // Interval blocks
      Cl.uint(10),     // Num intervals
    ], wallet1);

    expect(receipt.result).toBeOk(Cl.uint(1));
  });

  it('should submit an Iceberg order', () => {
    // 1. Register Account
    simnet.callPublicFn('enterprise-facade', 'register-account', [
      Cl.standardPrincipal(wallet1),
      Cl.uint(1),
      Cl.uint(1000000000), // Daily limit
    ], deployer);

    // 2. Submit Iceberg
    const receipt = simnet.callPublicFn('enterprise-facade', 'submit-iceberg-order', [
      Cl.contractPrincipal(deployer, token0),
      Cl.contractPrincipal(deployer, token1),
      Cl.uint(100000), // Total
      Cl.uint(10000),  // Visible
    ], wallet1);

    expect(receipt.result).toBeOk(Cl.uint(2));
  });

  it('should reset the daily spending limit after 144 blocks', () => {
    // 1. Register Account
    simnet.callPublicFn('enterprise-facade', 'register-account', [
      Cl.standardPrincipal(wallet1),
      Cl.uint(1),
      Cl.uint(1000), // Daily limit
    ], deployer);

    // 2. Spend up to the limit
    simnet.callPublicFn('enterprise-facade', 'submit-iceberg-order', [
      Cl.contractPrincipal(deployer, token0),
      Cl.contractPrincipal(deployer, token1),
      Cl.uint(1000), // Total
      Cl.uint(100),  // Visible
    ], wallet1);

    // 3. Advance the chain
    simnet.mineEmptyBlocks(144);

    // 4. Spend again
    const receipt = simnet.callPublicFn('enterprise-facade', 'submit-iceberg-order', [
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
        Cl.uint(500), // Total
        Cl.uint(50),  // Visible
    ], wallet1);

    expect(receipt.result).toBeOk(Cl.uint(4));
  });
});
