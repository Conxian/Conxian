import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

// Constants
const CONTRACT_OWNER = 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ';
const AUDIT_REGISTRY = `${CONTRACT_OWNER}.audit-registry`;
const NFT_CONTRACT = `${CONTRACT_OWNER}.audit-badge-nft`;
const ALICE = 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC';
const BOB = 'ST2NEB84ASENDXKYGJPQW86YXQCEFEX6ARQSD2NVT';

// Helper functions
function mintBadge(chain: Chain, caller: Account, auditId: number, metadata: string, recipient: string) {
  return chain.mineBlock([
    Tx.contractCall(
      NFT_CONTRACT,
      'mint',
      [
        types.uint(auditId),
        types.utf8(metadata),
        types.principal(recipient)
      ],
      caller.address
    )
  ]);
}

function transferBadge(chain: Chain, sender: Account, tokenId: number, recipient: string, memo: string | null = null) {
  const memoParam = memo ? types.some(types.buffFromString(memo)) : types.none();
  return chain.mineBlock([
    Tx.contractCall(
      NFT_CONTRACT,
      'transfer',
      [
        types.uint(tokenId),
        types.principal(sender.address),
        types.principal(recipient),
        memoParam
      ],
      sender.address
    )
  ]);
}

function setBaseTokenUri(chain: Chain, caller: Account, uri: string) {
  return chain.mineBlock([
    Tx.contractCall(
      NFT_CONTRACT,
      'set-base-token-uri',
      [types.utf8(uri)],
      caller.address
    )
  ]);
}

function updateMetadata(chain: Chain, caller: Account, tokenId: number, metadata: string) {
  return chain.mineBlock([
    Tx.contractCall(
      NFT_CONTRACT,
      'update-metadata',
      [
        types.uint(tokenId),
        types.utf8(metadata)
      ],
      caller.address
    )
  ]);
}

Clarinet.test({
  name: 'Audit Badge NFT - Minting',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const alice = accounts.get('wallet_1')!;
    
    // Test: Only audit registry can mint
    let block = mintBadge(chain, alice, 1, 'metadata1', alice.address);
    block.receipts[0].result.expectErr().expectUint(1001); // ERR_UNAUTHORIZED
    
    // Test: Mint from audit registry
    block = mintBadge(chain, deployer, 1, 'metadata1', alice.address);
    block.receipts[0].result.expectOk().expectUint(1);
    
    // Test: Get token URI
    let tokenUri = chain.callReadOnlyFn(
      NFT_CONTRACT,
      'get-token-uri',
      [types.uint(1)],
      alice.address
    );
    tokenUri.result.expectSome().expectUtf8('metadata1');
    
    // Test: Cannot mint duplicate audit ID
    block = mintBadge(chain, deployer, 1, 'metadata2', alice.address);
    block.receipts[0].result.expectErr().expectUint(1005); // ERR_ALREADY_EXISTS
    
    // Test: Invalid audit ID (too large)
    block = mintBadge(chain, deployer, 70000, 'metadata3', alice.address);
    block.receipts[0].result.expectErr().expectUint(1003); // ERR_INVALID_PARAMETERS
    
    // Test: Invalid metadata (too long)
    const longMetadata = 'x'.repeat(300); // Exceeds MAX_METADATA_LENGTH
    block = mintBadge(chain, deployer, 2, longMetadata, alice.address);
    block.receipts[0].result.expectErr().expectUint(1003); // ERR_INVALID_PARAMETERS
  }
});

Clarinet.test({
  name: 'Audit Badge NFT - Transfer',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const alice = accounts.get('wallet_1')!;
    const bob = accounts.get('wallet_2')!;
    
    // Mint a badge to Alice
    let block = mintBadge(chain, deployer, 1, 'metadata1', alice.address);
    const tokenId = 1;
    
    // Test: Transfer from non-owner
    block = transferBadge(chain, bob, tokenId, bob.address);
    block.receipts[0].result.expectErr().expectUint(1001); // ERR_UNAUTHORIZED
    
    // Test: Transfer to self (invalid)
    block = transferBadge(chain, alice, tokenId, alice.address);
    block.receipts[0].result.expectErr().expectUint(1003); // ERR_INVALID_PARAMETERS
    
    // Test: Valid transfer
    block = transferBadge(chain, alice, tokenId, bob.address);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Test: Verify new owner
    const owner = chain.callReadOnlyFn(
      NFT_CONTRACT,
      'get-owner',
      [types.uint(tokenId)],
      alice.address
    );
    owner.result.expectSome().expectPrincipal(bob.address);
    
    // Test: Transfer with memo (valid)
    block = transferBadge(chain, bob, tokenId, alice.address, 'memo');
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Test: Transfer with memo too long
    const longMemo = 'x'.repeat(35); // Exceeds MAX_MEMO_LENGTH
    block = transferBadge(chain, alice, tokenId, bob.address, longMemo);
    block.receipts[0].result.expectErr().expectUint(1003); // ERR_INVALID_PARAMETERS
  }
});

Clarinet.test({
  name: 'Audit Badge NFT - Admin Functions',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const alice = accounts.get('wallet_1')!;
    
    // Mint a badge
    let block = mintBadge(chain, deployer, 1, 'metadata1', alice.address);
    const tokenId = 1;
    
    // Test: Set base token URI (non-owner)
    block = setBaseTokenUri(chain, alice, 'https://example.com/');
    block.receipts[0].result.expectErr().expectUint(1001); // ERR_UNAUTHORIZED
    
    // Test: Set base token URI (owner)
    block = setBaseTokenUri(chain, deployer, 'https://example.com/');
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Test: Update metadata (non-owner)
    block = updateMetadata(chain, alice, tokenId, 'new-metadata');
    block.receipts[0].result.expectErr().expectUint(1001); // ERR_UNAUTHORIZED
    
    // Test: Update metadata (owner)
    block = updateMetadata(chain, deployer, tokenId, 'new-metadata');
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Verify metadata update
    const tokenUri = chain.callReadOnlyFn(
      NFT_CONTRACT,
      'get-token-uri-raw',
      [types.uint(tokenId)],
      alice.address
    );
    tokenUri.result.expectSome().expectUtf8('new-metadata');
    
    // Test: Update non-existent token
    block = updateMetadata(chain, deployer, 999, 'new-metadata');
    block.receipts[0].result.expectErr().expectUint(1004); // ERR_NOT_FOUND
  }
});

Clarinet.test({
  name: 'Audit Badge NFT - Lookup Functions',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const alice = accounts.get('wallet_1')!;
    
    // Mint a badge
    let block = mintBadge(chain, deployer, 1, 'metadata1', alice.address);
    const tokenId = 1;
    const auditId = 1;
    
    // Test: Get token by audit ID
    let result = chain.callReadOnlyFn(
      NFT_CONTRACT,
      'get-token-by-audit',
      [types.uint(auditId)],
      alice.address
    );
    result.result.expectSome().expectUint(tokenId);
    
    // Test: Get audit by token ID
    result = chain.callReadOnlyFn(
      NFT_CONTRACT,
      'get-audit-by-token',
      [types.uint(tokenId)],
      alice.address
    );
    result.result.expectSome().expectUint(auditId);
    
    // Test: Non-existent lookups
    result = chain.callReadOnlyFn(
      NFT_CONTRACT,
      'get-token-by-audit',
      [types.uint(999)],
      alice.address
    );
    result.result.expectNone();
    
    result = chain.callReadOnlyFn(
      NFT_CONTRACT,
      'get-audit-by-token',
      [types.uint(999)],
      alice.address
    );
    result.result.expectNone();
  }
});
