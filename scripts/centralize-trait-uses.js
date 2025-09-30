#!/usr/bin/env node
/**
 * Centralize trait imports and clean principal references
 * - use-trait X .all-traits.traits.Y  -> use-trait X .all-traits.Y
 * - use-trait X .traits.Y             -> use-trait X .all-traits.Y
 * - general principal refs: .traits.NAME -> .NAME (outside use-trait)
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const CONTRACTS = path.join(ROOT, 'contracts');

function walk(dir, cb){
  for (const d of fs.readdirSync(dir, {withFileTypes:true})){
    const p = path.join(dir, d.name);
    if (d.isDirectory()) walk(p, cb);
    else if (d.isFile() && d.name.endsWith('.clar')) cb(p);
  }
}

function fixFile(file){
  let src = fs.readFileSync(file, 'utf8');
  const orig = src;

  // Normalize use-trait
  src = src.replace(/\(use-trait(\s+\S+\s+)\.all-traits\.traits\./g, '(use-trait$1.all-traits.');
  src = src.replace(/\(use-trait(\s+\S+\s+)\.traits\./g, '(use-trait$1.all-traits.');

  // Cleanup stray parentheses around use-trait blocks e.g. starting with '(' on new line
  src = src.replace(/\n\(\s*use-trait/g, '\n(use-trait');

  // General principal references .traits.NAME -> .NAME (avoid all-traits.clar)
  if (!file.endsWith(path.join('traits','all-traits.clar'))){
    src = src.replace(/([^\w-])\.traits\./g, '$1.');
    src = src.replace(/\.all-traits\.traits\./g, '.all-traits.');
  }

  if (src !== orig){
    fs.writeFileSync(file, src, 'utf8');
    return true;
  }
  return false;
}

let modified = 0; let scanned = 0;
walk(CONTRACTS, (f)=>{ scanned++; if (fixFile(f)) modified++; });
console.log(`Scanned ${scanned} files, modified ${modified}`);
