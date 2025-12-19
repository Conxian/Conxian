import { defineConfig } from 'vitest/config';
import { vitestSetupFilePath } from '@stacks/clarinet-sdk/vitest';

export default defineConfig({
  test: {
    environment: "node",
    setupFiles: [vitestSetupFilePath],
    env: {
      CLARINET_MANIFEST_PATH: "Clarinet.toml",
    },
    testTimeout: 60000,
    hookTimeout: 30000,
    fileParallelism: false,
  },
});
