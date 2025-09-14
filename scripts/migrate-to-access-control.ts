import { Cl, ClarityType } from '@stacks/transactions';
import { simnet } from '../.stacks/Clarigen';
import { readFileSync, writeFileSync } from 'fs';
import { join } from 'path';

// Contract files that need to be updated
const CONTRACTS_TO_UPDATE = [
  'comprehensive-lending-system.clar',
  'oracle.clar',
  'vault.clar',
  'yield-distribution-engine.clar'
];

// Path to contracts directory
const CONTRACTS_DIR = join(__dirname, '..', 'contracts');

// Mapping of old permission checks to new role-based checks
const PERMISSION_MAPPING = [
  {
    pattern: /is-eq\s+tx-sender\s+contract-owner/g,
    replacement: '(unwrap! (contract-call? .access-control has-role tx-sender \'ADMIN) false)'
  },
  {
    pattern: /only-owner/g,
    replacement: 'only-role \'ADMIN'
  },
  {
    pattern: /contract-owner/g,
    replacement: '(unwrap! (contract-call? .access-control get-role-admin \'ADMIN))'
  }
];

// Function to update a contract file
function updateContractFile(filename: string) {
  const filePath = join(CONTRACTS_DIR, filename);
  let content = readFileSync(filePath, 'utf8');
  
  // Add access control trait if not present
  if (!content.includes('use-trait access-control')) {
    content = `(use-trait access-control .access-control-trait.access-control-trait)
${content}`;
  }
  
  // Update permission checks
  for (const { pattern, replacement } of PERMISSION_MAPPING) {
    content = content.replace(pattern, replacement);
  }
  
  // Save the updated file
  writeFileSync(filePath, content, 'utf8');
  console.log(`✅ Updated ${filename}`);
}

// Main migration function
async function migrateToAccessControl() {
  console.log('🚀 Starting migration to AccessControl...');
  
  // Update each contract
  for (const contract of CONTRACTS_TO_UPDATE) {
    try {
      updateContractFile(contract);
    } catch (error) {
      console.error(`❌ Error updating ${contract}:`, error);
    }
  }
  
  console.log('\n✨ Migration complete!');
  console.log('Please review the changes and test thoroughly before deploying.');
  console.log('Run tests with: npm test');
}

// Run the migration
migrateToAccessControl().catch(console.error);
