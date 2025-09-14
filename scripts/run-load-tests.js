#!/usr/bin/env node

/**
 * Load Test Runner with Environment Detection
 * Automatically scales test parameters based on CI vs local environment
 */

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

// Detect environment
const isCI = process.env.CI === 'true' || process.env.GITHUB_ACTIONS === 'true';
const isDebug = process.argv.includes('--debug');

console.log(`🧪 Running Load Tests`);
console.log(`📊 Environment: ${isCI ? 'CI/CD Pipeline' : 'Local Development'}`);
console.log(`🐛 Debug Mode: ${isDebug ? 'Enabled' : 'Disabled'}`);

// Set environment variables for the test
const testEnv = {
  ...process.env,
  CI: isCI ? 'true' : undefined,
  NODE_OPTIONS: '--max-old-space-size=4096', // Increase memory limit
  DEBUG: isDebug ? '*' : undefined
};

// Prepare test command
const vitestArgs = [
  'run',
  'tests/load-testing/massive-scale.test.ts',
  '--config',
  'vitest.config.enhanced.ts'
];

if (isDebug) {
  vitestArgs.push('--reporter=verbose');
}

if (!isCI) {
  vitestArgs.push('--watch=false'); // Ensure non-watch mode
}

console.log(`🚀 Command: npx vitest ${vitestArgs.join(' ')}`);

// Run the test
const testProcess = spawn('npx', ['vitest', ...vitestArgs], {
  stdio: 'inherit',
  env: testEnv,
  cwd: path.resolve(__dirname, '..')
});

testProcess.on('close', (code) => {
  if (code === 0) {
    console.log('\n✅ Load tests completed successfully!');
  } else {
    console.log('\n❌ Load tests failed with exit code:', code);
    process.exit(code);
  }
});

testProcess.on('error', (error) => {
  console.error('❌ Failed to start load tests:', error);
  process.exit(1);
});
