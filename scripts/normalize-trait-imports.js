#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const CONTRACTS_DIR = path.join(__dirname, '../contracts');
const DRY_RUN = process.argv.includes('--dry-run');

const stats = { filesScanned: 0, filesModified: 0, replacements: 0 };

function walk(dir, callback) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, callback);
    else if (entry.isFile() && entry.name.endsWith('.clar')) callback(full);
  }
}

const regexes = [
  /STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ\.all-traits\./g,
  /'\.all-traits\./g,
  /'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ\.all-traits\./g
];

walk(CONTRACTS_DIR, file => {
  stats.filesScanned++;
  const text = fs.readFileSync(file, 'utf8');
  let modified = text;
  for (const re of regexes) {
    modified = modified.replace(re, '.all-traits.');
  }
  if (modified !== text) {
    if (!DRY_RUN) fs.writeFileSync(file, modified, 'utf8');
    stats.filesModified++;
  }
});

console.log(`Scanned ${stats.filesScanned} files`);
console.log(`Modified ${stats.filesModified} files`);
if (DRY_RUN) console.log('Dry run - no files overwritten');
