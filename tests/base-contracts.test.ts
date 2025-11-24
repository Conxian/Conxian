import { describe, it, expect } from 'vitest';
import { Cl, cvToValue } from '@stacks/transactions';
import { Simnet } from '@stacks/clarinet-sdk';

const simnet = new Simnet();
const accounts = simnet.getAccounts();

const OWNABLE_CONTRACT = 'ownable';
const PAUSABLE_CONTRACT = 'pausable';
const ROLES_CONTRACT = 'roles';
const ERR_NOT_OWNER = 101;

describe('Base Contracts', () => {
  it('has correct initial owner', async () => {
    const result = await simnet.callReadOnlyFn(OWNABLE_CONTRACT, 'get-owner', [], accounts.get('deployer'));
    expect(result.result).toEqual(Cl.ok(Cl.principal(accounts.get('deployer'))));
  });

  it('transfers ownership correctly', async () => {
    const wallet1 = accounts.get('wallet_1');
    const deployer = accounts.get('deployer');

    // Transfer ownership to wallet1
    let block = await simnet.mineBlock([
      simnet.callPublicFn(OWNABLE_CONTRACT, 'transfer-ownership', [Cl.principal(wallet1)], deployer),
    ]);
    expect(block.receipts[0].result).toEqual(Cl.ok(Cl.bool(true)));

    // Claim ownership
    block = await simnet.mineBlock([
      simnet.callPublicFn(OWNABLE_CONTRACT, 'claim-ownership', [], wallet1),
    ]);
    expect(block.receipts[0].result).toEqual(Cl.ok(Cl.bool(true)));
    
    // Verify new owner
    const result = await simnet.callReadOnlyFn(OWNABLE_CONTRACT, 'get-owner', [], wallet1);
    expect(result.result).toEqual(Cl.ok(Cl.principal(wallet1)));
  });

  it('prevents unauthorized ownership transfer', async () => {
    const wallet1 = accounts.get('wallet_1');
    const wallet2 = accounts.get('wallet_2');

    // wallet1 tries to transfer ownership (not the owner)
    const block = await simnet.mineBlock([
      simnet.callPublicFn(OWNABLE_CONTRACT, 'transfer-ownership', [Cl.principal(wallet2)], wallet1),
    ]);
    expect(block.receipts[0].result).toEqual(Cl.err(Cl.uint(ERR_NOT_OWNER)));
  });

  it('pauses and unpauses correctly', async () => {
    const deployer = accounts.get('deployer');

    // Pause the contract
    let block = await simnet.mineBlock([
      simnet.callPublicFn(PAUSABLE_CONTRACT, 'pause', [], deployer),
    ]);
    expect(block.receipts[0].result).toEqual(Cl.ok(Cl.bool(true)));
    
    // Check if paused
    let result = await simnet.callReadOnlyFn(PAUSABLE_CONTRACT, 'is-paused', [], deployer);
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
    
    // Unpause
    block = await simnet.mineBlock([
      simnet.callPublicFn(PAUSABLE_CONTRACT, 'unpause', [], deployer),
    ]);
    expect(block.receipts[0].result).toEqual(Cl.ok(Cl.bool(true)));
    
    // Verify unpaused
    result = await simnet.callReadOnlyFn(PAUSABLE_CONTRACT, 'is-paused', [], deployer);
    expect(result.result).toEqual(Cl.ok(Cl.bool(false)));
  });

  it('manages roles correctly', async () => {
    const wallet1 = accounts.get('wallet_1');
    const deployer = accounts.get('deployer');
    const ROLE_ADMIN = 1;

    // Grant admin role to wallet1
    let block = await simnet.mineBlock([
      simnet.callPublicFn(ROLES_CONTRACT, 'grant-role', [Cl.principal(wallet1), Cl.uint(ROLE_ADMIN)], deployer),
    ]);
    expect(block.receipts[0].result).toEqual(Cl.ok(Cl.bool(true)));
    
    // Check role
    let result = await simnet.callReadOnlyFn(ROLES_CONTRACT, 'has-role', [Cl.principal(wallet1), Cl.uint(ROLE_ADMIN)], deployer);
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
    
    // Revoke role
    block = await simnet.mineBlock([
      simnet.callPublicFn(ROLES_CONTRACT, 'revoke-role', [Cl.principal(wallet1), Cl.uint(ROLE_ADMIN)], deployer),
    ]);
    expect(block.receipts[0].result).toEqual(Cl.ok(Cl.bool(true)));
    
    // Verify role revoked
    result = await simnet.callReadOnlyFn(ROLES_CONTRACT, 'has-role', [Cl.principal(wallet1), Cl.uint(ROLE_ADMIN)], deployer);
    expect(result.result).toEqual(Cl.ok(Cl.bool(false)));
  });
});
