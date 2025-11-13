import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet_1 = accounts.get("wallet_1")!;

describe("Dimensional Core Integration Test", () =\u003e {
  it("opens a position and records metrics", () =\u003e {
    simnet.callPublicFn(
      "dimensional-core",
      "set-oracle-contract",
      [Cl.contractPrincipal(deployer.address, "dimensional-oracle")],
      deployer.address
    );

    const { result } = simnet.callPublicFn(
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
    );
    expect(result).toBeOk(Cl.uint(0));

    const metric = simnet.callReadOnlyFn(
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
