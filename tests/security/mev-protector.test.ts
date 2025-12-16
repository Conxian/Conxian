import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { Cl, ClarityType } from "@stacks/transactions";
import { createHash } from "node:crypto";
import { initSimnet, type Simnet } from "@stacks/clarinet-sdk";

let deployer: string;
let wallet1: string;
let simnet: Simnet;

describe("MEV Protector", () => {
  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml");
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), "Clarinet.toml");
    const accounts = simnet.getAccounts();
    deployer = (accounts.get("deployer") ??
      "STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ") as string;
    wallet1 = (accounts.get("wallet_1") ??
      "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5") as string;
  });

  it("enforces owner-only admin controls for commit/reveal periods and ownership", () => {
    const periodsBefore = simnet.callReadOnlyFn(
      "mev-protector",
      "get-periods",
      [],
      deployer
    );
    expect(periodsBefore.result).toEqual(Cl.ok(expect.anything()));

    const setCommit = simnet.callPublicFn(
      "mev-protector",
      "set-commit-period",
      [Cl.uint(5)],
      deployer
    );
    expect(setCommit.result).toEqual(Cl.ok(Cl.bool(true)));

    const setReveal = simnet.callPublicFn(
      "mev-protector",
      "set-reveal-period",
      [Cl.uint(7)],
      deployer
    );
    expect(setReveal.result).toEqual(Cl.ok(Cl.bool(true)));

    const transfer = simnet.callPublicFn(
      "mev-protector",
      "set-contract-owner",
      [Cl.standardPrincipal(wallet1)],
      deployer
    );
    expect(transfer.result).toEqual(Cl.ok(Cl.bool(true)));

    const failSet = simnet.callPublicFn(
      "mev-protector",
      "set-commit-period",
      [Cl.uint(8)],
      deployer
    );
    expect(failSet.result).toEqual(Cl.error(Cl.uint(4000)));

    const successSet = simnet.callPublicFn(
      "mev-protector",
      "set-commit-period",
      [Cl.uint(8)],
      wallet1
    );
    expect(successSet.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it("reports batch readiness and prevents premature execution", () => {
    const currentBatch = simnet.callReadOnlyFn(
      "mev-protector",
      "get-current-batch-id",
      [],
      deployer
    );
    expect(currentBatch.result).toEqual(Cl.ok(expect.anything()));

    const batchId = (currentBatch.result as any).value as any;

    const ready = simnet.callReadOnlyFn(
      "mev-protector",
      "is-batch-ready",
      [batchId],
      deployer
    );
    expect(ready.result).toEqual(Cl.ok(Cl.bool(false)));

    const nonOwnerExec = simnet.callPublicFn(
      "mev-protector",
      "execute-batch",
      [batchId, Cl.contractPrincipal(deployer, "mock-pool")],
      wallet1
    );
    expect(nonOwnerExec.result).toEqual(Cl.error(Cl.uint(4005)));

    const ownerExec = simnet.callPublicFn(
      "mev-protector",
      "execute-batch",
      [batchId, Cl.contractPrincipal(deployer, "mock-pool")],
      deployer
    );
    expect(ownerExec.result).toEqual(Cl.error(Cl.uint(4005)));
  });

  it("allows committing an order", () => {
    const hash = "0x" + "0".repeat(64);
    const result = simnet.callPublicFn(
      "mev-protector",
      "commit-order",
      [Cl.bufferFromHex(hash)],
      wallet1
    );
    expect(result.result).toEqual(Cl.ok(Cl.uint(0)));
  });

  it("prevents early reveal", () => {
    const hash = "0x" + "0".repeat(64); // Dummy hash
    simnet.callPublicFn(
      "mev-protector",
      "commit-order",
      [Cl.bufferFromHex(hash)],
      wallet1
    );

    // Try to reveal immediately
    const result = simnet.callPublicFn(
      "mev-protector",
      "reveal-commitment",
      [Cl.uint(0), Cl.bufferFromHex("0x" + "0".repeat(64))], // Dummy salt (32 bytes)
      wallet1
    );

    expect(result.result).toBeErr(Cl.uint(4002)); // ERR_REVEAL_PERIOD_ENDED (actually wait period hasn't ended)
  });

  it("completes full batch lifecycle", () => {
    const salt = Buffer.from("0102030405060708090a0b0c0d0e0f10", "hex"); // 16 bytes

    // Define order parameters
    const tokenIn = Cl.contractPrincipal(deployer, "cxd-token");
    const tokenOut = Cl.contractPrincipal(deployer, "cxs-token");
    const amountIn = Cl.uint(1000);
    const minOut = Cl.uint(900);

    // Hash salt only
    const hash = createHash("sha256").update(salt).digest();

    // 1. Commit
    const commitResult = simnet.callPublicFn(
      "mev-protector",
      "commit-order",
      [Cl.buffer(hash)],
      wallet1
    );
    expect(commitResult.result).toEqual(Cl.ok(Cl.uint(0))); // Commitment ID 0

    // 2. Advance to Reveal Period (10 blocks)
    simnet.mineEmptyBlocks(10);

    // 3. Reveal
    const revealResult = simnet.callPublicFn(
      "mev-protector",
      "reveal-order",
      [
        Cl.uint(0),
        tokenIn, // token-in-trait
        tokenOut, // token-out
        amountIn, // amount-in
        minOut, // min-out
        Cl.buffer(salt), // salt
      ],
      wallet1
    );
    expect(revealResult.result).toEqual(Cl.ok(Cl.uint(0))); // Batch ID 0

    // 4. Advance to End of Batch (another 10 blocks)
    // Batch 0 ends at block 20. Current is ~11.
    simnet.mineEmptyBlocks(10);

    // 5. Execute Batch
    const executeResult = simnet.callPublicFn(
      "mev-protector",
      "execute-order-in-batch",
      [
        Cl.uint(0), // batch-id
        Cl.uint(0), // order-index
        Cl.contractPrincipal(deployer, "mock-pool"),
        tokenIn,
        tokenOut,
        Cl.contractPrincipal(deployer, "oracle"),
      ],
      deployer // Owner
    );
    // Since mock-pool swaps 1:1, amount-out should be 1000.
    // Oracle price check should pass (1:1).
    expect(executeResult.result).toEqual(Cl.ok(Cl.uint(1000)));
  });
});
