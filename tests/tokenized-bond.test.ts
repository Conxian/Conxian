import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.125.0/testing/asserts.ts';

const CONTRACT_NAME = 'tokenized-bond';
const BOND_DECIMALS = 6;
const INITIAL_SUPPLY = 1_000_000 * 10 ** BOND_DECIMALS;
const MATURITY_BLOCKS = 10_000;
const COUPON_RATE = 5 * 10 ** BOND_DECIMALS; // 5%
const COUPON_FREQUENCY = 1_000; // blocks
const FACE_VALUE = 100 * 10 ** BOND_DECIMALS;

Clarinet.test({
  name: 'Tokenized Bond - Basic Functionality',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Deploy a mock token for testing
    const mockToken = chain.deployContract(
      'mock-token',
      'mock-token.clar',
      deployer.address
    );

    // Initialize the bond contract
    const block = chain.mineBlock([
      Tx.contractCall(
        CONTRACT_NAME,
        'issue-bond',
        [
          types.ascii('Test Bond'),
          types.ascii('TBOND'),
          types.uint(BOND_DECIMALS),
          types.uint(INITIAL_SUPPLY),
          types.uint(MATURITY_BLOCKS),
          types.uint(COUPON_RATE),
          types.uint(COUPON_FREQUENCY),
          types.uint(FACE_VALUE),
          types.principal(mockToken.address)
        ],
        deployer.address
      )
    ]);

    // Verify the bond was issued
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Test basic token functionality
    const transferBlock = chain.mineBlock([
      Tx.contractCall(
        CONTRACT_NAME,
        'transfer',
        [
          types.uint(1000),
          types.principal(deployer.address),
          types.principal(wallet1.address),
          types.none()
        ],
        deployer.address
      )
    ]);

    transferBlock.receipts[0].result.expectOk().expectBool(true);
  }
});

// Add more test cases for:
// - Coupon payments
// - Maturity redemption
// - Edge cases
// - Access control
// - Pause functionality
// - Reentrancy protection
