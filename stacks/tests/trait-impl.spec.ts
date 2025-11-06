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

// Enforce: implementations reference centralized traits from `.all-traits.*`
// Allowed patterns:
// - (impl-trait .all-traits.<trait>)
// - (impl-trait <alias>) where a corresponding (use-trait <alias> .all-traits.<trait>) exists
// Disallowed:
// - Principal-qualified impl-trait (starts with "'")
// - Fully-qualified impl-trait that is NOT under `.all-traits.`

describe('Trait implementation policy (centralized all-traits)', () => {
  const contractsDir = path.join(__dirname, '..', '..', 'contracts');
  const files = readAllClarFiles(contractsDir).filter(p => !p.includes(`${path.sep}traits${path.sep}`));
  it('all impl-trait statements should use .all-traits.* directly or via alias mapped to .all-traits.*', () => {
    const failures: { file: string; message: string }[] = [];

    for (const file of files) {
      const content = fs.readFileSync(file, 'utf8');
      const uses = parseUseTrait(content);
      const impls = parseImplTrait(content);

      for (const sym of impls) {
        // Disallow principal-qualified impl-trait
        if (sym.startsWith("'")) {
          failures.push({ file, message: `(impl-trait ${sym}) must not be principal-qualified; use .all-traits.* or an alias mapped to it` });
          continue;
        }

        // Allow fully-qualified impl that points to centralized traits
        if (sym.includes('.')) {
          if (!sym.includes('.all-traits.')) {
            failures.push({ file, message: `(impl-trait ${sym}) must point to centralized traits via .all-traits.*` });
          }
          continue;
        }

        // Otherwise, sym must be an alias with a matching use-trait mapped to .all-traits.*
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
  }, 20000);
});
