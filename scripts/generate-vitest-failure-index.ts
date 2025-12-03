import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Simple helper script to extract failing Vitest suites from vitest_raw.txt
// and write a markdown index under documentation/reports/TEST_SUITE_FAILURES_INDEX.md.

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..');

const logPath = path.join(repoRoot, 'vitest_raw.txt');
const outPath = path.join(
  repoRoot,
  'documentation',
  'reports',
  'TEST_SUITE_FAILURES_INDEX.md',
);

if (!fs.existsSync(logPath)) {
  console.error(`vitest_raw.txt not found at ${logPath}`);
  process.exit(1);
}

const raw = fs.readFileSync(logPath, 'utf8');
const lines = raw.split(/\r?\n/);
const ansiRegex = /\x1B\[[0-9;]*m/g;

interface SuiteEntry {
  file: string;
  raw: string;
}

const suites: SuiteEntry[] = [];

for (const line of lines) {
  const clean = line.replace(ansiRegex, '');
  const match = clean.match(/^\s*FAIL\s+([^\s]+)\s+\[/);
  if (match) {
    const file = match[1];
    suites.push({ file, raw: clean.trim() });
  }
}

let output = '# Vitest Failed Suites Index\n\n';
output += 'Source log: `vitest_raw.txt`\n\n';
output += `Detected failing suites: **${suites.length}**\n\n`;

suites.forEach((s, idx) => {
  output += `- **${idx + 1}. ${s.file}**\n`;
  output += `  - ${s.raw}\n`;
});

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, output, 'utf8');

console.log(`Wrote ${suites.length} failing suite entries to ${outPath}`);
