import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from '@stacks/clarinet-sdk';

/**
 * Finance Metrics Tests
 * Validates EBITDA, CAPEX, OPEX recording and aggregation.
 */
describe('Finance Metrics Contract', () => {
  let simnet: any;
  let accounts: Map<string, string>;
  let deployer: string;

  beforeAll(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('should set writer principal and record EBITDA for DEX module', async () => {
    const setWriter = simnet.callPublicFn(
      'finance-metrics',
      'set-writer-principal',
      [Cl.principal(deployer)],
      deployer
    );
    expect(setWriter.result).toBeOk();

    const amount = 100000000; // example amount
    const record = simnet.callPublicFn(
      'finance-metrics',
      'record-ebitda',
      [Cl.stringAscii('DEX'), Cl.uint(amount)],
      deployer
    );
    expect(record.result).toBeOk();

    const agg = simnet.callReadOnlyFn(
      'finance-metrics',
      'get-aggregate',
      [Cl.stringAscii('DEX'), Cl.stringAscii('EBITDA'), Cl.uint(0)],
      deployer
    );
    expect(agg.result).toBeOk(Cl.uint(amount));

    const summary = simnet.callReadOnlyFn(
      'finance-metrics',
      'get-system-finance-summary',
      [Cl.uint(0)],
      deployer
    );
    expect(summary.result).toBeOk();
    const tup = summary.result.expectOk().expectTuple();
    expect(Number(tup['ebitda'])).toBe(amount);
    expect(Number(tup['capex'])).toBe(0);
    expect(Number(tup['opex'])).toBe(0);
  });

  it('should record CAPEX and OPEX and reflect in system summary', async () => {
    const capexAmt = 50000000;
    const opexAmt = 20000000;

    const capex = simnet.callPublicFn(
      'finance-metrics',
      'record-capex',
      [Cl.stringAscii('CORE'), Cl.uint(capexAmt)],
      deployer
    );
    expect(capex.result).toBeOk();

    const opex = simnet.callPublicFn(
      'finance-metrics',
      'record-opex',
      [Cl.stringAscii('OPS'), Cl.uint(opexAmt)],
      deployer
    );
    expect(opex.result).toBeOk();

    const summary = simnet.callReadOnlyFn(
      'finance-metrics',
      'get-system-finance-summary',
      [Cl.uint(0)],
      deployer
    );
    expect(summary.result).toBeOk();
    const tup = summary.result.expectOk().expectTuple();
    // EBITDA from previous test remains 100000000
    expect(Number(tup['ebitda'])).toBeGreaterThanOrEqual(100000000);
    expect(Number(tup['capex'])).toBeGreaterThanOrEqual(capexAmt);
    expect(Number(tup['opex'])).toBeGreaterThanOrEqual(opexAmt);
  });
});