/**
 * Global Test Setup for Enhanced Tokenomics System
 * 
 * Configures the test environment with Clarinet integration
 * and enhanced system capabilities
 */

import { resolve } from 'path';
import { existsSync, mkdirSync } from 'fs';

export default async function globalSetup() {
  console.log('🔧 Setting up enhanced tokenomics test environment...');
  
  // Ensure test directories exist
  const testDirs = [
    './test-results',
    './coverage',
    './logs/test-logs'
  ];
  
  for (const dir of testDirs) {
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }
  }
  
  // Verify Clarinet configuration
  const clarinetPath = resolve('./Clarinet.toml');
  if (!existsSync(clarinetPath)) {
    throw new Error('Clarinet.toml not found - ensure Clarinet is properly configured');
  }
  
  // Initialize enhanced system test environment
  process.env.TEST_MODE = 'enhanced';
  process.env.CLARINET_DISABLE_HINTS = 'true';
  process.env.CLARINET_MODE = 'test';
  
  console.log('✅ Enhanced test environment ready');
  console.log('📊 Coverage reporting enabled');
  console.log('🚀 Load testing capabilities initialized');
}
