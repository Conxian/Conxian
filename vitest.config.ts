import { defineConfig } from 'vitest/config';
import { vitestSetupFilePath } from '@stacks/clarinet-sdk/vitest';

export default defineConfig({
  test: {
    environment: "node",
    setupFiles: ['./stacks/setup-test-env.ts', vitestSetupFilePath],
    env: {
      CLARINET_MANIFEST_PATH: "Clarinet.toml",
    },
    testTimeout: 120000,
    hookTimeout: 90000,
    pool: "threads",
    fileParallelism: false,
  },
});
