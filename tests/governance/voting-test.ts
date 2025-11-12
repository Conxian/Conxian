import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0-rc.2/index.ts';
import { assertEquals } from 'https://deno.land/std@0.125.0/testing/asserts.ts';

const deployer = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
const alice = 'ST2JX41FDR0Z7X3SDWKRRBB02TKWK4TEDJN1VT6DX';
const bob = 'ST2NEB84ASENDXKYGJPQW86YXQCEFEX6ARQ6S5G3K';

const governanceToken = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.governance-token';

Clarinet.test({
  name: "Governance Voting - Proposal Creation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployerAccount = accounts.get(deployer)!;
    
    // Setup: Give Alice voting tokens
    chain.mineBlock([
      Tx.contractCall(
        governanceToken,
        "mint",
        [types.principal(alice), types.uint(10_000_000_000)],
        deployer
      )
    ]);
    
    // Create proposal
    const block = chain.mineBlock([
      Tx.contractCall(
        "governance-voting",
        "propose",
        [
          types.utf8("Test Proposal"),
          types.utf8("This is a test proposal")
        ],
        alice
      )
    ]);
    
    // Verify
    block.receipts[0].result.expectOk().expectUint(0);
    
    const proposal = chain.callReadOnlyFn(
      "governance-voting",
      "get-proposal",
      [types.uint(0)],
      deployer
    );
    
    proposal.result.expectTuple()["proposer"].expectPrincipal(alice);
  }
});

Clarinet.test({
  name: "Governance Voting - Voting",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployerAccount = accounts.get(deployer)!;
    
    // Setup: Give Alice voting tokens
    chain.mineBlock([
      Tx.contractCall(
        governanceToken,
        "mint",
        [types.principal(alice), types.uint(10_000_000_000)],
        deployer
      )
    ]);
    
    // Create proposal
    chain.mineBlock([
      Tx.contractCall(
        "governance-voting",
        "propose",
        [
          types.utf8("Test Proposal"),
          types.utf8("This is a test proposal")
        ],
        alice
      )
    ]);
    
    // Move chain to voting period
    chain.mineEmptyBlock(150);
    
    // Vote
    const block = chain.mineBlock([
      Tx.contractCall(
        "governance-voting",
        "cast-vote",
        [types.uint(0), types.uint(1)], // Vote FOR
        alice
      )
    ]);
    
    // Verify
    block.receipts[0].result.expectOk().expectBool(true);
    
    const vote = chain.callReadOnlyFn(
      "governance-voting",
      "get-vote",
      [types.uint(0), types.principal(alice)],
      deployer
    );
    
    vote.result.expectTuple()["weight"].expectUint(10_000_000_000);
  }
});
