import { Clarinet, Tx, Chain, Account, types } from '@stacks/clarinet-sdk';
import { assertEquals } from '@stacks/transactions';

Clarinet.test({
  name: 'bond-factory: basic test',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user = accounts.get('user')!;

    // Deploy contract
    const contract = chain.getContract('bond-factory');

    // Test create-bond with valid parameters
    let block = chain.mineBlock([
      Tx.contractCall(
        'bond-factory',
        'create-bond',
        [
          types.principal(user.address), // issuer
          types.uint(1000), // principal-amount
          types.uint(5), // coupon-rate
          types.uint(100), // issue-block
          types.uint(200), // maturity-blocks
          types.uint(1500), // collateral-amount
          types.principal('ST000000000000000000002AMW42H'), // collateral-token
          types.bool(true), // is-callable
          types.uint(10), // call-premium
          types.ascii('Test Bond'), // name
          types.ascii('TBOND'), // symbol
          types.uint(6), // decimals
          types.uint(1000) // face-value
        ],
        deployer.address
      )
    ]);

    // Verify event emission
    block.receipts[0].events.expectPrintEvent(
      contract.principal, 
      types.tuple({
        event: types.ascii('bond-created'),
        sender: types.principal(deployer.address),
        'bond-contract': types.principal(`${contract.principal}.bond-0`),
        'block-height': types.uint(1)
      })
    );

    // Test get-bond-details
    const bondContract = `${contract.principal}.bond-0`;
    const bondDetails = chain.callReadOnlyFn(
      'bond-factory',
      'get-bond-details',
      [types.principal(bondContract)],
      user.address
    ); 

    assertEquals(bondDetails, types.tuple({
      'issuer': types.principal(user.address),
      'principal-amount': types.uint(1000),
      'coupon-rate': types.uint(5),
      'issue-block': types.uint(100),
      'maturity-block': types.uint(300), // issue-block + maturity-blocks
      'collateral-amount': types.uint(1500),
      'collateral-token': types.principal('ST000000000000000000002AMW42H'),
      'status': types.ascii('active'),
      'is-callable': types.bool(true),
      'call-premium': types.uint(10),
      'bond-contract': types.principal(bondContract),
      'name': types.ascii('Test Bond'),
      'symbol': types.ascii('TBOND'),
      'decimals': types.uint(6),
      'face-value': types.uint(1000)
    }));

    // Test get-all-bonds
    const allBonds = chain.callReadOnlyFn(
      'bond-factory',
      'get-all-bonds',
      [],
      user.address
    );
    assertEquals(allBonds, types.list([types.principal(bondContract)]));
  }
});

/*
Clarinet.test({
  name: 'bond-factory: test safe math functions',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const contract = chain.getContract('bond-factory');

    // Test safe-add
    let result = chain.callReadOnlyFn('bond-factory', 'safe-add', [types.uint(5), types.uint(3)], accounts.get('deployer')!.address);
    assertEquals(result, types.ok(types.uint(8)));

    // Test safe-add overflow
    result = chain.callReadOnlyFn('bond-factory', 'safe-add', [types.uint(100), types.uint(200)], accounts.get('deployer')!.address);
    assertEquals(result, types.err(types.uint(1))); // ERR_OVERFLOW

    // Test safe-sub
    result = chain.callReadOnlyFn('bond-factory', 'safe-sub', [types.uint(5), types.uint(3)], accounts.get('deployer')!.address);
    assertEquals(result, types.ok(types.uint(2)));

    // Test safe-sub underflow
    result = chain.callReadOnlyFn('bond-factory', 'safe-sub', [types.uint(3), types.uint(5)], accounts.get('deployer')!.address);
    assertEquals(result, types.err(types.uint(2))); // ERR_UNDERFLOW
  }
});
*/