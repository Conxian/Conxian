import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

import { Clarinet, Chain, Account } from "@stacks/clarinet-sdk";

describe("Dimensional Core Integration Test", () => {
  let clarinet: Clarinet;
  let chain: Chain;
  let accounts: Map<string, Account>;
  let deployer: Account;
  let wallet_1: Account;

  beforeAll(async () => {
    clarinet = await Clarinet.fromStream(new Uint8Array());
    chain = clarinet.chain;
    accounts = clarinet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet_1 = accounts.get("wallet_1")!;
  });

  it("opens a position and records metrics", () => {
    const block = chain.mineBlock([
      Tx.contractCall(
        "dimensional-core",
        "set-oracle-contract",
        [Cl.contractPrincipal(deployer.address, "dimensional-oracle")],
        deployer.address
      ),
      Tx.contractCall(
        "dimensional-engine",
        "create-position",
        [
          Cl.uint(100000000), // collateral-amount
          Cl.uint(200), // leverage
          Cl.stringAscii("LONG"), // pos-type
          Cl.contractPrincipal(deployer.address, "mock-token"), // token
          Cl.uint(100), // slippage-tolerance
          Cl.stringAscii("DAILY"), // funding-int
        ],
        wallet_1.address
      ),
    ]);
    block.receipts[1].result.expectOk().expectUint(0);

    const metric = chain.callReadOnlyFn(
      "dim-metrics",
      "get-metric",
      [
        Cl.uint(1), // dim-id
        Cl.uint(0), // metric-id
      ],
      deployer.address
    );
    expect(metric.result).toStrictEqual(
      Cl.some(
        Cl.tuple({
          value: Cl.uint(100000000),
          "last-updated": Cl.uint(2),
        })
      )
    );
  });
});
