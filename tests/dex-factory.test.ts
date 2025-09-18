import { Cl, ClarityType, ClarityValue, ResponseOk, ResponseError, TupleCV, uintCV, standardPrincipalCV, someCV, noneCV, contractPrincipalCV } from '@stacks/transactions';
import { describe, expect, it, beforeEach, beforeAll, afterEach } from 'vitest';
import { initSimnet } from '@hirosystems/clarinet-sdk';
import { Simnet } from '@hirosystems/clarinet-sdk';

// Helper function to parse response
const parseResponse = (response: any) => {
  if (response.type === ClarityType.ResponseOk) {
    return { ok: true, value: response.value };
  } else if (response.type === ClarityType.ResponseError) {
    return { ok: false, error: response.value };
  }
  return response;
};

describe('DEX Factory Tests', () => {
  let simnet: Simnet;
  let accounts: Map<string, any>;
  let deployer: any;
  let wallet1: any;
  let wallet2: any;
  let wallet3: any;

  // Contract principals
  let factoryContract: string;
  let tokenAContract: string;
  let tokenBContract: string;
  let poolTemplateContract: string;

  beforeAll(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get('deployer');
    wallet1 = accounts.get('wallet_1');
    wallet2 = accounts.get('wallet_2');
    wallet3 = accounts.get('wallet_3');

    // Deploy test tokens
    const tokenADeploy = await simnet.deployContract(
      'test-token-a',
      'tests/mocks/test-token-a.clar',
      null,
      deployer.address
    );
    tokenAContract = tokenADeploy.contract_id;

    const tokenBDeploy = await simnet.deployContract(
      'test-token-b',
      'tests/mocks/test-token-b.clar',
      null,
      deployer.address
    );
    tokenBContract = tokenBDeploy.contract_id;

    // Deploy pool template
    const poolDeploy = await simnet.deployContract(
      'pool-template',
      'contracts/dex/pool-template.clar',
      null,
      deployer.address
    );
    poolTemplateContract = poolDeploy.contract_id;

    // Deploy factory
    const factoryDeploy = await simnet.deployContract(
      'dex-factory',
      'contracts/dex/dex-factory.clar',
      null,
      deployer.address
    );
    factoryContract = factoryDeploy.contract_id;

    // Initialize test tokens
    await simnet.callPublicFn(
      'test-token-a',
      'initialize',
      [standardPrincipalCV(deployer.address), uintCV(1000000)],
      deployer.address
    );

    await simnet.callPublicFn(
      'test-token-b',
      'initialize',
      [standardPrincipalCV(deployer.address), uintCV(1000000)],
      deployer.address
    );
    
    // Set up access control
    await simnet.callPublicFn(
      'dex-factory',
      'set-access-control-contract',
      [standardPrincipalCV(deployer.address)],
      deployer.address
    );
  });

  describe('Access Control', () => {
    it('should allow deployer to set access control contract', async () => {
      const result = await simnet.callPublicFn(
        'dex-factory',
        'set-access-control-contract',
        [standardPrincipalCV(deployer.address)],
        deployer.address
      );
      expect(result.result).toBeOk(Cl.bool(true));
    });

    it('should not allow non-owner to set access control contract', async () => {
      const result = await simnet.callPublicFn(
        'dex-factory',
        'set-access-control-contract',
        [standardPrincipalCV(wallet1.address)],
        wallet1.address
      );
      expect(result.result).toBeErr(Cl.uint(1003)); // ERR_UNAUTHORIZED
    });
  });

  describe('Pool Creation', () => {
    beforeEach(async () => {
      // Set up access control before each test
      await simnet.callPublicFn(
        'dex-factory',
        'set-access-control-contract',
        [standardPrincipalCV(deployer.address)],
        deployer.address
      );
    });

    it('should create a new pool', async () => {
      const result = await simnet.callPublicFn(
        'dex-factory',
        'create-pool',
        [
          standardPrincipalCV(tokenAContract),
          standardPrincipalCV(tokenBContract),
          Cl.uint(30) // 0.3% fee
        ],
        deployer.address
      );
      
      const parsed = parseResponse(result.result);
      expect(parsed.ok).toBe(true);
      
      // Verify pool was created by checking the pools map
      const poolsMap = simnet.getMapEntry('dex-factory', 'pools', {
        'token-a': standardPrincipalCV(tokenAContract),
        'token-b': standardPrincipalCV(tokenBContract)
      });
      
      expect(poolsMap).toBeDefined();
    });

    it('should not allow creating a pool with the same tokens', async () => {
      const result = await simnet.callPublicFn(
        'dex-factory',
        'create-pool',
        [
          standardPrincipalCV(tokenAContract),
          standardPrincipalCV(tokenAContract),
          Cl.uint(30)
        ],
        deployer.address
      );
      
      expect(result.result).toBeErr(Cl.uint(2002)); // ERR_INVALID_TOKENS
    });

    it('should not allow creating a pool with invalid fee', async () => {
      const result = await simnet.callPublicFn(
        'dex-factory',
        'create-pool',
        [
          standardPrincipalCV(tokenAContract),
          standardPrincipalCV(tokenBContract),
          Cl.uint(10001) // Invalid fee > 100%
        ],
        deployer.address
      );
      
      expect(result.result).toBeErr(Cl.uint(2004)); // ERR_INVALID_FEE
    });
  });

  describe('Pool Operations', () => {
    let poolAddress: string;

    beforeEach(async () => {
      // Create a pool before each test
      await simnet.callPublicFn(
        'dex-factory',
        'set-access-control-contract',
        [standardPrincipalCV(deployer.address)],
        deployer.address
      );

      const result = await simnet.callPublicFn(
        'dex-factory',
        'create-pool',
        [
          standardPrincipalCV(tokenAContract),
          standardPrincipalCV(tokenBContract),
          Cl.uint(30) // 0.3% fee
        ],
        deployer.address
      );
      
      poolAddress = factoryContract; // In our simplified implementation, factory acts as pool
    });

    it('should allow adding liquidity', async () => {
      // Approve tokens first
      await simnet.callPublicFn(
        'test-token-a',
        'transfer',
        [
          Cl.uint(1000),
          Cl.standardPrincipal(deployer.address),
          Cl.standardPrincipal(poolAddress),
          noneCV()
        ],
        deployer.address
      );

      await simnet.callPublicFn(
        'test-token-b',
        'transfer',
        [
          Cl.uint(1000),
          Cl.standardPrincipal(deployer.address),
          Cl.standardPrincipal(poolAddress),
          noneCV()
        ],
        deployer.address
      );

      // Add liquidity
      const result = await simnet.callPublicFn(
        'dex-factory',
        'add-liquidity',
        [
          standardPrincipalCV(tokenAContract),
          standardPrincipalCV(tokenBContract),
          Cl.uint(1000),
          Cl.uint(1000),
          Cl.uint(1), // min amount
          Cl.uint(1), // min amount
          Cl.standardPrincipal(deployer.address),
          Cl.uint(1000) // deadline
        ],
        deployer.address
      );
      
      expect(result.result).toBeOk(Cl.tuple({
        'shares': Cl.uint(1000), // sqrt(1000 * 1000)
        'amount-a': Cl.uint(1000),
        'amount-b': Cl.uint(1000)
      }));
    });

    it('should allow swapping tokens', async () => {
      // First add liquidity
      await simnet.callPublicFn(
        'test-token-a',
        'transfer',
        [
          Cl.uint(1000),
          Cl.standardPrincipal(deployer.address),
          Cl.standardPrincipal(poolAddress),
          noneCV()
        ],
        deployer.address
      );

      await simnet.callPublicFn(
        'test-token-b',
        'transfer',
        [
          Cl.uint(1000),
          Cl.standardPrincipal(deployer.address),
          Cl.standardPrincipal(poolAddress),
          noneCV()
        ],
        deployer.address
      );

      await simnet.callPublicFn(
        'dex-factory',
        'add-liquidity',
        [
          standardPrincipalCV(tokenAContract),
          standardPrincipalCV(tokenBContract),
          Cl.uint(1000),
          Cl.uint(1000),
          Cl.uint(1),
          Cl.uint(1),
          Cl.standardPrincipal(deployer.address),
          Cl.uint(1000)
        ],
        deployer.address
      );

      // Perform swap
      const swapResult = await simnet.callPublicFn(
        'dex-factory',
        'swap-exact-tokens-for-tokens',
        [
          Cl.uint(100), // amount in
          Cl.uint(90),  // min amount out (expect ~99 after 0.3% fee)
          Cl.list([
            standardPrincipalCV(tokenAContract),
            standardPrincipalCV(tokenBContract)
          ]),
          Cl.standardPrincipal(deployer.address),
          Cl.uint(1000) // deadline
        ],
        deployer.address
      );
      
      expect(swapResult.result).toBeOk(Cl.tuple({
        'amounts': Cl.list([Cl.uint(100), Cl.uint(99)]) // 0.3% fee on 100 = 0.3, so ~99.7 out
      }));
    });
  });
});
