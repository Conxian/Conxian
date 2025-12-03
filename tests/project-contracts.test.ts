
import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;

describe('Concentrated Liquidity Pool Real Tests', () => {
  
  it('should initialize the pool', () => {
    const t0 = `${deployer}.token-a`; // Assuming token-a exists or use mock-token
    const t1 = `${deployer}.token-b`;
    
    // We need valid traits. 
    // Let's use mock-token if available in Clarinet.toml
    // Clarinet.toml has mock-token at contracts/mocks/mock-token.clar
    
    const token0 = `${deployer}.mock-token`;
    const token1 = `${deployer}.mock-token`; // Using same token for simplicity or create another

    const init = simnet.callPublicFn(
      'concentrated-liquidity-pool',
      'initialize',
      [
        Cl.principal(token0),
        Cl.principal(token1),
        Cl.uint(79228162514264337593543950336n), // Q96 (1.0)
        Cl.int(0),
        Cl.uint(30)
      ],
      deployer
    );
    
    expect(init.result).toBeOk(Cl.bool(true));
  });

  it('should add liquidity', () => {
    // First initialize
    const token0 = `${deployer}.mock-token`;
    const token1 = `${deployer}.mock-token`; // In real scenario, these should be different
    
    // Mint tokens to wallet1
    simnet.callPublicFn('mock-token', 'mint', [Cl.uint(1000000), Cl.principal(wallet1)], deployer);

    const addLiq = simnet.callPublicFn(
      'concentrated-liquidity-pool',
      'add-liquidity',
      [
        Cl.uint(1000),
        Cl.uint(1000),
        Cl.principal(token0), // Trait
        Cl.principal(token1)  // Trait
      ],
      wallet1
    );
    
    // Expect OK or error depending on setup (traits might fail if not same as initialized)
    // Since we initialized with mock-token, passing mock-token as trait should work IF mock-token implements sip-010.
    // contracts/mocks/mock-token.clar usually implements sip-010.
    
    // Note: The contract expects (contract-of token0-trait) to match var-get token0.
    // If we initialized with mock-token, both are mock-token.
    
    expect(addLiq.result).toBeOk(Cl.uint(1)); // Returns position ID 1
  });
  
  it('should swap', () => {
     const token0 = `${deployer}.mock-token`;
     const token1 = `${deployer}.mock-token`;
     
     // Perform swap
     const swap = simnet.callPublicFn(
        'concentrated-liquidity-pool',
        'swap',
        [
            Cl.uint(100),
            Cl.principal(token0),
            Cl.principal(token1)
        ],
        wallet1
     );
     
     expect(swap.result).toBeOk(Cl.uint(99)); // Roughly 100 minus fees? Or calculated amount.
  });
});

describe('Comprehensive Lending System Tests', () => {
    it('should supply assets', () => {
        const asset = `${deployer}.mock-token`;
        const amount = Cl.uint(1000);
        
        // Ensure wallet1 has tokens
        simnet.callPublicFn('mock-token', 'mint', [amount, Cl.principal(wallet1)], deployer);
        
        const supply = simnet.callPublicFn(
            'comprehensive-lending-system',
            'supply',
            [Cl.principal(asset), amount],
            wallet1
        );
        
        // This might fail if interest-rate-model is not initialized or if asset is not supported
        // But checking basic execution.
        // If it fails with specific error, we know it ran.
        expect(supply.result).toBeOk(Cl.bool(true));
    });
});
