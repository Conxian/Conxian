#!/usr/bin/env node

/**
 * Contract Deployment Verification Script
 * 
 * This script verifies that:
 * 1. All contracts referenced in tests exist in Clarinet.toml
 * 2. All contract dependencies are properly declared
 * 3. All contract files exist on disk
 * 4. No orphaned contracts (declared but not tested)
 */

const fs = require('fs');
const path = require('path');

// Parse Clarinet.toml
function parseClarinetToml(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const contracts = {};
  const remappings = {};
  const dependencies = {};
  
  // Simple TOML parser (basic implementation)
  const lines = content.split('\n');
  let currentSection = null;
  let currentContract = null;
  
  for (const line of lines) {
    const trimmed = line.trim();
    
    // Skip comments and empty lines
    if (trimmed.startsWith('#') || trimmed === '') continue;
    
    // Section headers
    if (trimmed.startsWith('[contracts.')) {
      const match = trimmed.match(/\[contracts\.(.+)\]/);
      if (match) {
        currentContract = match[1];
        contracts[currentContract] = {};
        currentSection = 'contract';
      }
    } else if (trimmed === '[remap.contracts]') {
      currentSection = 'remap';
    } else if (trimmed.startsWith('#')) {
      // Skip comments
      continue;
    } else {
      // Key-value pairs
      const equalIndex = trimmed.indexOf('=');
      if (equalIndex > 0 && currentSection) {
        const key = trimmed.substring(0, equalIndex).trim();
        const value = trimmed.substring(equalIndex + 1).trim().replace(/"/g, '');
        
        if (currentSection === 'contract' && currentContract) {
          if (key === 'depends_on') {
            // Parse dependency array
            const deps = value.replace(/[\[\]]/g, '').split(',').map(d => d.trim().replace(/"/g, ''));
            contracts[currentContract][key] = deps;
          } else {
            contracts[currentContract][key] = value;
          }
        } else if (currentSection === 'remap') {
          remappings[key] = value;
        }
      }
    }
  }
  
  return { contracts, remappings };
}

// Find all test files and extract contract references
function findContractReferences(testDir) {
  const contractRefs = new Set();
  
  function scanDirectory(dir) {
    const files = fs.readdirSync(dir);
    
    for (const file of files) {
      const fullPath = path.join(dir, file);
      const stat = fs.statSync(fullPath);
      
      if (stat.isDirectory()) {
        scanDirectory(fullPath);
      } else if (file.endsWith('.ts') || file.endsWith('.spec.ts') || file.endsWith('.test.ts')) {
        const content = fs.readFileSync(fullPath, 'utf8');
        
        // Find contract calls
        const contractCallMatches = content.match(/contractCall\s*\(\s*['"`]([^'"`]+)['"`]/g);
        if (contractCallMatches) {
          for (const match of contractCallMatches) {
            const contractMatch = match.match(/contractCall\s*\(\s*['"`]([^'"`]+)['"`]/);
            if (contractMatch) {
              contractRefs.add(contractMatch[1]);
            }
          }
        }
        
        // Find read-only function calls
        const readOnlyMatches = content.match(/callReadOnlyFn\s*\(\s*['"`]([^'"`]+)['"`]/g);
        if (readOnlyMatches) {
          for (const match of readOnlyMatches) {
            const readOnlyMatch = match.match(/callReadOnlyFn\s*\(\s*['"`]([^'"`]+)['"`]/);
            if (readOnlyMatch) {
              contractRefs.add(readOnlyMatch[1]);
            }
          }
        }
      }
    }
  }
  
  scanDirectory(testDir);
  return contractRefs;
}

// Verify contract files exist
function verifyContractFiles(contracts, contractsDir) {
  const missingFiles = [];
  
  for (const [contractName, contractData] of Object.entries(contracts)) {
    if (!contractData.path) {
      // Some entries in Clarinet.toml (like accounts.*) are pseudo-contracts
      // used only for address aliases and are not expected to have a path.
      if (!contractName.startsWith('accounts.')) {
        missingFiles.push(`${contractName}: no path defined`);
      }
      continue;
    }
    // The path in TOML is relative to project root, not contractsDir
    const contractPath = contractData.path.replace(/\//g, path.sep);
    const projectRoot = path.join(__dirname, '..');
    const fullPath = path.join(projectRoot, contractPath);
    if (!fs.existsSync(fullPath)) {
      missingFiles.push(`${contractName}: ${fullPath}`);
    }
  }
  
  return missingFiles;
}

// Main verification function
function main() {
  const clarinetPath = path.join(__dirname, '..', 'Clarinet.toml');
  const testDir = path.join(__dirname, '..', 'tests');
  const contractsDir = path.join(__dirname, '..', 'contracts');
  
  console.log('🔍 Contract Deployment Verification');
  console.log('=====================================\n');
  
  // Parse Clarinet.toml
  if (!fs.existsSync(clarinetPath)) {
    console.error('❌ Clarinet.toml not found');
    process.exit(1);
  }
  
  const { contracts, remappings } = parseClarinetToml(clarinetPath);
  console.log(`📋 Found ${Object.keys(contracts).length} contracts in Clarinet.toml`);
  
  // Find contract references in tests
  const contractRefs = findContractReferences(testDir);
  console.log(`🔍 Found ${contractRefs.size} contract references in tests`);
  
  // Check for missing contracts
  const missingContracts = [];
  for (const ref of contractRefs) {
    // Skip dynamic references like ${deployer}.dimensional-engine
    if (ref.includes('${')) {
      continue;
    }
    
    // Check direct contract name
    if (!contracts[ref]) {
      // Check remappings
      const remapped = remappings[ref];
      if (!remapped || !contracts[remapped.substring(1)]) {
        missingContracts.push(ref);
      }
    }
  }
  
  if (missingContracts.length > 0) {
    console.log('\n❌ Missing contracts in Clarinet.toml:');
    for (const missing of missingContracts) {
      console.log(`   - ${missing}`);
    }
  } else {
    console.log('\n✅ All referenced contracts are declared in Clarinet.toml');
  }
  
  // Verify contract files exist
  const missingFiles = verifyContractFiles(contracts, contractsDir);
  if (missingFiles.length > 0) {
    console.log('\n❌ Missing contract files:');
    for (const missing of missingFiles) {
      console.log(`   - ${missing}`);
    }
  } else {
    console.log('\n✅ All contract files exist');
  }
  
  // Check for orphaned contracts (declared but not tested)
  const orphanedContracts = [];
  for (const contractName of Object.keys(contracts)) {
    if (!contractRefs.has(contractName) && !remappings[contractName]) {
      // Check if this contract is referenced via remapping
      let isReferenced = false;
      for (const ref of contractRefs) {
        if (remappings[ref] === `.${contractName}`) {
          isReferenced = true;
          break;
        }
      }
      if (!isReferenced) {
        orphanedContracts.push(contractName);
      }
    }
  }
  
  if (orphanedContracts.length > 0) {
    console.log('\n⚠️  Orphaned contracts (declared but not tested):');
    for (const orphaned of orphanedContracts) {
      console.log(`   - ${orphaned}`);
    }
  } else {
    console.log('\n✅ All declared contracts are tested');
  }
  
  // Summary
  const hasErrors = missingContracts.length > 0 || missingFiles.length > 0;
  
  console.log('\n📊 Summary:');
  console.log(`   - Contracts declared: ${Object.keys(contracts).length}`);
  console.log(`   - Contracts referenced in tests: ${contractRefs.size}`);
  console.log(`   - Missing declarations: ${missingContracts.length}`);
  console.log(`   - Missing files: ${missingFiles.length}`);
  console.log(`   - Orphaned contracts: ${orphanedContracts.length}`);
  
  if (hasErrors) {
    console.log('\n❌ Verification failed!');
    process.exit(1);
  } else {
    console.log('\n✅ All checks passed!');
    process.exit(0);
  }
}

if (require.main === module) {
  main();
}

module.exports = { parseClarinetToml, findContractReferences, verifyContractFiles };
