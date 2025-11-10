import { Cl, ClarityValue, ResponseOkCV, ResponseErrorCV, cvToValue, ClarityType } from '@stacks/transactions';
import { expect } from 'vitest';

// Error codes from errors.clar
export const ERR_NOT_AUTHORIZED = 1000;
export const ERR_INVALID_INPUT = 1001;
export const ERR_INSUFFICIENT_BALANCE = 2001;
export const ERR_POSITION_NOT_FOUND = 3001;
export const ERR_POSITION_NOT_ACTIVE = 3002;
export const ERR_INVALID_LEVERAGE = 3003;

// Role constants
export const ROLE_ADMIN = 1;
export const ROLE_OPERATOR = 2;
export const ROLE_LIQUIDATOR = 3;

// Test accounts
export const deployer = 'ST1PQHQKV0RJXZ9VZC53AGRTZ9KXQWDXVSCD9QCSQ';
export const user1 = 'ST2NEB84ASENDXKYGJPQW86YXQCEFEX6ARQ95FFSV';
export const user2 = 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC';

// Helper functions
export function expectOk(result: any) {
  const response = result.result as ResponseOkCV<ClarityValue> | ResponseErrorCV<ClarityValue>;
  expect(response.type).toBe(ClarityType.ResponseOk);
}

export function expectErr(result: any) {
  const response = result.result as ResponseOkCV<ClarityValue> | ResponseErrorCV<ClarityValue>;
  expect(response.type).toBe(ClarityType.ResponseErr);
}

export function expectOkWithResult(
  result: any,
  expected: any
) {
  expectOk(result);
  const value = cvToValue((result.result as ResponseOkCV<ClarityValue>).value);
  expect(value).toEqual(expected);
}

export function expectErrWithCode(
  result: any,
  code: number
) {
  expectErr(result);
  const error = (result.result as ResponseErrorCV<ClarityValue>).value;
  expect(Number(cvToValue(error))).toBe(code);
}

export function expectEvent(
  events: any[],
  eventName: string,
  expectedData: Record<string, any>
) {
  const event = events.find(e => 
    e.event === eventName && 
    e.contract_identifier.endsWith('dimensional-engine')
  );
  
  expect(event).toBeDefined();
  
  for (const [key, value] of Object.entries(expectedData)) {
    expect(event.data[key]).toEqual(value);
  }
}

// Setup helper
export async function setupRoles(simnet: any) {
  // Grant admin role to deployer
  await simnet.callPublicFn(
    `${deployer}.dimensional-engine`,
    'grant-role',
    [Cl.uint(ROLE_ADMIN), Cl.principal(deployer)],
    deployer
  );
  
  // Grant operator role to deployer
  await simnet.callPublicFn(
    `${deployer}.dimensional-engine`,
    'grant-role',
    [Cl.uint(ROLE_OPERATOR), Cl.principal(deployer)],
    deployer
  );
  
  // Grant liquidator role to user1
  await simnet.callPublicFn(
    `${deployer}.dimensional-engine`,
    'grant-role',
    [Cl.uint(ROLE_LIQUIDATOR), Cl.principal(user1)],
    deployer
  );
}

// Token helper
export async function mintTokens(simnet: any, recipient: string, amount: number) {
  // Mint tokens to recipient
  await simnet.callPublicFn(
    `${deployer}.token`,
    'mint',
    [Cl.uint(amount), Cl.principal(recipient)],
    deployer
  );
  
  // Approve engine to spend tokens
  await simnet.callPublicFn(
    `${deployer}.token`,
    'approve',
    [Cl.principal(`${deployer}.dimensional-engine`), Cl.uint(amount), Cl.none()],
    recipient
  );
}

// Balance helper
export async function getBalance(simnet: any, address: string) {
  const result = await simnet.callReadOnlyFn(
    `${deployer}.dimensional-engine`,
    'get-balance',
    [Cl.principal(address)],
    address
  );
  
  if (result.result.type !== ClarityType.ResponseOk) {
    return 0;
  }

  const okResponse = result.result as ResponseOkCV<ClarityValue>;
  return Number(cvToValue(okResponse.value));
}

// Position helper
export async function openPosition(
  simnet: any, 
  user: string, 
  asset: string, 
  collateral: number, 
  leverage: number, 
  isLong: boolean
) {
  // Approve tokens first
  await simnet.callPublicFn(
    asset,
    'approve',
    [Cl.principal(`${deployer}.dimensional-engine`), Cl.uint(collateral), Cl.none()],
    user
  );
  
  // Open position
  const result = await simnet.callPublicFn(
    `${deployer}.dimensional-engine`,
    'open-position',
    [
      Cl.principal(asset),
      Cl.uint(collateral),
      Cl.uint(leverage),
      Cl.bool(isLong),
      Cl.none(),
      Cl.none()
    ],
    user
  );
  
  if (result.result.type !== ClarityType.ResponseOk) {
    throw new Error(`Failed to open position: ${JSON.stringify(result)}`);
  }

  const okResponse = result.result as ResponseOkCV<ClarityValue>;
  return Number(cvToValue(okResponse.value));
}
