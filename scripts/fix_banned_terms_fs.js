const fs = require('fs');
const path = require('path');

// Root directory (workspace)
const ROOT = path.resolve(__dirname, '..');

// File extensions to process
const EXTENSIONS = new Set(['.md']);

// Walk the directory recursively and collect files
function walk(dir, files = []) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      // Skip VCS and node_modules and hidden .git directories
      if (entry.name === '.git' || entry.name === 'node_modules') continue;
      files = walk(fullPath, files);
    } else {
      files.push(fullPath);
    }
  }
  return files;
}

function processMarkdown(content) {
  // Replace outside code fences only
  const lines = content.split(/\r?\n/);
  let inCodeFence = false;
  for (let i = 0; i < lines.length; i++) {
    let line = lines[i];
    // Toggle code fence state
    if (line.trim().startsWith('```')) {
      inCodeFence = !inCodeFence;
      lines[i] = line;
      continue;
    }
    if (!inCodeFence) {
      // Replace legacy project name 'conxian' with 'Conxian' (whole word, case-insensitive)
      line = line.replace(/\bconxian\b/gi, (m) => 'Conxian');
      // Replace token symbol 'cxlp' with 'CXLP' (whole word, case-insensitive)
      line = line.replace(/\bcxlp\b/gi, (m) => 'CXLP');
      lines[i] = line;
    } else {
      lines[i] = line; // leave code fence contents unchanged
    }
  }
  return lines.join('\n');
}

function main() {
  const allFiles = walk(ROOT);
  const targetFiles = allFiles.filter((f) => EXTENSIONS.has(path.extname(f).toLowerCase()));
  let fixedCount = 0;
  let processedCount = 0;
  for (const file of targetFiles) {
    processedCount++;
    const original = fs.readFileSync(file, 'utf8');
    const updated = processMarkdown(original);
    if (updated !== original) {
      fs.writeFileSync(file, updated, 'utf8');
      console.log(`Fixed: ${path.relative(ROOT, file)}`);
      fixedCount++;
    }
  }
  console.log(`\nProcessed ${processedCount} markdown files. Fixed ${fixedCount} files.`);
}

try {
  main();
} catch (e) {
  console.error('Error fixing banned terms:', e);
  process.exit(1);
}