import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';

function readAllClarFiles(dir: string, acc: string[] = []): string[] {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) readAllClarFiles(p, acc);
    else if (entry.isFile() && p.endsWith('.clar')) acc.push(p);
  }
  return acc;
}

function parseUseTrait(content: string): Record<string, string> {
  const m: Record<string, string> = {};
  const re = /\(use-trait\s+([^\s\)]+)\s+([^\)]+)\)/g;
  let match: RegExpExecArray | null;
  while ((match = re.exec(content))) {
    const alias = match[1]?.trim();
    const ref = match[2]?.trim();
    if (alias) m[alias] = ref;
  }
  return m;
}

function parseImplTrait(content: string): string[] {
  const out: string[] = [];
  const re = /\(impl-trait\s+([^\s\)]+)\)/g;
  let match: RegExpExecArray | null;
  while ((match = re.exec(content))) {
    const sym = match[1]?.trim();
    if (sym) out.push(sym);
  }
  return out;
}

// Enforce: implementations reference centralized traits via alias imported from `.all-traits.*`
// - Contracts in `contracts/traits/` are skipped
// - For each (impl-trait X): X must be an alias defined by (use-trait X ...)
// - The corresponding (use-trait X ...) path must include `.all-traits.` (centralized traits)
// - Disallow `(impl-trait .something...)` (fully-qualified impl)

describe('Trait implementation policy (centralized all-traits)', () => {
  const contractsDir = path.join(__dirname, '..', '..', 'contracts');
  const files = readAllClarFiles(contractsDir).filter(p => !p.includes(`${path.sep}traits${path.sep}`));

  it('all impl-trait statements should use alias from use-trait and point to .all-traits.*', () => {
    const failures: { file: string; message: string }[] = [];

    for (const file of files) {
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
        if (!ref.includes('.all-traits.')) {
          failures.push({ file, message: `(impl-trait ${sym}) should reference centralized traits: found ${ref}` });
        }
      }
    }

    if (failures.length > 0) {
      const lines = failures.map(f => `${f.file}: ${f.message}`).join('\n');
      throw new Error(`Trait implementation policy violations (centralized all-traits)\n${lines}`);
    }

    expect(true).toBe(true);
  });
});
