import { Clarinet, Tx, Chain, Account, types } from "@stacks/clarinet-sdk";
import { assertEquals } from "vitest";

Clarinet.test({ name: "concentrated-liquidity-pool: initialize" }, async (t) => {
  const { chain, accounts } = t.context;
  const deployer = accounts.deployer;
  const fee = types.uint(100);
  const tokenA = types.principal("ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-a");
  const tokenB = types.principal("ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-b");

  let block = chain.mineBlock([
    Tx.contractCall(
      "concentrated-liquidity-pool",
      "initialize",
      [fee, tokenA, tokenB],
      deployer.address
    ),
  ]);
  block.receipts[0].result.expectOk().expectBool(true);
});

Clarinet.test({ name: "concentrated-liquidity-pool: set-fee" }, async (t) => {
  const { chain, accounts } = t.context;
  const deployer = accounts.deployer;
  const newFee = types.uint(50);

  let block = chain.mineBlock([
    Tx.contractCall(
      "concentrated-liquidity-pool",
      "set-fee",
      [newFee],
      deployer.address
    ),
  ]);
  block.receipts[0].result.expectOk().expectBool(true);

  const fee = chain.callReadOnlyFn(
    "concentrated-liquidity-pool",
    "get-fee-rate",
    [],
    deployer.address
  );
  fee.result.expectOk().expectUint(50);
});

Clarinet.test({ name: "concentrated-liquidity-pool: set-current-tick" }, async (t) => {
  const { chain, accounts } = t.context;
  const deployer = accounts.deployer;
  const newTick = types.int(1000);

  let block = chain.mineBlock([
    Tx.contractCall(
      "concentrated-liquidity-pool",
      "set-current-tick",
      [newTick],
      deployer.address
    ),
  ]);
  block.receipts[0].result.expectOk().expectBool(true);

  const tick = chain.callReadOnlyFn(
    "concentrated-liquidity-pool",
    "get-current-tick",
    [],
    deployer.address
  );
  tick.result.expectOk().expectInt(1000);
});

Clarinet.test({ name: "concentrated-liquidity-pool: add-liquidity and get-position" }, async (t) => {
  const { chain, accounts } = t.context;
  const deployer = accounts.deployer;
  const positionId = types.bufferFrom("position-1");
  const lowerTick = types.int(-100);
  const upperTick = types.int(100);
  const amount = types.uint(1000);

  let block = chain.mineBlock([
    Tx.contractCall(
      "concentrated-liquidity-pool",
      "add-liquidity",
      [positionId, lowerTick, upperTick, amount],
      deployer.address
    ),
  ]);
  block.receipts[0].result.expectOk().expectTuple({
    shares: types.uint(1000),
  });

  const position = chain.callReadOnlyFn(
    "concentrated-liquidity-pool",
    "get-position",
    [positionId],
    deployer.address
  );
  position.result.expectOk().expectTuple({
    lower: types.int(-100),
    upper: types.int(100),
    shares: types.uint(1000),
  });
});

Clarinet.test({ name: "concentrated-liquidity-pool: remove-liquidity" }, async (t) => {
  const { chain, accounts } = t.context;
  const deployer = accounts.deployer;
  const positionId = types.bufferFrom("position-1");
  const lowerTick = types.int(-100);
  const upperTick = types.int(100);
  const initialAmount = types.uint(1000);
  const removeAmount = types.uint(500);

  chain.mineBlock([
    Tx.contractCall(
      "concentrated-liquidity-pool",
      "add-liquidity",
      [positionId, lowerTick, upperTick, initialAmount],
      deployer.address
    ),
  ]);

  let block = chain.mineBlock([
    Tx.contractCall(
      "concentrated-liquidity-pool",
      "remove-liquidity",
      [positionId, removeAmount],
      deployer.address
    ),
  ]);
  block.receipts[0].result.expectOk().expectTuple({
    "amount-out": types.uint(500),
  });

  const position = chain.callReadOnlyFn(
    "concentrated-liquidity-pool",
    "get-position",
    [positionId],
    deployer.address
  );
  position.result.expectOk().expectTuple({
    lower: types.int(-100),
    upper: types.int(100),
    shares: types.uint(500),
  });
});

