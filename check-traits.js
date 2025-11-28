const fs = require('fs');
const path = require('path');

function readAllClarFiles(dir, acc = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) readAllClarFiles(p, acc);
    else if (entry.isFile() && p.endsWith('.clar')) acc.push(p);
  }
  return acc;
}

function parseUseTrait(content) {
  const m = {};
  const re = /\(use-trait\s+([^\s\)]+)\s+([^\)]+)\)/g;
  let match;
  while ((match = re.exec(content))) {
    const alias = match[1]?.trim();
    const ref = match[2]?.trim();
    if (alias) m[alias] = ref;
  }
  return m;
}

function parseImplTrait(content) {
  const out = [];
  const re = /\(impl-trait\s+([^\s\)]+)\)/g;
  let match;
  while ((match = re.exec(content))) {
    const sym = match[1]?.trim();
    if (sym) out.push(sym);
  }
  return out;
}

const contractsDir = path.join(process.cwd(), 'contracts');
const files = readAllClarFiles(contractsDir).filter(p => !p.includes(`${path.sep}traits${path.sep}`));
const failures = [];

for (const file of files) {
  try {
    const content = fs.readFileSync(file, 'utf8');
    const uses = parseUseTrait(content);
    const impls = parseImplTrait(content);

    for (const sym of impls) {
      // Disallow fully-qualified impl-trait
      if (sym.includes('.') || sym.startsWith("'")) {
        failures.push({ file, message: `(impl-trait ${sym}) should use an alias imported via (use-trait ...)` });
        continue;
      }

      const ref = uses[sym];
      if (!ref) {
        failures.push({ file, message: `(impl-trait ${sym}) has no matching (use-trait ${sym} <path>)` });
        continue;
      }
      if (!ref.includes('.traits folder.')) {
        failures.push({ file, message: `(impl-trait ${sym}) should reference centralized traits: found ${ref}` });
      }
    }
  } catch (e) {
    failures.push({ file, message: `Error reading file: ${e.message}` });
  }
}

if (failures.length > 0) {
  console.log('Trait implementation policy violations:');
  failures.forEach(f => console.log(`${f.file}: ${f.message}`));
  process.exit(1);
} else {
  console.log('All trait implementations follow the policy!');
}
