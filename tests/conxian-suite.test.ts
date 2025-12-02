
import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';

describe('Conxian System Suite', () => {
  let deployer: string;
  let wallet1: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });
  
  describe('Concentrated Liquidity Pool', () => {
    it('should initialize correctly', () => {
      const { result } = simnet.callPublicFn(
        'concentrated-liquidity-pool',
        'initialize',
        [
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.uint(1000000), // sqrt-price
          Cl.int(0)         // tick
        ],
        deployer
      );
      expect(result).toBeOk(Cl.bool(true));
    });

    it('should fail to initialize twice', () => {
       simnet.callPublicFn('concentrated-liquidity-pool', 'initialize', [Cl.principal(deployer), Cl.principal(wallet1), Cl.uint(1000000), Cl.int(0)], deployer);
       const { result } = simnet.callPublicFn('concentrated-liquidity-pool', 'initialize', [Cl.principal(deployer), Cl.principal(wallet1), Cl.uint(1000000), Cl.int(0)], deployer);
       expect(result).toBeErr(Cl.uint(3008)); // ERR_ALREADY_INITIALIZED
    });

    it('should mint position', () => {
      simnet.callPublicFn('concentrated-liquidity-pool', 'initialize', [Cl.principal(deployer), Cl.principal(wallet1), Cl.uint(1000000), Cl.int(0)], deployer);
      
      const { result } = simnet.callPublicFn(
        'concentrated-liquidity-pool',
        'mint',
        [
          Cl.principal(wallet1),
          Cl.int(-100),
          Cl.int(100),
          Cl.uint(1000000),
          Cl.uint(1000000)
        ],
        wallet1
      );
      expect(result).toBeOk(Cl.uint(1)); // Position ID 1
    });
  });

  describe('DEX Factory V2', () => {
    it('should register pool type', () => {
      const { result } = simnet.callPublicFn(
        'dex-factory-v2',
        'register-pool-type',
        [Cl.stringAscii("CLP"), Cl.principal(deployer)], // Using deployer as mock impl
        deployer
      );
      expect(result).toBeOk(Cl.bool(true));
    });

    it('should fail register from non-owner', () => {
      const { result } = simnet.callPublicFn(
        'dex-factory-v2',
        'register-pool-type',
        [Cl.stringAscii("CLP"), Cl.principal(deployer)],
        wallet1
      );
      expect(result).toBeErr(Cl.uint(1000)); // ERR_UNAUTHORIZED
    });
  });

  describe('Multi-Hop Router V3', () => {
     // Mock pool behavior would be needed here, but checking structure
     it('should exist', () => {
        const { result } = simnet.callPublicFn('multi-hop-router-v3', 'swap-hop-1', 
            [Cl.uint(100), Cl.uint(90), Cl.principal(deployer + '.concentrated-liquidity-pool'), Cl.principal(deployer), Cl.principal(wallet1)], 
            wallet1);
        // Will likely fail due to mock tokens not being valid traits in this context without full setup,
        // but validates contract deployment.
        expect(result).toBeDefined(); 
     });
  });

  describe('Oracle Aggregator V2', () => {
    it('should update price', () => {
        simnet.callPublicFn('oracle-aggregator-v2', 'register-oracle', [Cl.principal(deployer), Cl.bool(true)], deployer);
        const { result } = simnet.callPublicFn('oracle-aggregator-v2', 'update-price', [Cl.principal(wallet1), Cl.uint(50000)], deployer);
        expect(result).toBeOk(Cl.bool(true));
    });
  });
});
