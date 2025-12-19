import { defineConfig } from 'vitest/config';
import { vitestSetupFilePath } from '@stacks/clarinet-sdk/vitest';

export default defineConfig({
  test: {
    include: ['stacks/tests/**/*.test.ts'],
    environment: 'node',
    setupFiles: [vitestSetupFilePath, './tests/vitest.setup.ts'],
    env: {
      CLARINET_MANIFEST_PATH: 'Clarinet.toml',
    },
    testTimeout: 60000,
    hookTimeout: 60000,
  },
});
