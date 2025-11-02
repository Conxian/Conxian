import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';

// This test verifies the foundation layer is present and correctly wired.
// It does not execute Clarinet; it validates files and basic content to keep the loop fast.
describe('Foundation layer (traits + encoding)', () => {
  const stacksDir = __dirname; // stacks/tests
  const stacksRoot = path.join(stacksDir, '..'); // stacks
  const manifest = path.join(stacksRoot, 'Clarinet.foundation.toml');

  it('has a foundation manifest with required entries', () => {
    expect(fs.existsSync(manifest)).toBe(true);
    const content = fs.readFileSync(manifest, 'utf8');
    expect(content).toContain('contracts/traits/all-traits.clar');
    expect(content).toContain('contracts/utils/encoding.clar');
  });

  it('contains centralized all-traits and encoding contracts', () => {
    const repoRoot = path.join(stacksRoot, '..');
    const allTraits = path.join(repoRoot, 'contracts', 'traits', 'all-traits.clar');
    const encoding = path.join(repoRoot, 'contracts', 'utils', 'encoding.clar');

    expect(fs.existsSync(allTraits)).toBe(true);
    expect(fs.existsSync(encoding)).toBe(true);

    const traitsSrc = fs.readFileSync(allTraits, 'utf8');
    expect(traitsSrc).toMatch(/\(define-trait\s+[a-zA-Z0-9-]+/);

    const encSrc = fs.readFileSync(encoding, 'utf8');
    expect(encSrc).toMatch(/define-read-only\s*\(hash-uint/);
  });
});
