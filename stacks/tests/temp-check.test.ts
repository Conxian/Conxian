import { Cl } from "@stacks/transactions";
import { describe, expect, it } from "vitest";

const CONTRACT_NAME = "error-utils";
const DEFAULT_SENDER = "ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE";

describe("error-utils contract", () => {
  it("should be a valid contract", () => {
    const { result } = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      "get-last-error",
      [],
      DEFAULT_SENDER
    );
    expect(result).toBeOk(Cl.uint(0));
  });
});
