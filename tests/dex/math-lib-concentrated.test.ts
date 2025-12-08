import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl, ClarityType } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;

// Focused tests for math-lib-concentrated tick/price math.
describe('math-lib-concentrated tick/price math', () => {
  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml', false, {
      trackCosts: false,
      trackCoverage: false,
    });
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), 'Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  const Q96 = 79228162514264337593543950336n;

  it('maps tick 0 to Q96 and back to tick 0', () => {
    const sqrtRes = simnet.callReadOnlyFn(
      'math-lib-concentrated',
      'tick-to-sqrt-price',
      [Cl.int(0)],
      deployer,
    );

    expect(sqrtRes.result).toBeOk(Cl.uint(Q96));

    const tickRes = simnet.callReadOnlyFn(
      'math-lib-concentrated',
      'sqrt-price-to-tick',
      [Cl.uint(Q96)],
      deployer,
    );

    expect(tickRes.result).toBeOk(Cl.int(0));
  });

  it('produces higher sqrt price for positive tick and lower for negative tick', () => {
    const zeroRes = simnet.callReadOnlyFn(
      'math-lib-concentrated',
      'tick-to-sqrt-price',
      [Cl.int(0)],
      deployer,
    );
    const posRes = simnet.callReadOnlyFn(
      'math-lib-concentrated',
      'tick-to-sqrt-price',
      [Cl.int(100)],
      deployer,
    );
    const negRes = simnet.callReadOnlyFn(
      'math-lib-concentrated',
      'tick-to-sqrt-price',
      [Cl.int(-100)],
      deployer,
    );

    expect(zeroRes.result.type).toBe(ClarityType.ResponseOk);
    expect(posRes.result.type).toBe(ClarityType.ResponseOk);
    expect(negRes.result.type).toBe(ClarityType.ResponseOk);

    const zeroVal = (zeroRes.result as any).value.value as bigint;
    const posVal = (posRes.result as any).value.value as bigint;
    const negVal = (negRes.result as any).value.value as bigint;

    expect(posVal).toBeGreaterThan(zeroVal);
    expect(negVal).toBeLessThan(zeroVal);
  });
});
