import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@0.31.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.125.0/testing/asserts.ts';

// Helper functions for test setup
export function setupTestEnv(chain: Chain, accounts: Map<string, Account>) {
  const deployer = accounts.get('deployer')!;
  const wallet1 = accounts.get('wallet_1')!;
  const wallet2 = accounts.get('wallet_2')!;
  
  // Deploy mock tokens
  const mockToken = deployMockToken(chain, deployer);
  
  // Deploy core contracts
  const core = deployCore(chain, deployer, mockToken);
  
  // Deploy lending module
  const lending = deployLending(chain, deployer, core, mockToken);
  
  // Initialize system
  initializeSystem(chain, deployer, { ...core, ...lending });
  
  return {
    ...core,
    ...risk,
    ...lending,
    mockToken,
    deployer,
    wallet1,
    wallet2
  };
}

function deployMockToken(chain: Chain, deployer: Account) {
  const receipt = chain.mineBlock([
    Tx.contractCall(
      'mock-token',
      'initialize',
      [types.principal(deployer.address)],
      deployer.address
    )
  ]);
  
  assertEquals(receipt.height, 2);
  return 'mock-token';
}

function deployCore(chain: Chain, deployer: Account, token: string) {
  // Deploy core contracts
  const contracts = {
    dimensionalCore: 'dimensional-engine',
    positionManager: 'position-manager'
  };
  
  // Initialize core contracts
  chain.mineBlock([
    Tx.contractCall(
      contracts.dimensionalCore,
      'initialize',
      [],
      deployer.address
    )
  ]);
  
  return contracts;
}

function deployLending(chain: Chain, deployer: Account, core: any, token: string) {
  const contracts = {
    lendingVault: 'dimensional-vault',
    enterpriseModule: 'enterprise-module'
  };
  
  // Initialize lending module
  chain.mineBlock([
    Tx.contractCall(
      contracts.lendingVault,
      'initialize',
      [
        types.principal(core.dimensionalCore),
        types.principal(token)
      ],
      deployer.address
    ),
    Tx.contractCall(
      contracts.enterpriseModule,
      'initialize',
      [types.principal(contracts.lendingVault)],
      deployer.address
    )
  ]);
  
  return contracts;
}

function initializeSystem(chain: Chain, deployer: Account, contracts: any) {
  // Set up initial parameters
  chain.mineBlock([
    // Configure oracle
    Tx.contractCall(
      contracts.dimensionalCore,
      'set-price',
      [types.principal(contracts.mockToken), types.uint(1_000000)], // 1.0 with 6 decimals
      deployer.address
    ),
    
    // Configure risk parameters
    Tx.contractCall(
    
    // Configure lending vault
    Tx.contractCall(
      contracts.lendingVault,
      'configure-asset',
      [
        types.principal(contracts.mockToken),
        types.tuple({
          'is-listed': types.bool(true),
          'collateral-factor': types.uint(7500), // 75%
          'reserve-factor': types.uint(1000), // 10%
          'liquidation-bonus': types.uint(10500) // 5%
        })
      ],
      deployer.address
    )
  ]);
}