Clarinet.test({ name: "concentrated-liquidity-pool: swap" }, async (t) => {
  const { chain, accounts } = t.context;
  const deployer = accounts.deployer;
  const tokenA = types.principal("ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-a");
  const tokenB = types.principal("ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-b");
  const amountIn = types.uint(10000);

  // Initialize the pool with a fee
  chain.mineBlock([
    Tx.contractCall(
      "concentrated-liquidity-pool",
      "initialize",
      [types.uint(100), tokenA, tokenB],
      deployer.address
    ),
  ]);

  let block = chain.mineBlock([
    Tx.contractCall(
      "concentrated-liquidity-pool",
      "swap",
      [tokenA, tokenB, amountIn],
      deployer.address
    ),
  ]);
  block.receipts[0].result.expectOk().expectTuple({
    "amount-out": types.uint(9900),
  });
});

Clarinet.test({ name: "get-position returns error for invalid position ID (edge case)" }, async (t) => {
  const { chain, accounts } = t.context;
  const deployer = accounts.deployer;
  const invalidPositionId = types.bufferFrom("invalid-position-id-1234567890abcdef");

  const getPositionResult = await chain.callReadOnlyFn(
    "concentrated-liquidity-pool",
    "get-position",
    [invalidPositionId],
    deployer.address
  );

  getPositionResult.expectErr(types.uint(4)); // ERR_POSITION_NOT_FOUND
});

Clarinet.test({ name: "add-liquidity emits correct print event" }, async (t) => {
  const { chain, accounts } = t.context;
  const deployer = accounts.deployer;
  const positionId = types.bufferFrom("valid-position-id-1234567890abcdef");
  const lowerTick = types.int(-100);
  const upperTick = types.int(100);
  const amount = types.uint(1000);

  const addLiquidityTx = Tx.contractCall(
    "concentrated-liquidity-pool",
    "add-liquidity",
    [positionId, lowerTick, upperTick, amount],
    deployer.address
  );

  const result = await chain.mineBlock([addLiquidityTx]);
  const event = result.receipts[0].events[0];

  assertEquals(event.type, "print_event");
  assertEquals(event.data.value.event, "add_liquidity");
  assertEquals(event.data.value.sender, deployer.address);
  assertEquals(event.data.value["position-id"].hex, positionId.hex);
  assertEquals(event.data.value["lower-tick"], -100);
  assertEquals(event.data.value["upper-tick"], 100);
  assertEquals(event.data.value.amount, 1000);
  assertEquals(event.data.value.shares, 1000);
});

Clarinet.test({ name: "swap emits correct print event with fee calculation" }, async (t) => {
  const { chain, accounts } = t.context;
  const deployer = accounts.deployer;
  const tokenIn = types.principal("ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-a");
  const tokenOut = types.principal("ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-b");
  const amountIn = types.uint(10000);

  // Set fee to 30 bps first
  const setFeeTx = Tx.contractCall(
    "concentrated-liquidity-pool",
    "set-fee",
    [types.uint(30)],
    deployer.address
  );
  await chain.mineBlock([setFeeTx]);

  const swapTx = Tx.contractCall(
    "concentrated-liquidity-pool",
    "swap",
    [tokenIn, tokenOut, amountIn],
    deployer.address
  );

  const result = await chain.mineBlock([swapTx]);
  const event = result.receipts[0].events[0];
  const feeAmount = 30; // 10000 * 30 / 10000
  const amountOut = 9970;

  assertEquals(event.type, "print_event");
  assertEquals(event.data.value.event, "swap");
  assertEquals(event.data.value.sender, deployer.address);
  assertEquals(event.data.value["token-in"], tokenIn);
  assertEquals(event.data.value["token-out"], tokenOut);
  assertEquals(event.data.value["amount-in"], 10000);
  assertEquals(event.data.value["amount-out"], amountOut);
  assertEquals(event.data.value["fee-amount"], feeAmount);
});
