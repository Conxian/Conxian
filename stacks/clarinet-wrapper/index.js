#!/usr/bin/env node
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const candidates = [
  path.resolve(__dirname, '..', '..', 'bin', 'clarinet'), // stacks/bin/clarinet when installed into node_modules
  path.resolve(process.cwd(), '..', 'bin', 'clarinet'),   // running from stacks/
  path.resolve(process.cwd(), 'bin', 'clarinet'),         // running from repo root
  // Windows winget install location
  'C:\\Program Files\\clarinet\\bin\\clarinet.exe',
];

const binPath = candidates.find(p => {
  try {
    const st = fs.statSync(p);
    return st.isFile() && (st.mode & 0o111);
  } catch (_) { return false; }
});

if (!binPath) {
  // Fallback: try using clarinet from PATH (e.g., winget-installed on Windows)
  const child = spawn('clarinet', process.argv.slice(2), {
    stdio: 'inherit',
    shell: process.platform === 'win32',
  });
  child.on('error', (err) => {
    console.error('clarinet wrapper: unable to locate bin/clarinet binary and failed to execute clarinet from PATH.');
    console.error('Searched:');
    for (const p of candidates) console.error(' - ' + p);
    console.error(`Spawn error: ${err.message}`);
    process.exit(127);
  });
  child.on('exit', code => process.exit(code));
} else {
  const child = spawn(binPath, process.argv.slice(2), { stdio: 'inherit' });
  child.on('exit', code => process.exit(code));
}
