const fs = require('fs');
const path = require('path');

// List of trait files and their corresponding trait names
const traitFiles = [
  'access-control-trait.clar',
  'bond-trait.clar',
  'circuit-breaker-trait.clar',
  'dao-trait.clar',
  'dim-registry-trait.clar',
  'dimensional-oracle-trait.clar',
  'factory-trait.clar',
  'flash-loan-receiver-trait.clar',
  'ft-mintable-trait.clar',
  'lending-system-trait.clar',
  'liquidation-trait.clar',
  'monitor-trait.clar',
  'oracle-trait.clar',
  'ownable-trait.clar',
  'pausable-trait.clar',
  'pool-trait.clar',
  'reentrancy-guard-trait.clar',
  'router-trait.clar',
  'sip-010-ft-trait.clar',
  'staking-trait.clar',
  'strategy-trait.clar',
  'vault-admin-trait.clar',
  'vault-trait.clar'
];

// Function to update trait files
function updateTraitFiles() {
  const traitsDir = path.join(__dirname, '..', 'contracts', 'traits');
  
  traitFiles.forEach(traitFile => {
    const traitName = traitFile.replace('.clar', '');
    const filePath = path.join(traitsDir, traitFile);
    
    // Skip if file doesn't exist or is the all-traits.clar file
    if (!fs.existsSync(filePath) || traitFile === 'all-traits.clar') {
      return;
    }
    
    // Read the file content
    let content = fs.readFileSync(filePath, 'utf8');
    
    // Add deprecation notice if not already present
    const deprecationNotice = `;; This file is deprecated. Please use all-traits.clar instead.\n;; The ${traitName} is now defined in all-traits.clar\n\n`;
    
    if (!content.includes('This file is deprecated')) {
      content = `;; ${traitFile}\n` + deprecationNotice + content;
      fs.writeFileSync(filePath, content, 'utf8');
      console.log(`Updated ${traitFile} with deprecation notice`);
    } else {
      console.log(`${traitFile} already has deprecation notice`);
    }
  });
  
  console.log('\nTrait files update complete!');
  console.log('Please ensure all contracts use the traits from all-traits.clar');
  console.log('Example usage:');
  console.log('(use-trait my-trait \'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.my-trait)');
  console.log('(impl-trait \'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.my-trait)');
}

// Run the update
updateTraitFiles();
