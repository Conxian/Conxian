// Import required test utilities
import { beforeEach, afterEach } from 'vitest';
import { ClarinetTestProvider } from '@clarigen/test';

// Initialize test provider
const testProvider = new ClarinetTestProvider({
  // Use local Clarinet instance
  clarinetPath: 'clarinet',
  // Path to your Clarinet.toml
  manifestPath: './Clarinet.toml',
  // Enable debug logging
  debug: true
});

// Setup and teardown
beforeEach(async () => {
  await testProvider.start();
});

afterEach(async () => {
  await testProvider.close();
});

// Export test provider for use in tests
export { testProvider };
