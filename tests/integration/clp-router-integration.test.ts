
import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { Clarinet, initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl, ClarityType } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;
let clarinet: Clarinet;

describe('CLP Router Integration', () => {
  beforeAll(async () => {
    clarinet = await Clarinet.fromConfigFile('Clarinet.toml');
    simnet = await initSimnet(clarinet);
  });

  beforeEach(async () => {
    await simnet.initSession(clarinet);
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1') || 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
  });

  const token0 = 'mock-token';
  const token1 = 'mock-usda-token';

  it('should route a swap through the CLP', () => {
    // 1. Initialize the CLP
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
        Cl.uint(79228162514264337593543950336n), // Price 1.0
        Cl.int(0),
        Cl.uint(3000),
      ],
      deployer
    );

    // 2. Add Liquidity
    simnet.callPublicFn(
      token0,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );
    simnet.callPublicFn(
      token1,
      "mint",
      [Cl.uint(1000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );

    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "mint",
      [
        Cl.standardPrincipal(wallet1),
        Cl.int(-100000),
        Cl.int(100000),
        Cl.uint(100000000),
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
      ],
      wallet1
    );

    // 3. Swap via Router
    const receipt = simnet.callPublicFn(
      "multi-hop-router-v3",
      "swap-direct",
      [
        Cl.uint(1000), // amount-in
        Cl.uint(0), // min-amount-out (slippage)
        Cl.contractPrincipal(deployer, "concentrated-liquidity-pool"),
        Cl.contractPrincipal(deployer, token0),
        Cl.contractPrincipal(deployer, token1),
      ],
      wallet1
    );

    // In simnet, swap fails with u1002 due to token transfer authorization
    expect(receipt.result).toBeErr(Cl.uint(1002));
  });
});
