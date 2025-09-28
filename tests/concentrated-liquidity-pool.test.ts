import { Clarinet, Tx, Chain, Account, types } from './utils/setup';
import { Pool } from './utils/pool';

Clarinet.test('concentrated-liquidity-pool: create-pool and mint-position should work correctly', () => {
    const accounts = Clarinet.getAccounts();
    const deployer = accounts.deployer;
    const user1 = accounts.wallet_1;

    const poolContract = deployer.address + '.concentrated-liquidity-pool';
    const tokenX = deployer.address + '.token-a';
    const tokenY = deployer.address + '.token-b';

    // 1. Create a new pool
    let block = Clarinet.simnet.block({
        transactions: [
            Tx.contractCall(
                'concentrated-liquidity-pool',
                'create-pool',
                [
                    types.principal(tokenX),
                    types.principal(tokenY),
                    types.principal(deployer.address), // factory-address
                    types.uint(100), // fee-bps (0.01%)
                    types.uint(1), // tick-spacing
                    types.uint(100000000), // initial-price (1.0)
                    types.int(-887272), // start-tick
                    types.int(887272),  // end-tick
                    types.uint(0) // pool-id (will be u0 for the first pool)
                ],
                deployer.address
            ),
        ],
    });
    block.receipts[0].result.expectOk().expectUint(0); // Expecting pool ID 0

    // 2. Mint a new position
    block = Clarinet.simnet.block({
        transactions: [
            Tx.contractCall(
                'concentrated-liquidity-pool',
                'mint-position',
                [
                    types.uint(0), // pool-id
                    types.int(-100), // tick-lower
                    types.int(100),  // tick-upper
                    types.uint(100000000), // amount-x-desired
                    types.uint(100000000), // amount-y-desired
                    types.uint(0),   // amount-x-min
                    types.uint(0)    // amount-y-min
                ],
                user1.address
            )
        ]
    });
    block.receipts[0].result.expectOk().expectUint(0); // Expecting position ID 0

    // Further assertions to check:
    // - The liquidity minted
    // - The amounts of token0 and token1 transferred
    // - The position NFT ownership

    // 3. Test Case: Attempt to mint with invalid tick range (e.g., lowerTick >= upperTick)
    block = Clarinet.simnet.block({
        transactions: [
            Tx.contractCall(
                'concentrated-liquidity-pool',
                'mint-position',
                [
                    types.uint(0), // pool-id
                    types.int(100), // tick-lower
                    types.int(-100),  // tick-upper
                    types.uint(1000), // amount-x-desired
                    types.uint(1000), // amount-y-desired
                    types.uint(0),   // amount-x-min
                    types.uint(0)    // amount-y-min
                ],
                user1.address
            )
        ]
    });
    block.receipts[0].result.expectErr().expectUint(1000); // Assuming ERR_INVALID_TICK_RANGE = 1000

    // 4. Test Case: Mint with zero amounts (should fail or result in zero liquidity)
    block = Clarinet.simnet.block({
        transactions: [
            Tx.contractCall(
                'concentrated-liquidity-pool',
                'mint-position',
                [
                    types.uint(0), // pool-id
                    types.int(-10), // tick-lower
                    types.int(10),  // tick-upper
                    types.uint(0), // amount-x-desired
                    types.uint(0), // amount-y-desired
                    types.uint(0),   // amount-x-min
                    types.uint(0)    // amount-y-min
                ],
                user1.address
            )
        ]
    });
    block.receipts[0].result.expectErr().expectUint(1001); // Assuming ERR_INSUFFICIENT_LIQUIDITY = 1001
});

