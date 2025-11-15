import { Cl, ClarityType, ResponseOkCV, ResponseErrorCV, cvToValue } from '@stacks/transactions';
import { expect } from 'vitest';

// Helper to extract values from Clarity responses
export const extractValue = (result: { result: ResponseOkCV<ClarityValue> | ResponseErrorCV<ClarityValue> }) => {
  if (result.result.type !== ClarityType.ResponseOk) {
    throw new Error('Expected successful response');
  }
  return cvToValue(result.result.value);
};

// Helper to create a position
export const createPosition = async (
  simnet: any,
  user: string,
  {
    collateral = 1000,
    leverage = 2000,
    isLong = true,
    stopLoss = undefined,
    takeProfit = undefined,
  } = {}
) => {
  // Approve tokens
  await simnet.callPublicFn(
    'token',
    'approve',
    [Cl.principal('dimensional-engine'), Cl.uint(collateral), Cl.none()],
    user
  );

  // Open position
  const result = await simnet.callPublicFn(
    'dimensional-engine',
    'open-position',
    [
      Cl.principal('token'),
      Cl.uint(collateral),
      Cl.uint(leverage),
      Cl.bool(isLong),
      stopLoss ? Cl.some(Cl.uint(stopLoss)) : Cl.none(),
      takeProfit ? Cl.some(Cl.uint(takeProfit)) : Cl.none(),
    ],
    user
  );

  return extractValue(result);
};

// Helper to check position state
export const getPosition = async (simnet: any, positionId: number, user: string) => {
  const result = await simnet.callReadOnlyFn(
    'dimensional-engine',
    'get-position',
    [Cl.uint(positionId)],
    user
  );
  return extractValue(result);
};

// Helper to check token balance
export const getBalance = async (simnet: any, token: string, user: string) => {
  const result = await simnet.callReadOnlyFn(
    token,
    'get-balance',
    [Cl.principal(user)],
    user
  );
  return extractValue(result);
};

// Helper to set oracle price
export const setOraclePrice = async (simnet: any, price: number) => {
  await simnet.callPublicFn(
    'oracle',
    'set-price',
    [Cl.uint(price)],
    'deployer'
  );
};

// Custom matchers for common assertions
expect.extend({
  toBeOk(result: { result: ResponseOkCV<ClarityValue> | ResponseErrorCV<ClarityValue> }) {
    const pass = result.result.type === ClarityType.ResponseOk;
    return {
      pass,
      message: () => `Expected operation to ${pass ? 'fail' : 'succeed'}`,
    };
  },
  toHaveErrorCode(result: { result: ResponseOkCV<ClarityValue> | ResponseErrorCV<ClarityValue> }, expectedCode: number) {
    if (result.result.type !== ClarityType.ResponseErr) {
      return {
        pass: false,
        message: () => 'Expected operation to fail with an error',
      };
    }
    
    const actualCode = Number(cvToValue(result.result.value));
    return {
      pass: actualCode === expectedCode,
      message: () => `Expected error code ${expectedCode}, got ${actualCode}`,
    };
  },
});

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace jest {
    interface Matchers<R> {
      toBeOk(): R;
      toHaveErrorCode(code: number): R;
    }
  }
}
