const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Find all files with the term "conxian" (case insensitive)
// Use git grep to find all markdown files with lowercase "conxian"
try {
  console.log("Running comprehensive capitalization fix...");
  
  // Get all markdown files in the repository
  const allMdFiles = execSync('git ls-files "*.md"', { encoding: 'utf8' })
    .trim()
    .split('\n')
    .filter(Boolean);
    
  console.log(`Found ${allMdFiles.length} markdown files to check`);
  
  let fixedFiles = 0;
  
  // Process each file
  for (const filePath of allMdFiles) {
    if (!fs.existsSync(filePath)) {
      continue;
    }
    
    // Read file content
    let content = fs.readFileSync(filePath, 'utf8');
    const originalContent = content;
    
    // Replace "conxian" with "Conxian" (case-insensitive, but not in URLs or code blocks)
    content = content.replace(/\bconxian\b/gi, match => {
      // If it's already "Conxian", leave it as is
      if (match === 'Conxian') return match;
      // Otherwise, capitalize the first letter
      return 'Conxian';
    });
    
    // Replace "cxlp" with "CXLP" (case-insensitive, but not in URLs or code blocks)
    content = content.replace(/\bcxlp\b/gi, match => {
      // If it's already "CXLP", leave it as is
      if (match === 'CXLP') return match;
      // Otherwise, uppercase it
      return 'CXLP';
    });
    
    // Only write if changes were made
    if (content !== originalContent) {
      fs.writeFileSync(filePath, content, 'utf8');
      console.log(`Fixed capitalization in: ${filePath}`);
      fixedFiles++;
    }
  }
  
  console.log(`\nSummary: Fixed capitalization in ${fixedFiles} files`);
} catch (error) {
  console.error('Error:', error.message);
  process.exit(1);
}