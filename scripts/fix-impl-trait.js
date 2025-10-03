#!/usr/bin/env node
/**
 * Fix impl-trait Syntax
 * 
 * Fixes incorrect impl-trait references from:
 *   (impl-trait .all-traits.trait-name)
 * To:
 *   (impl-trait .trait-name)
 */

const fs = require('fs');
const path = require('path');

const DRY_RUN = process.argv.includes('--dry-run');
const CONTRACTS_DIR = path.join(__dirname, '../contracts');

const stats = {
  filesScanned: 0,
  filesModified: 0,
  implTraitsFixed: 0
};

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

function fixImplTrait(filePath) {
  stats.filesScanned++;
  
  try {
    let content = fs.readFileSync(filePath, 'utf-8');
    const originalContent = content;
    let fixCount = 0;
    
    // Pattern: (impl-trait .all-traits.trait-name) -> (impl-trait .trait-name)
    const pattern = /\(impl-trait\s+\.all-traits\.([a-zA-Z0-9\-]+)\)/g;
    
    content = content.replace(pattern, (match, traitName) => {
      fixCount++;
      return `(impl-trait .${traitName})`;
    });
    
    if (content !== originalContent) {
      if (!DRY_RUN) {
        fs.writeFileSync(filePath, content, 'utf-8');
      }
      
      stats.filesModified++;
      stats.implTraitsFixed += fixCount;
      
      const relativePath = path.relative(CONTRACTS_DIR, filePath);
      console.log(`✅ Fixed ${fixCount} impl-trait(s) in: ${relativePath}${DRY_RUN ? ' (DRY RUN)' : ''}`);
      
      return { fixed: true, count: fixCount };
    }
    
    return { fixed: false, count: 0 };
    
  } catch (error) {
    const relativePath = path.relative(CONTRACTS_DIR, filePath);
    console.error(`❌ Error processing ${relativePath}:`, error.message);
    return { fixed: false, count: 0, error: true };
  }
}

function main() {
  console.log('🔧 Fix impl-trait References\n');
  
  if (DRY_RUN) {
    console.log('⚠️  DRY RUN MODE\n');
  }
  
  const clarityFiles = findClarityFiles(CONTRACTS_DIR);
  
  for (const file of clarityFiles) {
    fixImplTrait(file);
  }
  
  console.log('\n📊 Summary');
  console.log(`Files scanned: ${stats.filesScanned}`);
  console.log(`Files modified: ${stats.filesModified}`);
  console.log(`impl-trait statements fixed: ${stats.implTraitsFixed}`);
  
  if (!DRY_RUN && stats.filesModified > 0) {
    console.log('\n✅ Fixes applied!');
  } else if (DRY_RUN) {
    console.log('\n💡 Run without --dry-run to apply changes');
  }
}

main();
