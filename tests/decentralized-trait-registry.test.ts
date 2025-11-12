import { Clarinet, Tx, Chain, Account, types } from '@stacks/clarinet';
import { describe, it, expect } from 'vitest';

const CONTRACT_OWNER = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
const GOVERNANCE_CONTRACT = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'; // For simplicity, initially same as owner

describe('decentralized-trait-registry', () => {
  let chain: Chain;
  let deployer: Account;
  let alice: Account;
  let bob: Account;
  let registry: Account;

  beforeAll(() => {
    chain = Clarinet.V1.getChain(CONTRACT_OWNER);
    deployer = chain.getAccount(CONTRACT_OWNER);
    alice = chain.getAccount('ST1SJ3DTE5DN7X5M4XQR8ZYSMR6K7V5ZPG34S2GE7');
    bob = chain.getAccount('ST2CY5KCE7B6X2HB5F0F2V3RK2T0M09RM10DQS4J4');
    registry = chain.getAccount('ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'); // The contract itself
  });

  it('should register a trait interface', () => {
    let block = chain.mineBlock([
      Tx.contractCall(
        'decentralized-trait-registry',
        'register-trait-interface',
        [types.ascii('sip-010-trait'), types.ascii('SIP-010 Fungible Token Standard')],
        deployer.address
      ),
    ]);
    expect(block.receipts[0].result).toBeOk(types.bool(true));

    let call = chain.callReadOnlyFn(
      'decentralized-trait-registry',
      'get-trait-interfaces',
      [],
      deployer.address
    );
    expect(call.result).toBeOk(types.list([
      types.tuple({
        name: types.ascii('sip-010-trait'),
        description: types.ascii('SIP-010 Fungible Token Standard'),
      }),
    ]));
  });

  it('should not register an existing trait interface', () => {
    let block = chain.mineBlock([
      Tx.contractCall(
        'decentralized-trait-registry',
        'register-trait-interface',
        [types.ascii('sip-010-trait'), types.ascii('SIP-010 Fungible Token Standard')],
        deployer.address
      ),
    ]);
    expect(block.receipts[0].result).toBeErr(types.uint(102)); // ERR_TRAIT_ALREADY_REGISTERED
  });

  it('should register a trait implementation', () => {
    let block = chain.mineBlock([
      Tx.contractCall(
        'decentralized-trait-registry',
        'register-trait-implementation',
        [
          types.ascii('sip-010-trait'),
          types.principal('ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-v1'),
          types.uint(1),
        ],
        deployer.address
      ),
    ]);
    expect(block.receipts[0].result).toBeOk(types.bool(true));

    let call = chain.callReadOnlyFn(
      'decentralized-trait-registry',
      'get-trait-implementations',
      [types.ascii('sip-010-trait')],
      deployer.address
    );
    expect(call.result).toBeOk(types.list([
      types.tuple({
        'implementation-principal': types.principal('ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-v1'),
        'trait-name': types.ascii('sip-010-trait'),
        status: types.ascii('pending'),
        version: types.uint(1),
      }),
    ]));
  });

  it('should activate a trait implementation', () => {
    let block = chain.mineBlock([
      Tx.contractCall(
        'decentralized-trait-registry',
        'activate-trait-implementation',
        [
          types.ascii('sip-010-trait'),
          types.principal('ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-v1'),
        ],
        deployer.address // Should be governance contract
      ),
    ]);
    expect(block.receipts[0].result).toBeErr(types.uint(106)); // ERR_NOT_GOVERNANCE_CONTRACT

    // Set governance contract to deployer for testing purposes
    block = chain.mineBlock([
      Tx.contractCall(
        'decentralized-trait-registry',
        'set-governance-contract',
        [types.principal(deployer.address)],
        deployer.address
      ),
    ]);
    expect(block.receipts[0].result).toBeOk(types.bool(true));

    block = chain.mineBlock([
      Tx.contractCall(
        'decentralized-trait-registry',
        'activate-trait-implementation',
        [
          types.ascii('sip-010-trait'),
          types.principal('ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-v1'),
        ],
        deployer.address
      ),
    ]);
    expect(block.receipts[0].result).toBeOk(types.bool(true));

    let call = chain.callReadOnlyFn(
      'decentralized-trait-registry',
      'get-active-trait-implementation',
      [types.ascii('sip-010-trait')],
      deployer.address
    );
    expect(call.result).toBeOk(types.some(types.principal('ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-v1')));
  });

  it('should propose and finalize a trait upgrade', () => {
    // Register a new implementation
    let block = chain.mineBlock([
      Tx.contractCall(
        'decentralized-trait-registry',
        'register-trait-implementation',
        [
          types.ascii('sip-010-trait'),
          types.principal('ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-v2'),
          types.uint(2),
        ],
        deployer.address
      ),
    ]);
    expect(block.receipts[0].result).toBeOk(types.bool(true));

    // Propose upgrade
    block = chain.mineBlock([
      Tx.contractCall(
        'decentralized-trait-registry',
        'propose-trait-upgrade',
        [
          types.uint(1001),
          types.ascii('sip-010-trait'),
          types.principal('ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-v2'),
          types.uint(2),
        ],
        deployer.address // Should be governance contract
      ),
    ]);
    expect(block.receipts[0].result).toBeOk(types.bool(true));

    // Finalize upgrade
    block = chain.mineBlock([
      Tx.contractCall(
        'decentralized-trait-registry',
        'finalize-trait-upgrade',
        [types.uint(1001)],
        deployer.address // Should be governance contract
      ),
    ]);
    expect(block.receipts[0].result).toBeOk(types.bool(true));

    let call = chain.callReadOnlyFn(
      'decentralized-trait-registry',
      'get-active-trait-implementation',
      [types.ascii('sip-010-trait')],
      deployer.address
    );
    expect(call.result).toBeOk(types.some(types.principal('ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-v2')));
  });

  it('should transfer ownership', () => {
    let block = chain.mineBlock([
      Tx.contractCall(
        'decentralized-trait-registry',
        'transfer-ownership',
        [types.principal(alice.address)],
        deployer.address
      ),
    ]);
    expect(block.receipts[0].result).toBeOk(types.bool(true));

    // Try to register a trait with old owner, should fail
    block = chain.mineBlock([
      Tx.contractCall(
        'decentralized-trait-registry',
        'register-trait-interface',
        [types.ascii('new-trait'), types.ascii('A brand new trait')],
        deployer.address
      ),
    ]);
    expect(block.receipts[0].result).toBeErr(types.uint(100)); // ERR_UNAUTHORIZED

    // Register with new owner, should succeed
    block = chain.mineBlock([
      Tx.contractCall(
        'decentralized-trait-registry',
        'register-trait-interface',
        [types.ascii('new-trait'), types.ascii('A brand new trait')],
        alice.address
      ),
    ]);
    expect(block.receipts[0].result).toBeOk(types.bool(true));
  });
});
