#!/usr/bin/env node
/**
 * StacksOrbit CLI Entry Point
 * Launches the Python GUI deployer
 */

const { spawn } = require('child_process');
const path = require('path');

// Get the directory where stacksorbit.py is located
const scriptDir = path.join(__dirname, '..');
const pythonScript = path.join(scriptDir, 'stacksorbit.py');

// Launch Python GUI
const python = spawn('python', [pythonScript], {
  stdio: 'inherit',
  cwd: process.cwd()
});

python.on('error', (err) => {
  console.error('Failed to start StacksOrbit:', err.message);
  console.error('\nMake sure Python 3.8+ is installed and in your PATH');
  process.exit(1);
});

python.on('exit', (code) => {
  process.exit(code);
});
