// Simple type definitions for test environment
interface ClarityAbi {
  functions: Array<{
    name: string;
    access: 'read_only' | 'public' | 'private';
    args: Array<{ name: string; type: string }>;
    outputs: { type: any };
  }>;
  variables: any[];
  maps: any[];
  fungible_tokens: any[];
  non_fungible_tokens: any[];
  clarity_version: string;
  contractName: string;
}

// Mock Clarity types for testing
const ClarityType = {
  ResponseOk: 'ok',
  ResponseErr: 'err',
  OptionalSome: 'some',
  OptionalNone: 'none',
  PrincipalStandard: 'standard',
  PrincipalContract: 'contract',
  BoolTrue: 'bool_true',
  BoolFalse: 'bool_false',
  Int: 'int',
  UInt: 'uint',
  StringASCII: 'string_ascii',
  StringUTF8: 'string_utf8',
  Tuple: 'tuple',
  List: 'list'
} as const;

export interface TokenContract {
  identifier: string;
  abi: ClarityAbi;
  contract_id: string;
  [key: string]: any;
}

export interface TestContracts {
  cxdToken: TokenContract;
  cxvgToken: TokenContract;
  cxlpToken: TokenContract;
  cxtrToken: TokenContract;
  cxsToken: TokenContract;
  [key: string]: TokenContract | any;
}

// Helper function to parse Clarity values
function parseClarityValue(value: ClarityValue): any {
  if (value.type === ClarityType.ResponseOk) {
    return { isOk: true, value: parseClarityValue(value.value) };
  }
  if (value.type === ClarityType.ResponseErr) {
    return { isErr: true, error: parseClarityValue(value.value) };
  }
  if (value.type === ClarityType.OptionalSome) {
    return parseClarityValue(value.value);
  }
  if (value.type === ClarityType.OptionalNone) {
    return null;
  }
  if (value.type === ClarityType.PrincipalStandard || value.type === ClarityType.PrincipalContract) {
    return value.address;
  }
  if (value.type === ClarityType.BoolTrue || value.type === ClarityType.BoolFalse) {
    return value.type === ClarityType.BoolTrue;
  }
  if (value.type === ClarityType.Int) {
    return BigInt(value.value);
  }
  if (value.type === ClarityType.UInt) {
    return BigInt(value.value.toString());
  }
  if (value.type === ClarityType.StringASCII || value.type === ClarityType.StringUTF8) {
    return value.data;
  }
  if (value.type === ClarityType.Tuple) {
    const result: Record<string, any> = {};
    for (const [key, val] of Object.entries(value.data)) {
      result[key] = parseClarityValue(val);
    }
    return result;
  }
  if (value.type === ClarityType.List) {
    return value.list.map(parseClarityValue);
  }
  return value;
}

// Create a contract instance with type-safe methods
export function createContract<T = any>(
  identifier: string,
  abi: ClarityAbi,
  address: string
): T {
  const contract: any = {
    identifier,
    abi,
    contract_id: `${address}.${identifier}`,
  };

  // Add contract methods
  for (const func of abi.functions) {
    contract[func.name] = async (args: any[] = [], options: any = {}) => {
      const { sender } = options;
      // In a real test environment, this would call the blockchain
      // For now, we'll just return a mock response
      return {
        isOk: true,
        value: null,
        events: [],
        ...options.mockResponse,
      };
    };
  }

  // Add read-only methods
  for (const readOnly of abi.functions.filter(f => f.access === 'read_only')) {
    contract[`get${readOnly.name.charAt(0).toUpperCase() + readOnly.name.slice(1)}`] = 
      async (...args: any[]) => {
        // Mock implementation for testing
        if (readOnly.name === 'getBalance') {
          return { value: 0n };
        }
        if (readOnly.name === 'getTotalSupply') {
          return { value: 0n };
        }
        if (readOnly.name === 'getOwner') {
          return { value: address };
        }
        return { value: null };
      };
  }

  return contract as T;
}

// Mock contract ABIs for testing
export const mockTokenAbi: ClarityAbi = {
  functions: [
    {
      name: 'mint',
      access: 'public',
      args: [
        { name: 'recipient', type: 'principal' },
        { name: 'amount', type: 'uint128' }
      ],
      outputs: { type: { response: { ok: 'bool', error: 'uint128' } } }
    },
    {
      name: 'get-balance',
      access: 'read_only',
      args: [{ name: 'owner', type: 'principal' }],
      outputs: { type: { response: { ok: 'uint128', error: 'none' } } }
    },
    {
      name: 'get-total-supply',
      access: 'read_only',
      args: [],
      outputs: { type: { response: { ok: 'uint128', error: 'none' } } }
    },
    {
      name: 'get-owner',
      access: 'read_only',
      args: [],
      outputs: { type: { response: { ok: 'principal', error: 'none' } } }
    },
    {
      name: 'get-symbol',
      access: 'read_only',
      args: [],
      outputs: { type: { response: { ok: { 'string-ascii': { length: 10 } }, error: 'none' } } }
    },
    {
      name: 'get-name',
      access: 'read_only',
      args: [],
      outputs: { type: { response: { ok: { 'string-ascii': { length: 32 } }, error: 'none' } } }
    },
    {
      name: 'get-decimals',
      access: 'read_only',
      args: [],
      outputs: { type: { response: { ok: 'uint128', error: 'none' } } }
    }
  ],
  variables: [],
  maps: [],
  fungible_tokens: [],
  non_fungible_tokens: [],
  clarity_version: 'Clarity1',
  contractName: '',
};

// Mock NFT ABI
export const mockNftAbi: ClarityAbi = {
  ...mockTokenAbi,
  functions: [
    ...mockTokenAbi.functions,
    {
      name: 'mint',
      access: 'public',
      args: [
        { name: 'recipient', type: 'principal' },
        { name: 'uri', type: { optional: { 'string-utf8': { length: 256 } } } }
      ],
      outputs: { type: { response: { ok: 'bool', error: 'uint128' } } }
    },
    {
      name: 'get-token-uri',
      access: 'read_only',
      args: [{ name: 'token-id', type: 'uint128' }],
      outputs: { type: { response: { ok: { optional: { 'string-utf8': { length: 256 } } }, error: 'none' } } }
    },
    {
      name: 'get-owner',
      access: 'read_only',
      args: [{ name: 'token-id', type: 'uint128' }],
      outputs: { type: { response: { ok: { optional: 'principal' }, error: 'none' } } }
    }
  ]
};

// Create mock test contracts
export function createMockTestContracts(address: string): TestContracts {
  return {
    cxdToken: createContract('cxd-token', mockTokenAbi, address),
    cxvgToken: createContract('cxvg-token', mockTokenAbi, address),
    cxlpToken: createContract('cxlp-token', mockTokenAbi, address),
    cxtrToken: createContract('cxtr-token', mockTokenAbi, address),
    cxsToken: createContract('cxs-token', mockNftAbi, address),
  };
}
