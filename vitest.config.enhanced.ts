import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    env: {
      CLARINET_MANIFEST_PATH: 'Clarinet.toml',
    },
    testTimeout: 300000,
    hookTimeout: 90000,
    fileParallelism: false,
  },
});
