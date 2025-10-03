#!/usr/bin/env node
/**
 * Fix Trait Quote Syntax
 * 
 * This script fixes the incorrect single-quote syntax in trait imports
 * across all Clarity contracts in the Conxian protocol.
 * 
 * Pattern to fix:
 *   'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.trait-name
 *   → .all-traits.trait-name OR ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.trait-name
 * 
 * Usage: node scripts/fix-trait-quotes.js [--dry-run]
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const DRY_RUN = process.argv.includes('--dry-run');
const CONTRACTS_DIR = path.join(__dirname, '../contracts');

// Statistics
const stats = {
  filesScanned: 0,
  filesModified: 0,
  quotesFixed: 0,
  errors: []
};

/**
 * Recursively find all .clar files
 */
function findClarityFiles(dir) {
  const files = [];
  
  function traverse(currentPath) {
    const items = fs.readdirSync(currentPath, { withFileTypes: true });
    
    for (const item of items) {
      const fullPath = path.join(currentPath, item.name);
      
      if (item.isDirectory()) {
        traverse(fullPath);
      } else if (item.isFile() && item.name.endsWith('.clar')) {
        files.push(fullPath);
      }
    }
  }
  
  traverse(dir);
  return files;
}

/**
 * Fix trait quote syntax in a single file
 */
function fixTraitQuotes(filePath) {
  stats.filesScanned++;
  
  try {
    let content = fs.readFileSync(filePath, 'utf-8');
    const originalContent = content;
    let fixCount = 0;
    
    // Pattern 1: Single-quoted full path in use-trait
    // 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.trait-name
    const pattern1 = /'(ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6\.all-traits\.[a-zA-Z0-9\-]+)'/g;
    const newContent1 = content.replace(pattern1, (match, traitPath) => {
      fixCount++;
      // Convert to relative notation for cleaner code
      const traitName = traitPath.split('.').pop();
      return `.all-traits.${traitName}`;
    });
    content = newContent1;
    
    // Pattern 2: Single-quoted full path with closing paren
    // 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.trait-name)
    const pattern2 = /'(ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6\.all-traits\.[a-zA-Z0-9\-]+)\)/g;
    const newContent2 = content.replace(pattern2, (match, traitPath) => {
      fixCount++;
      const traitName = traitPath.split('.').pop();
      return `.all-traits.${traitName})`;
    });
    content = newContent2;
    
    // Pattern 3: use-trait with quote at end
    // (use-trait name 'path')
    const pattern3 = /\(use-trait\s+([a-zA-Z0-9\-]+)\s+'([^']+)'\)/g;
    const newContent3 = content.replace(pattern3, (match, name, traitPath) => {
      fixCount++;
      if (traitPath.includes('all-traits')) {
        const traitName = traitPath.split('.').pop();
        return `(use-trait ${name} .all-traits.${traitName})`;
      }
      return `(use-trait ${name} ${traitPath})`;
    });
    content = newContent3;
    
    // Pattern 4: impl-trait with full quoted path (should be relative)
    const pattern4 = /\(impl-trait\s+'(ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6\.all-traits\.[a-zA-Z0-9\-]+)\)/g;
    const newContent4 = content.replace(pattern4, (match, traitPath) => {
      fixCount++;
      const traitName = traitPath.split('.').pop();
      return `(impl-trait .${traitName})`;
    });
    content = newContent4;
    
    // If content changed, write it back
    if (content !== originalContent) {
      if (!DRY_RUN) {
        fs.writeFileSync(filePath, content, 'utf-8');
      }
      
      stats.filesModified++;
      stats.quotesFixed += fixCount;
      
      const relativePath = path.relative(CONTRACTS_DIR, filePath);
      console.log(`✅ Fixed ${fixCount} quote(s) in: ${relativePath}${DRY_RUN ? ' (DRY RUN)' : ''}`);
      
      return { fixed: true, count: fixCount };
    }
    
    return { fixed: false, count: 0 };
    
  } catch (error) {
    const relativePath = path.relative(CONTRACTS_DIR, filePath);
    console.error(`❌ Error processing ${relativePath}:`, error.message);
    stats.errors.push({ file: relativePath, error: error.message });
    return { fixed: false, count: 0, error: true };
  }
}

/**
 * Main execution
 */
function main() {
  console.log('🔍 Conxian Trait Quote Fixer');
  console.log('============================\n');
  
  if (DRY_RUN) {
    console.log('⚠️  DRY RUN MODE - No files will be modified\n');
  }
  
  console.log(`Scanning contracts in: ${CONTRACTS_DIR}\n`);
  
  // Find all Clarity files
  const clarityFiles = findClarityFiles(CONTRACTS_DIR);
  console.log(`Found ${clarityFiles.length} .clar files\n`);
  
  // Process each file
  for (const file of clarityFiles) {
    fixTraitQuotes(file);
  }
  
  // Print summary
  console.log('\n============================');
  console.log('📊 Summary');
  console.log('============================');
  console.log(`Files scanned: ${stats.filesScanned}`);
  console.log(`Files modified: ${stats.filesModified}`);
  console.log(`Total quotes fixed: ${stats.quotesFixed}`);
  console.log(`Errors: ${stats.errors.length}`);
  
  if (stats.errors.length > 0) {
    console.log('\n❌ Errors encountered:');
    stats.errors.forEach(({ file, error }) => {
      console.log(`  - ${file}: ${error}`);
    });
  }
  
  if (!DRY_RUN && stats.filesModified > 0) {
    console.log('\n✅ Files have been modified. Running validation...');
    
    try {
      console.log('\nRunning: clarinet check...');
      execSync('clarinet check', { 
        cwd: path.join(__dirname, '..'),
        stdio: 'inherit'
      });
      console.log('\n✅ Validation passed!');
    } catch (error) {
      console.log('\n⚠️  Validation failed. Review the output above.');
      console.log('You may need to run additional fixes.');
    }
  } else if (DRY_RUN) {
    console.log('\n💡 Run without --dry-run to apply changes');
  } else {
    console.log('\n✨ No changes needed - all files are already correct!');
  }
}

// Run the script
main();
