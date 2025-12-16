import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl, ClarityType } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Funding Calculator', () => {
  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 =
      accounts.get("wallet_1") ?? "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5";
  });

  describe('admin parameter configuration', () => {
    it('allows owner to set funding parameters within bounds', () => {
      const res = simnet.callPublicFn('funding-calculator', 'set-funding-parameters', [
        Cl.uint(144),   // 1-day interval
        Cl.uint(100),   // 1% max rate
        Cl.uint(500),   // 5% sensitivity
      ], deployer);

      expect(res.result).toBeOk(Cl.bool(true));
    });

    it('rejects invalid interval', () => {
      const res = simnet.callPublicFn('funding-calculator', 'set-funding-parameters', [
        Cl.uint(0),   // invalid
        Cl.uint(100),
        Cl.uint(500),
      ], deployer);

      // (err u5009) for invalid interval
      expect(res.result).toBeErr(Cl.uint(5009));
    });
  });

  describe('read-only views', () => {
    it("returns error when no funding history exists", () => {
      // This test is skipped because of a bug in the Clarinet SDK that causes a
      // "TypeError: Cannot read properties of undefined (reading 'length')"
      // error when calling a read-only function that takes a contract principal
      // as an argument.
      const asset = `${deployer}.cxd-token`;
      const res = simnet.callReadOnlyFn(
        "funding-calculator",
        "get-current-funding-rate",
        [Cl.contractPrincipal(asset.split(".")[0], asset.split(".")[1])],
        wallet1
      );

      // When no history is present, contract returns (err u5008)
      expect(res.result).toBeErr(Cl.uint(5008));
    });
  });
});
