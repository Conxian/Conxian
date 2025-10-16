const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Find all markdown files with the term "conxian"
const findCommand = 'git grep -l "conxian" -- "*.md"';

try {
  // Execute the find command
  const files = execSync(findCommand, { encoding: 'utf8' })
    .trim()
    .split('\n')
    .filter(Boolean);

  console.log(`Found ${files.length} files containing "conxian"`);

  // Process each file
  let fixedFiles = 0;
  for (const filePath of files) {
    if (!fs.existsSync(filePath)) {
      console.log(`File not found: ${filePath}`);
      continue;
    }

    // Read file content
    let content = fs.readFileSync(filePath, 'utf8');
    
    // Skip files that don't actually contain "conxian"
    if (!content.toLowerCase().includes('conxian')) {
      continue;
    }

    // Replace "conxian" with "Conxian" (case-insensitive, preserve case for the rest)
    const originalContent = content;
    content = content.replace(/conxian/gi, match => {
      // If it's already "Conxian", leave it as is
      if (match === 'Conxian') return match;
      // Otherwise, capitalize the first letter
      return 'Conxian';
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