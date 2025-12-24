import { defineConfig } from 'vitest/config';
import { vitestSetupFilePath } from '@stacks/clarinet-sdk/vitest';

export default defineConfig({
  test: {
    environment: 'node',
    setupFiles: ['./tests/api-test-setup.ts', vitestSetupFilePath, './tests/vitest.setup.ts'],
    env: {
      CLARINET_MANIFEST_PATH: 'Clarinet.toml',
    },
    testTimeout: 300000,
    hookTimeout: 90000,
    fileParallelism: false,
  },
});
