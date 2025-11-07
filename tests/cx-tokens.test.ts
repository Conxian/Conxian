import { Cl, ClarityType, ClarityValue, cvToValue, hexToCV, principalCV } from '@stacks/transactions';
import { describe, expect, it, beforeEach, beforeAll } from 'vitest';
import { getTestContracts } from './utils/token-helpers';

// Mock test data
const mockChain = {
  deployer: 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ'
};

const mockAccounts = new Map([
  ['wallet_1', { address: 'ST3NBRSFKX28FQ2ZJ1MAKX58HKHSHNG2KP3DZ2MXT' }],
  ['wallet_2', { address: 'ST3J2GVMMM2R07ZFBJDWTYEYAR8FZH5WKDTFJ9AHA' }]
]);

// Simple mock setup
function setup() {
  return {
    chain: mockChain,
    accounts: mockAccounts,
    contracts: getTestContracts(mockChain.deployer)
  };
}

// Helper functions
function getDeployer(chain: any, accounts: any) {
  return { address: chain.deployer };
}

async function getContractName(contract: any) {
  try {
    const result = await contract.getName();
    return result.value;
  } catch (e) {
    return 'Unknown';
  }
}

async function getContractOwner(contract: any) {
  try {
    const result = await contract.getOwner();
    return result.value;
  } catch (e) {
    return null;
  }
}