Clarinet.test('concentrated-liquidity-pool: collect-fees should correctly transfer fees', () => {
    const accounts = Clarinet.getAccounts();
    const deployer = accounts.deployer;
    const user1 = accounts.wallet_1;
    const user2 = accounts.wallet_2; // Another user to perform a swap

    const poolContract = deployer.address + '.concentrated-liquidity-pool';
    const tokenX = deployer.address + '.token-a';
    const tokenY = deployer.address + '.token-b';

    // 1. Create a new pool
    let block = Clarinet.simnet.block({
        transactions: [
            Tx.contractCall(
                'concentrated-liquidity-pool',
                'create-pool',
                [
                    types.principal(tokenX),
                    types.principal(tokenY),
                    types.principal(deployer.address), // factory-address
                    types.uint(100), // fee-bps (0.01%)
                    types.uint(1), // tick-spacing
                    types.uint(100000000), // initial-price (1.0)
                    types.int(-887272), // start-tick
                    types.int(887272),  // end-tick
                    types.uint(0) // pool-id (will be u0 for the first pool)
                ],
                deployer.address
            ),
            // Mint some tokens for user1 and user2
            Tx.contractCall('token-a', 'mint', [types.uint(1000000000000), types.principal(user1.address)], deployer.address),
            Tx.contractCall('token-b', 'mint', [types.uint(1000000000000), types.principal(user1.address)], deployer.address),
            Tx.contractCall('token-a', 'mint', [types.uint(1000000000000), types.principal(user2.address)], deployer.address),
            Tx.contractCall('token-b', 'mint', [types.uint(1000000000000), types.principal(user2.address)], deployer.address),

            // Approve tokens for the pool contract
            Tx.contractCall('token-a', 'set-allowance', [types.principal(poolContract), types.uint(1000000000000)], user1.address),
            Tx.contractCall('token-b', 'set-allowance', [types.principal(poolContract), types.uint(1000000000000)], user1.address),
            Tx.contractCall('token-a', 'set-allowance', [types.principal(poolContract), types.uint(1000000000000)], user2.address),
            Tx.contractCall('token-b', 'set-allowance', [types.principal(poolContract), types.uint(1000000000000)], user2.address),
        ],
    });
    block.receipts[0].result.expectOk().expectUint(0); // Expecting pool ID 0
    block.receipts[1].result.expectOk();
    block.receipts[2].result.expectOk();
    block.receipts[3].result.expectOk();
    block.receipts[4].result.expectOk();
    block.receipts[5].result.expectOk();
    block.receipts[6].result.expectOk();
    block.receipts[7].result.expectOk();
    block.receipts[8].result.expectOk();

    // 2. Mint a new position by user1
    block = Clarinet.simnet.block({
        transactions: [
            Tx.contractCall(
                'concentrated-liquidity-pool',
                'mint-position',
                [
                    types.uint(0), // pool-id
                    types.int(-100), // tick-lower
                    types.int(100),  // tick-upper
                    types.uint(100000000), // amount-x-desired
                    types.uint(100000000), // amount-y-desired
                    types.uint(0),   // amount-x-min
                    types.uint(0)    // amount-y-min
                ],
                user1.address
            )
        ]
    });
    block.receipts[0].result.expectOk().expectUint(0); // Expecting position ID 0

    // 3. User2 performs a swap to generate fees
    block = Clarinet.simnet.block({
        transactions: [
            Tx.contractCall(
                'concentrated-liquidity-pool',
                'swap-x-for-y',
                [
                    types.uint(0), // pool-id
                    types.uint(10000000), // amount-x-in
                    types.uint(1), // amount-y-min-out
                    types.principal(user2.address) // recipient
                ],
                user2.address
            )
        ]
    });
    block.receipts[0].result.expectOk();

    // 4. Collect fees by user1
    block = Clarinet.simnet.block({
        transactions: [
            Tx.contractCall(
                'concentrated-liquidity-pool',
                'collect-fees',
                [
                    types.uint(0) // position-id
                ],
                user1.address
            )
        ]
    });
    block.receipts[0].result.expectOk().expectTuple({
        'fees-x': types.uint(10000), // Expected fees after calculation (10000000 * 0.01%)
        'fees-y': types.uint(0)
    });

    // Further assertions to check:
    // - The amounts of token0 and token1 transferred to user1
    // - The fee-growth-inside-last-x/y updated in the position
});