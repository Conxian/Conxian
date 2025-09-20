#!/usr/bin/env node

import { run } from '@oclif/core';
import { config } from 'dotenv';
import { resolve } from 'path';

// Load environment variables
config({ path: resolve(__dirname, '../.env') });

// Run tests using Vitest
async function main() {
  try {
    console.log('Starting tests...');
    
    // Run tests with Vitest programmatically
    const { startVitest } = await import('vitest/node');
    
    const vitest = await startVitest('test', ['cx-tokens.test.ts'], {
      run: false,
      watch: false,
      passWithNoTests: true,
      reporters: 'verbose',
      environment: 'node',
    });
    
    process.exit(vitest ? 0 : 1);
  } catch (error) {
    console.error('Error running tests:', error);
    process.exit(1);
  }
}

main().catch(console.error);
