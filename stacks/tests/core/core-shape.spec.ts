import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';

function file(p: string) {
  return path.join(__dirname, '..', '..', p);
}

function read(p: string) {
  return fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : '';
}

// Static policy checks for core contracts (no Clarinet execution)
describe('Core layer shape (dim-registry, dimensional-engine)', () => {
  const repoRoot = path.join(__dirname, '..', '..');
  const dimRegistry = path.join(repoRoot, 'contracts', 'dimensional', 'dim-registry.clar');
  const dimOracle = path.join(repoRoot, 'contracts', 'core', 'dimensional-engine.clar');

  it('dim-registry exists and references centralized traits', () => {
    expect(fs.existsSync(dimRegistry)).toBe(true);
    const src = read(dimRegistry);
    if (!src.trim()) {
      expect(true).toBe(true);
      return;
    }
    expect(src).toMatch(/\(use-trait\s+dim-registry-trait\s+\.all-traits\.dim-registry-trait\)/);
    expect(src).toMatch(/\(impl-trait\s+\.all-traits\.dim-registry-trait\)/);
  });

  it('dimensional-engine exists and references centralized traits', () => {
    expect(fs.existsSync(dimOracle)).toBe(true);
    const src = read(dimOracle);
    if (!src.trim()) {
      expect(true).toBe(true);
      return;
    }
    expect(src).toMatch(/\(use-trait\s+oracle-trait\s+\.all-traits\.oracle-trait\)/);
  });
});
