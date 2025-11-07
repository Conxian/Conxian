import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.5/index.ts';
import { assertEquals } from 'https://deno.land/std@0.125.0/testing/asserts.ts';

const CONTRACT_OWNER = 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ';
const TRAIT_REGISTRY = `${CONTRACT_OWNER}.trait-registry`;

// Standard trait contracts
const STANDARD_TRAITS = [
  {
    name: 'sip-010-trait',
    contract: `${CONTRACT_OWNER}.sip-010-trait`,
    version: 1,
    description: 'Standard SIP-010 Fungible Token Trait',
    deprecated: false,
    replacedBy: null
  },
  {
    name: 'sip-010-ft-trait',
    contract: `${CONTRACT_OWNER}.sip-010-ft-trait`,
    version: 1,
    description: 'Extended SIP-010 FT Trait with additional functionality',
    deprecated: false,
    replacedBy: null
  },
  {
    name: 'access-control-trait',
    contract: `${CONTRACT_OWNER}.access-control-trait`,
    version: 1,
    description: 'Standard Access Control Trait',
    deprecated: false,
    replacedBy: null
  },
  {
    name: 'pool-trait',
    contract: `${CONTRACT_OWNER}.pool-trait`,
    version: 1,
    description: 'DEX Pool Trait for AMM functionality',
    deprecated: false,
    replacedBy: null
  },
  {
    name: 'oracle-trait',
    contract: `${CONTRACT_OWNER}.oracle-trait`,
    version: 1,
    description: 'Oracle Trait for price feeds',
    deprecated: false,
    replacedBy: null
  }
];

async function registerTrait(
  chain: Chain,
  deployer: Account,
  trait: typeof STANDARD_TRAITS[0]
) {
  const tx = chain.mineBlock([
    Tx.contractCall(
      TRAIT_REGISTRY,
      'register-trait',
      [
        types.ascii(trait.name),
        types.uint(trait.version),
        types.utf8(trait.description),
        types.principal(trait.contract),
        types.bool(trait.deprecated),
        trait.replacedBy ? types.some(types.ascii(trait.replacedBy)) : types.none()
      ],
      deployer.address
    )
  ]);

  if (tx.receipts[0].result.includes('err')) {
    console.error(`Failed to register ${trait.name}:`, tx.receipts[0].result);
    return false;
  }
  return true;
}

export async function initializeTraitRegistry(chain: Chain, deployer: Account) {
  console.log('Initializing Trait Registry...');
  
  // Register each standard trait
  for (const trait of STANDARD_TRAITS) {
    const success = await registerTrait(chain, deployer, trait);
    if (success) {
      console.log(`✅ Registered trait: ${trait.name}`);
    } else {
      console.error(`❌ Failed to register trait: ${trait.name}`);
    }
  }
  
  // Verify all traits were registered
  const call = await chain.callReadOnlyFn(
    TRAIT_REGISTRY,
    'list-traits',
    [],
    deployer.address
  );
  
  const registeredTraits = call.result.expectList();
  console.log(`\nSuccessfully registered ${registeredTraits.length} traits`);
  console.log('Trait registry initialization complete!');
}

// Example usage in a test file:
/*
Clarinet.test({
  name: 'Initialize trait registry',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    await initializeTraitRegistry(chain, deployer);
  },
});
*/