describe('CX* Token Contracts', () => {
  const { chain, accounts } = setup();
  const deployer = getDeployer(chain, accounts);
  const alice = accounts.get('wallet_1')!;
  const bob = accounts.get('wallet_2')!;

  // Get contract instances
  const cxdToken = getTestContracts(chain).cxdToken;
  const cxvgToken = getTestContracts(chain).cxvgToken;
  const cxlpToken = getTestContracts(chain).cxlpToken;
  const cxtrToken = getTestContracts(chain).cxtrToken;
  const cxsToken = getTestContracts(chain).cxsToken;

  // Helper function to get token balance
  async function getBalance(contract: any, owner: string) {
    const result = await contract.getBalance(owner);
    return result.value;
  }

  describe('CXD Token', () => {
    it('has correct initial state', async () => {
      const name = await cxdToken.getName();
      const symbol = await cxdToken.getSymbol();
      const decimals = await cxdToken.getDecimals();
      const totalSupply = await cxdToken.getTotalSupply();
      const owner = await cxdToken.getOwner();

      expect(name).toBe('Conxian Revenue Token');
      expect(symbol).toBe('CXD');
      expect(decimals).toBe(6n);
      expect(totalSupply).toBe(0n);
      expect(owner).toBe(deployer.address);
    });

    it('allows owner to mint tokens', async () => {
      const amount = 1000000n; // 1 token with 6 decimals
      
      // Mint tokens to Alice
      const receipt = await cxdToken.mint(alice.address, amount, { sender: deployer });
      expect(receipt.isOk).toBe(true);
      
      // Check Alice's balance
      const balance = await getBalance(cxdToken, alice.address);
      expect(balance).toBe(amount);
      
      // Check total supply
      const totalSupply = await cxdToken.getTotalSupply();
      expect(totalSupply).toBe(amount);
    });

    it('prevents non-owners from minting', async () => {
      const amount = 1000000n;
      
      // Alice tries to mint tokens (should fail)
      const receipt = await cxdToken.mint(alice.address, amount, { sender: alice });
      expect(receipt.isErr).toBe(true);
    });
  });

  describe('CXLP Token', () => {
    it('has correct initial state', async () => {
      const name = await cxlpToken.getName();
      const symbol = await cxlpToken.getSymbol();
      const decimals = await cxlpToken.getDecimals();
      const totalSupply = await cxlpToken.getTotalSupply();
      const owner = await cxlpToken.getOwner();

      expect(name).toBe('Conxian LP Token');
      expect(symbol).toBe('CXLP');
      expect(decimals).toBe(6n);
      expect(totalSupply).toBe(0n);
      expect(owner).toBe(deployer.address);
    });

    it('supports migration to CXD', async () => {
      // First, mint some CXLP tokens to Alice
      const amount = 1000000n;
      await cxlpToken.mint(alice.address, amount, { sender: deployer });
      
      // Set up migration parameters (simplified for test)
      await cxlpToken.setMigrationStart(1, { sender: deployer });
      
      // Alice migrates her CXLP to CXD
      const receipt = await cxlpToken.migrateToCxd(amount, alice.address, cxdToken.identifier, { sender: alice });
      expect(receipt.isOk).toBe(true);
      
      // Check that Alice's CXLP balance is now 0
      const cxlpBalance = await getBalance(cxlpToken, alice.address);
      expect(cxlpBalance).toBe(0n);
      
      // Check that Alice received CXD tokens (simplified check)
      const cxdBalance = await getBalance(cxdToken, alice.address);
      expect(cxdBalance).toBeGreaterThan(0n);
    });
  });

  describe('CXTR Token', () => {
    it('has correct initial state', async () => {
      const name = await cxtrToken.getName();
      const symbol = await cxtrToken.getSymbol();
      const decimals = await cxtrToken.getDecimals();
      const totalSupply = await cxtrToken.getTotalSupply();
      const owner = await cxtrToken.getOwner();

      expect(name).toBe('Conxian Contributor Token');
      expect(symbol).toBe('CXTR');
      expect(decimals).toBe(6n);
      expect(totalSupply).toBe(0n);
      expect(owner).toBe(deployer.address);
    });

    it('supports creator reputation system', async () => {
      // Set up creator council
      await cxtrToken.setCreatorCouncil(alice.address, { sender: deployer });
      
      // Update creator reputation
      const receipt = await cxtrToken.updateCreatorReputation(
        bob.address, 
        1000n, // reputation
        5n,    // bounties
        2n,    // successful proposals
        { sender: alice }
      );
      
      expect(receipt.isOk).toBe(true);
      
      // Check creator contributions
      const contributions = await cxtrToken.getCreatorContributions(bob.address);
      expect(contributions.value.reputation).toBe(1000n);
      expect(contributions.value.successfulProposals).toBe(2n);
    });
  });

  describe('CXS Token (NFT)', () => {
    it('has correct initial state', async () => {
      const name = await cxsToken.getName();
      const symbol = await cxsToken.getSymbol();
      const owner = await cxsToken.getOwner();

      expect(name).toBe('Conxian Staking NFT');
      expect(symbol).toBe('CXS');
      expect(owner).toBe(deployer.address);
    });

    it('allows minting NFTs', async () => {
      const tokenId = 1n;
      const uri = 'https://example.com/nft/1';
      
      // Mint NFT to Alice
      const receipt = await cxsToken.mint(alice.address, uri, { sender: deployer });
      expect(receipt.isOk).toBe(true);
      
      // Check owner of the NFT
      const owner = await cxsToken.getOwner(tokenId);
      expect(owner).toBe(alice.address);
      
      // Check token URI
      const tokenUri = await cxsToken.getTokenUri(tokenId);
      expect(tokenUri).toBe(uri);
    });
  });

  describe('CXVG Token', () => {
    it('has correct initial state', async () => {
      const name = await cxvgToken.getName();
      const symbol = await cxvgToken.getSymbol();
      const decimals = await cxvgToken.getDecimals();
      const totalSupply = await cxvgToken.getTotalSupply();
      const owner = await cxvgToken.getOwner();

      expect(name).toBe('Conxian Governance Token');
      expect(symbol).toBe('CXVG');
      expect(decimals).toBe(6n);
      expect(totalSupply).toBe(0n);
      expect(owner).toBe(deployer.address);
    });

    it('supports delegation', async () => {
      // Mint some tokens to Alice
      await cxvgToken.mint(alice.address, 1000000n, { sender: deployer });
      
      // Alice delegates to Bob
      const delegateReceipt = await cxvgToken.delegate(bob.address, { sender: alice });
      expect(delegateReceipt.isOk).toBe(true);
      
      // Check delegation
      const delegate = await cxvgToken.getDelegate(alice.address);
      expect(delegate).toBe(bob.address);
      
      // Check voting power
      const votingPower = await cxvgToken.getVotes(alice.address);
      expect(votingPower).toBe(1000000n);
    });
  });
});
