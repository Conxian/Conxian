const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Find all files with the term "conxian" (case insensitive)
const findCommand = 'git grep -l -i "conxian" -- "*.md"';
// Find files with "cxlp" token symbol
const findTokenCommand = 'git grep -l "cxlp" -- "*.md"';

try {
  // Execute the find commands
  const files = execSync(findCommand, { encoding: 'utf8' })
    .trim()
    .split('\n')
    .filter(Boolean);
  
  const tokenFiles = execSync(findTokenCommand, { encoding: 'utf8' })
    .trim()
    .split('\n')
    .filter(Boolean);
  
  // Combine unique files
  const allFiles = [...new Set([...files, ...tokenFiles])];

  console.log(`Found ${allFiles.length} files to process`);

  // Process each file
  let fixedFiles = 0;
  for (const filePath of allFiles) {
    if (!fs.existsSync(filePath)) {
      console.log(`File not found: ${filePath}`);
      continue;
    }

    // Read file content
    let content = fs.readFileSync(filePath, 'utf8');
    const originalContent = content;
    
    // Fix "conxian" to "Conxian" (case-insensitive)
    content = content.replace(/conxian/gi, match => {
      // If it's already "Conxian", leave it as is
      if (match === 'Conxian') return match;
      // Otherwise, capitalize the first letter
      return 'Conxian';
    });
    
    // Fix "cxlp" to "CXLP" (case-insensitive, but not in URLs or code blocks)
    content = content.replace(/\bcxlp\b/gi, match => {
      // If it's in a URL or code block, leave it as is
      const prevChars = content.substring(Math.max(0, content.indexOf(match) - 10), content.indexOf(match));
      if (prevChars.includes('```') || prevChars.includes('http') || prevChars.includes('://')) return match;
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