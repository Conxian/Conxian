import { Cl, ClarityType, ResponseOkCV, ResponseErrorCV, cvToValue } from '@stacks/transactions';
import { expect } from 'vitest';
import { Simnet, Tx } from "@stacks/clarinet-sdk";

// Standard test accounts
export const TEST_ACCOUNTS = {
  deployer: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
  wallet_1: "ST3J2GVMMM2R07ZFBJDWTYEYAR8FZH5WKDTFJ9AHA",
  wallet_2: "ST3J2GVMMM2R07ZFBJDWTYEYAR8FZH5WKDTFJ9AHB",
  wallet_3: "ST3J2GVMMM2R07ZFBJDWTYEYAR8FZH5WKDTFJ9AHC",
} as const;

// Standard contract names
export const CONTRACTS = {
  // Base contracts
  ownable: "ownable",
  pausable: "pausable",
  roles: "roles",

  // Token contracts
  cxd_token: "cxd-token",
  cxvg_token: "cxvg-token",
  cxlp_token: "cxlp-token",
  cxtr_token: "cxtr-token",
  cxs_token: "cxs-token",

  // DEX contracts
  dex_factory: "dex-factory",
  dex_router: "dex-router",
  concentrated_liquidity_pool: "concentrated-liquidity-pool",

  // Oracle contracts
  twap_oracle: "twap-oracle",
  oracle_adapter: "oracle-adapter",

  // Governance
  governance_token: "governance-token",
} as const;

// Common error codes
export const ERROR_CODES = {
  ERR_NOT_OWNER: 1001,
  ERR_PAUSED: 1003,
  ERR_INVALID_INPUT: 1004,
  ERR_UNAUTHORIZED: 1100,
  ERR_NOT_ENOUGH_BALANCE: 2003,
  ERR_OVERFLOW: 2000,
  ERR_SUB_UNDERFLOW: 2001,
} as const;

// Helper to extract values from Clarity responses
export const extractValue = (result: {
  result: ResponseOkCV<ClarityValue> | ResponseErrorCV<ClarityValue>;
}) => {
  if (result.result.type !== ClarityType.ResponseOk) {
    throw new Error("Expected successful response");
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
    "token",
    "approve",
    [Cl.principal("dimensional-engine"), Cl.uint(collateral), Cl.none()],
    user
  );

  // Open position
  const result = await simnet.callPublicFn(
    "dimensional-engine",
    "open-position",
    [
      Cl.principal("token"),
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
export const getPosition = async (
  simnet: any,
  positionId: number,
  user: string
) => {
  const result = await simnet.callReadOnlyFn(
    "dimensional-engine",
    "get-position",
    [Cl.uint(positionId)],
    user
  );
  return extractValue(result);
};

// Helper to check token balance
export const getBalance = async (simnet: any, token: string, user: string) => {
  const result = await simnet.callReadOnlyFn(
    token,
    "get-balance",
    [Cl.principal(user)],
    user
  );
  return extractValue(result);
};

// Helper to set oracle price
export const setOraclePrice = async (simnet: any, price: number) => {
  await simnet.callPublicFn(
    "oracle",
    "set-price",
    [Cl.uint(price)],
    "deployer"
  );
};

// Custom matchers for common assertions
expect.extend({
  toBeOk(result: {
    result: ResponseOkCV<ClarityValue> | ResponseErrorCV<ClarityValue>;
  }) {
    const pass = result.result.type === ClarityType.ResponseOk;
    return {
      pass,
      message: () => `Expected operation to ${pass ? "fail" : "succeed"}`,
    };
  },
  toHaveErrorCode(
    result: {
      result: ResponseOkCV<ClarityValue> | ResponseErrorCV<ClarityValue>;
    },
    expectedCode: number
  ) {
    if (result.result.type !== ClarityType.ResponseErr) {
      return {
        pass: false,
        message: () => "Expected operation to fail with an error",
      };
    }

    const actualCode = Number(cvToValue(result.result.value));
    return {
      pass: actualCode === expectedCode,
      message: () => `Expected error code ${expectedCode}, got ${actualCode}`,
    };
  },
});

// Helper functions for standardized setup
export function setupSimnet(): Simnet {
  // Initialize Simnet with the Clarinet.toml manifest
  const simnet = new Simnet("Clarinet.toml");
  return simnet;
}

export function getErrorName(code: number): string {
  const errorMap: { [key: number]: string } = {
    [ERROR_CODES.ERR_NOT_OWNER]: "ERR_NOT_OWNER",
    [ERROR_CODES.ERR_PAUSED]: "ERR_PAUSED",
    [ERROR_CODES.ERR_INVALID_INPUT]: "ERR_INVALID_INPUT",
    [ERROR_CODES.ERR_UNAUTHORIZED]: "ERR_UNAUTHORIZED",
    [ERROR_CODES.ERR_NOT_ENOUGH_BALANCE]: "ERR_NOT_ENOUGH_BALANCE",
    [ERROR_CODES.ERR_OVERFLOW]: "ERR_OVERFLOW",
    [ERROR_CODES.ERR_SUB_UNDERFLOW]: "ERR_SUB_UNDERFLOW",
  };
  return errorMap[code] || `UNKNOWN_ERROR_${code}`;
}

// Re-export commonly used types
export { Simnet, Tx };

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace jest {
    interface Matchers<R> {
      toBeOk(): R;
      toHaveErrorCode(code: number): R;
    }
  }
}
