import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

const CONTRACT_OWNER = 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ';
const AUDITOR = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
const CONTRACT_ADDRESS = 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.audit-registry';
const NFT_CONTRACT = 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.audit-badge-nft';
const AUDIT_HASH = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b8c7d6e5f4a3b2c1d0e9f8a7b6';
const REPORT_URI = 'https://example.com/audit-reports/1';

// Mock DAO trait implementation for testing
class MockDaoTrait {
  static hasVotingPower(address: string) {
    return Tx.contractCall('mock-dao', 'has-voting-power', [types.principal(address)], CONTRACT_OWNER);
  }
  
  static getVotingPower(address: string) {
    return Tx.contractCall('mock-dao', 'get-voting-power', [types.principal(address)], CONTRACT_OWNER);
  }
}

// Helper functions
function submitAudit(chain: Chain, caller: Account, contractAddress: string, auditHash: string, reportUri: string) {
  return chain.mineBlock([
    Tx.contractCall(
      'audit-registry',
      'submit-audit',
      [
        types.principal(contractAddress),
        types.ascii(auditHash),
        types.utf8(reportUri)
      ],
      caller.address
    )
  ]);
}

function voteOnAudit(chain: Chain, caller: Account, auditId: number, approve: boolean) {
  return chain.mineBlock([
    Tx.contractCall(
      'audit-registry',
      'vote',
      [
        types.uint(auditId),
        types.bool(approve)
      ],
      caller.address
    )
  ]);
}

function finalizeAudit(chain: Chain, caller: Account, auditId: number) {
  return chain.mineBlock([
    Tx.contractCall(
      'audit-registry',
      'finalize-audit',
      [types.uint(auditId)],
      caller.address
    )
  ]);
}

Clarinet.test({
  name: 'Audit Registry - Submit and approve audit',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const auditor = accounts.get('wallet_1')!;
    const voter1 = accounts.get('wallet_2')!;
    const voter2 = accounts.get('wallet_3')!;
    
    // Setup mock DAO to allow voting
    chain.mineBlock([
      Tx.contractCall(
        'mock-dao',
        'set-voting-power',
        [types.principal(auditor.address), types.uint(100)],
        deployer.address
      ),
      Tx.contractCall(
        'mock-dao',
        'set-voting-power',
        [types.principal(voter1.address), types.uint(50)],
        deployer.address
      ),
      Tx.contractCall(
        'mock-dao',
        'set-voting-power',
        [types.principal(voter2.address), types.uint(30)],
        deployer.address
      )
    ]);
    
    // Submit audit
    const contractAddress = 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.some-contract';
    const block = submitAudit(chain, auditor, contractAddress, AUDIT_HASH, REPORT_URI);
    block.receipts[0].result.expectOk().expectUint(1);
    
    // Vote on audit
    const vote1 = voteOnAudit(chain, voter1, 1, true);
    vote1.receipts[0].result.expectOk().expectBool(true);
    
    const vote2 = voteOnAudit(chain, voter2, 1, true);
    vote2.receipts[0].result.expectOk().expectBool(true);
    
    // Fast forward blocks to pass voting period
    chain.mineEmptyBlock(10081);
    
    // Finalize audit
    const finalize = finalizeAudit(chain, auditor, 1);
    finalize.receipts[0].result.expectOk().expectBool(true);
    
    // Check if NFT was minted
    const nftOwner = chain.callReadOnlyFn(
      'audit-badge-nft',
      'get-owner',
      [types.uint(1)],
      auditor.address
    );
    nftOwner.result.expectSome().expectPrincipal(auditor.address);
    
    // Verify audit status
    const auditStatus = chain.callReadOnlyFn(
      'audit-registry',
      'get-audit-status',
      [types.uint(1)],
      auditor.address
    );
    
    const status = auditStatus.result.expectOk().expectTuple();
    status['status'].expectAscii('approved');
  }
});

// Add more test cases as needed
