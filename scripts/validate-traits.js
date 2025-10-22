const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// 1. Run the trait scanner
console.log('🔍 Scanning for trait usage...');
require('./trait-scanner');

// 2. Load the generated registry
const registryPath = path.join(__dirname, '../contracts/traits/trait-registry.ts');
if (!fs.existsSync(registryPath)) {
  console.error('❌ Trait registry not found. Run the trait scanner first.');
  process.exit(1);
}

// 3. Check for unimplemented but used traits
const { traitRegistry, traitCoverage } = require(registryPath);

let hasErrors = false;

// Check for used but undefined traits
Object.entries(traitRegistry).forEach(([trait, data]) => {
  if (!traitCoverage.definedTraits.includes(trait)) {
    console.error(`❌ Trait ${trait} is used but not defined in all-traits.clar`);
    data.usages.forEach(usage => {
      console.error(`   - ${usage.filePath}:${usage.line} (${usage.type})`);
    });
    hasErrors = true;
  }
});

// Check for unused traits
if (traitCoverage.unusedTraits > 0) {
  console.warn(`⚠️  Found ${traitCoverage.unusedTraits} unused traits`);
  traitCoverage.unusedTraitsList.forEach(trait => {
    console.warn(`   - ${trait}`);
  });
}

// 4. Run Clarinet check to validate trait implementations
console.log('\n🔧 Validating trait implementations with Clarinet...');
try {
  execSync('clarinet check', { stdio: 'inherit' });
  console.log('✅ All trait implementations are valid!');
} catch (error) {
  console.error('❌ Trait validation failed. Please fix the issues above.');
  hasErrors = true;
}

if (hasErrors) {
  console.error('\n🚨 Trait validation failed. Please fix the issues above before committing.');
  process.exit(1);
}

console.log('\n✨ All trait validations passed!');
process.exit(0);
